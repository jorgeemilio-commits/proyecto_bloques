import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../cuenta/servicio_cuenta.dart';

// Estado de la conexion con el servidor de salas.
enum EstadoConexion { desconectado, conectando, conectado, reconectando }

class JugadorEnSala {
  final String usuario;
  final bool conectado;

  const JugadorEnSala(this.usuario, {required this.conectado});
}

// Lo que manda el servidor en cada mensaje "estado" (ver
// PROTOCOLO_MULTIJUGADOR.md). Por ahora solo lo del lobby.
class EstadoSala {
  // 'sinSala', 'lobby', 'valoresIniciales'...
  final String fase;
  final String usuario;
  final String? codigo;
  final String? anfitrion;
  final String? mapa;
  final int maximo;
  final int? meta;
  final List<JugadorEnSala> jugadores;

  const EstadoSala({
    required this.fase,
    required this.usuario,
    this.codigo,
    this.anfitrion,
    this.mapa,
    this.maximo = 6,
    this.meta,
    this.jugadores = const [],
  });

  factory EstadoSala.desdeJson(Map<String, dynamic> datos) => EstadoSala(
    fase: datos['fase'] as String,
    usuario: datos['usuario'] as String,
    codigo: datos['codigo'] as String?,
    anfitrion: datos['anfitrion'] as String?,
    mapa: datos['mapa'] as String?,
    maximo: datos['maximo'] as int? ?? 6,
    meta: datos['meta'] as int?,
    jugadores: [
      for (final jugador in datos['jugadores'] as List? ?? const [])
        JugadorEnSala(
          (jugador as Map)['usuario'] as String,
          conectado: jugador['conectado'] as bool,
        ),
    ],
  );

  bool get enSala => fase != 'sinSala';
  bool get soyAnfitrion => anfitrion == usuario;
}

// Habla con el servidor de salas por WebSocket: manda los mensajes del
// jugador, guarda el ultimo estado que llego y avisa a las pantallas. Si se
// cae la conexion, reintenta sola durante [tiempoReconexion].
class ServicioDeSala extends ChangeNotifier {
  final ServicioDeCuenta cuenta;
  // Abre el canal con el servidor; las pruebas pasan uno falso.
  final StreamChannel<dynamic> Function(Uri direccion) _abrirCanal;
  final Duration esperaEntreIntentos;
  final Duration tiempoReconexion;

  StreamChannel<dynamic>? _canal;
  StreamSubscription<dynamic>? _suscripcion;
  Timer? _reintento;
  DateTime? _caidaDesde;
  // true cuando el jugador cerro a proposito o el servidor no deja volver
  // (sesion no valida o abierta en otro dispositivo): no se reintenta.
  bool _sinReintentos = false;

  EstadoConexion _conexion = EstadoConexion.desconectado;
  EstadoSala? _estado;
  final _avisos = StreamController<String>.broadcast();

  ServicioDeSala({
    required this.cuenta,
    StreamChannel<dynamic> Function(Uri direccion)? abrirCanal,
    this.esperaEntreIntentos = const Duration(seconds: 2),
    this.tiempoReconexion = const Duration(seconds: 80),
  }) : _abrirCanal = abrirCanal ?? WebSocketChannel.connect;

  EstadoConexion get conexion => _conexion;

  // Ultimo estado que mando el servidor, o null si todavia no llega.
  EstadoSala? get estado => _estado;

  // Mensajes para mostrar un momento: avisos del servidor ("Ana se
  // desconectó") y errores ("No existe una sala con ese código.").
  Stream<String> get avisos => _avisos.stream;

  // Direccion del WebSocket: la del servidor de cuentas con ws/wss y /sala.
  Uri get direccion => cuenta.servidor.replace(
    scheme: cuenta.servidor.scheme == 'https' ? 'wss' : 'ws',
    path: '/sala',
  );

  void conectar() {
    if (_conexion != EstadoConexion.desconectado) {
      return;
    }
    _sinReintentos = false;
    _caidaDesde = null;
    _cambiarConexion(EstadoConexion.conectando);
    _abrir();
  }

  void crearSala() => _mandar({'tipo': 'crearSala'});

  void unirse(String codigo) => _mandar({'tipo': 'unirse', 'codigo': codigo});

  void salir() => _mandar({'tipo': 'salir'});

  void elegirMapa(String mapa) => _mandar({'tipo': 'elegirMapa', 'mapa': mapa});

  void iniciar() => _mandar({'tipo': 'iniciar'});

  // Cierra la conexion a proposito (por ejemplo, al cerrar sesion).
  void desconectar() {
    _sinReintentos = true;
    _cerrarCanal();
    _estado = null;
    _cambiarConexion(EstadoConexion.desconectado);
  }

  @override
  void dispose() {
    _sinReintentos = true;
    _cerrarCanal();
    _avisos.close();
    super.dispose();
  }

  void _abrir() {
    final token = cuenta.token;
    if (token == null) {
      _rendirse('Inicia sesión para jugar en línea.');
      return;
    }

    final StreamChannel<dynamic> canal;
    try {
      canal = _abrirCanal(direccion);
    } on Object {
      _seCayo();
      return;
    }
    _canal = canal;
    _suscripcion = canal.stream.listen(
      _recibir,
      onError: (_) {},
      onDone: () {
        if (identical(_canal, canal)) {
          _seCayo();
        }
      },
    );
    canal.sink.add(jsonEncode({'tipo': 'hola', 'token': token}));
  }

  void _recibir(dynamic texto) {
    final Map<String, dynamic> mensaje;
    try {
      mensaje = jsonDecode(texto as String) as Map<String, dynamic>;
    } on Object {
      return;
    }

    switch (mensaje['tipo']) {
      case 'estado':
        // El primer estado confirma que el servidor nos acepto.
        _caidaDesde = null;
        _estado = EstadoSala.desdeJson(mensaje);
        _cambiarConexion(EstadoConexion.conectado);
      case 'aviso':
        _avisos.add(mensaje['texto'] as String);
      case 'error':
        final codigo = mensaje['codigo'];
        if (codigo == 'sesionInvalida' || codigo == 'sesionReemplazada') {
          _rendirse(mensaje['mensaje'] as String);
        } else {
          _avisos.add(mensaje['mensaje'] as String);
        }
    }
  }

  // Se cerro la conexion sin querer: se reintenta hasta [tiempoReconexion].
  void _seCayo() {
    _cerrarCanal();
    if (_sinReintentos) {
      return;
    }
    _caidaDesde ??= DateTime.now();
    if (DateTime.now().difference(_caidaDesde!) >= tiempoReconexion) {
      _rendirse('Se perdió la conexión con el servidor.');
      return;
    }
    _cambiarConexion(EstadoConexion.reconectando);
    _reintento = Timer(esperaEntreIntentos, _abrir);
  }

  // Ya no se puede seguir: se cierra todo y se avisa por que.
  void _rendirse(String mensaje) {
    _sinReintentos = true;
    _cerrarCanal();
    _estado = null;
    _avisos.add(mensaje);
    _cambiarConexion(EstadoConexion.desconectado);
  }

  void _mandar(Map<String, Object?> mensaje) {
    if (_conexion != EstadoConexion.conectado) {
      _avisos.add('No hay conexión con el servidor.');
      return;
    }
    _canal?.sink.add(jsonEncode(mensaje));
  }

  void _cerrarCanal() {
    _reintento?.cancel();
    _reintento = null;
    _suscripcion?.cancel();
    _suscripcion = null;
    final canal = _canal;
    _canal = null;
    canal?.sink.close();
  }

  void _cambiarConexion(EstadoConexion conexion) {
    _conexion = conexion;
    notifyListeners();
  }
}
