import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../cuenta/servicio_cuenta.dart';

// Estado de la conexion con el servidor de salas.
enum EstadoConexion { desconectado, conectando, conectado, reconectando }

// Un jugador de la sala. En el lobby solo importan su nombre y si esta
// conectado; en la partida llegan tambien sus puntos y su tablero.
class JugadorEnSala {
  final String usuario;
  final bool conectado;
  // En el lobby: si marco que esta listo para empezar.
  final bool listo;
  // 'jugando', 'llegoALaMeta' o 'rendido'.
  final String situacion;
  // Si ya mando su jugada de esta ronda (o sus valores iniciales).
  final bool yaJugo;
  final int puntos;
  // Sus valores iniciales en el orden de las casillas iniciales del mapa; los
  // de los rivales llegan como null hasta la primera ronda.
  final List<int>? iniciales;
  // Los numeros que coloco, como (x, y, numero).
  final List<(int, int, int)> casillas;
  // Region que completo en la ultima ronda y los puntos que le dio.
  final ({String region, int puntos})? ultimoReclamo;

  const JugadorEnSala(
    this.usuario, {
    required this.conectado,
    this.listo = false,
    this.situacion = 'jugando',
    this.yaJugo = false,
    this.puntos = 0,
    this.iniciales,
    this.casillas = const [],
    this.ultimoReclamo,
  });

  factory JugadorEnSala.desdeJson(Map<String, dynamic> datos) {
    final reclamo = datos['ultimoReclamo'] as Map?;
    return JugadorEnSala(
      datos['usuario'] as String,
      conectado: datos['conectado'] as bool,
      listo: datos['listo'] as bool? ?? false,
      situacion: datos['situacion'] as String? ?? 'jugando',
      yaJugo: datos['yaJugo'] as bool? ?? false,
      puntos: datos['puntos'] as int? ?? 0,
      iniciales: (datos['iniciales'] as List?)?.cast<int>(),
      casillas: [
        for (final casilla in datos['casillas'] as List? ?? const [])
          (casilla[0] as int, casilla[1] as int, casilla[2] as int),
      ],
      ultimoReclamo: reclamo == null
          ? null
          : (
              region: reclamo['region'] as String,
              puntos: reclamo['puntos'] as int,
            ),
    );
  }

  bool get jugando => situacion == 'jugando';
}

// Lo que manda el servidor en cada mensaje "estado" (ver
// PROTOCOLO_MULTIJUGADOR.md).
class EstadoSala {
  // 'sinSala', 'lobby', 'valoresIniciales', 'ronda', 'entreRondas' o
  // 'terminada'.
  final String fase;
  final String usuario;
  final String? codigo;
  final String? anfitrion;
  final String? mapa;
  // Segundos por ronda que eligio el anfitrion, o null si no hay limite.
  final int? segundosPorRonda;
  final int maximo;
  final int? meta;
  final List<JugadorEnSala> jugadores;
  final int ronda;
  final List<int>? dados;
  // Cuando se acaba la ronda (o los valores iniciales), con el reloj de este
  // dispositivo; null si no hay tiempo corriendo.
  final DateTime? limite;
  final List<String> ganadores;
  // Veces que se ha reclamado cada region, por su id.
  final Map<String, int> reclamos;

  const EstadoSala({
    required this.fase,
    required this.usuario,
    this.codigo,
    this.anfitrion,
    this.mapa,
    this.segundosPorRonda,
    this.maximo = 6,
    this.meta,
    this.jugadores = const [],
    this.ronda = 0,
    this.dados,
    this.limite,
    this.ganadores = const [],
    this.reclamos = const {},
  });

  factory EstadoSala.desdeJson(Map<String, dynamic> datos) {
    final restante = datos['restanteMs'] as int?;
    return EstadoSala(
      fase: datos['fase'] as String,
      usuario: datos['usuario'] as String,
      codigo: datos['codigo'] as String?,
      anfitrion: datos['anfitrion'] as String?,
      mapa: datos['mapa'] as String?,
      segundosPorRonda: datos['segundosPorRonda'] as int?,
      maximo: datos['maximo'] as int? ?? 6,
      meta: datos['meta'] as int?,
      jugadores: [
        for (final jugador in datos['jugadores'] as List? ?? const [])
          JugadorEnSala.desdeJson((jugador as Map).cast<String, dynamic>()),
      ],
      ronda: datos['ronda'] as int? ?? 0,
      dados: (datos['dados'] as List?)?.cast<int>(),
      // El servidor manda cuanto falta; la cuenta regresiva se hace con el
      // reloj de aqui para no depender de que los relojes coincidan.
      limite: restante == null
          ? null
          : DateTime.now().add(Duration(milliseconds: restante)),
      ganadores: (datos['ganadores'] as List? ?? const []).cast<String>(),
      reclamos: (datos['reclamos'] as Map? ?? const {}).cast<String, int>(),
    );
  }

  bool get enSala => fase != 'sinSala';
  bool get soyAnfitrion => anfitrion == usuario;
  bool get enLaPartida => enSala && fase != 'lobby';

  // En el lobby: si todos los jugadores marcaron que estan listos.
  bool get todosListos => jugadores.every((jugador) => jugador.listo);

  // Los datos de este jugador en la sala.
  JugadorEnSala? get yo {
    for (final jugador in jugadores) {
      if (jugador.usuario == usuario) {
        return jugador;
      }
    }
    return null;
  }
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
    this.tiempoReconexion = const Duration(seconds: 15),
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

  // Tiempo por ronda (solo el anfitrion); null = sin limite.
  void elegirTiempo(int? segundos) =>
      _mandar({'tipo': 'elegirTiempo', 'segundos': segundos});

  // Marca o desmarca que este jugador esta listo para empezar.
  void marcarListo(bool listo) => _mandar({'tipo': 'listo', 'listo': listo});

  // Deja la partida; los demas siguen jugando.
  void rendirse() => _mandar({'tipo': 'rendirse'});

  // Los 6 valores iniciales, en el orden de las casillas iniciales del mapa.
  void mandarValores(List<int> valores) =>
      _mandar({'tipo': 'valoresIniciales', 'valores': valores});

  // La jugada de la ronda: el numero que se puso y donde, y la region que se
  // completo con el (si se completo una) con sus premios.
  void colocar({
    required int ronda,
    required int x,
    required int y,
    required int numero,
    String? region,
    List<int> premios = const [],
  }) => _mandar({
    'tipo': 'colocar',
    'ronda': ronda,
    'x': x,
    'y': y,
    'numero': numero,
    'reclamo': region == null ? null : {'region': region, 'premios': premios},
  });

  void pasar(int ronda) => _mandar({'tipo': 'pasar', 'ronda': ronda});

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
          // La sesion ya no vale (por ejemplo, se inicio sesion con la misma
          // cuenta en otro dispositivo): se cierra y la app vuelve al inicio
          // de sesion.
          _rendirse(mensaje['mensaje'] as String);
          cuenta.cerrarSesion();
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
