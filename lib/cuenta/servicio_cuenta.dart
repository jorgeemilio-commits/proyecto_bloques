import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Direccion del servidor de cuentas (servidor/bin/servidor.dart), que corre
// en la computadora en el puerto 8081. ngrok la publica en internet con este
// dominio fijo, asi que los jugadores se conectan desde cualquier red.
//
// Para usar tu propio servidor, cambia la direccion por una de estas:
// - Tu dominio de ngrok: 'https://<tu-dominio>.ngrok-free.dev'
// - En la misma computadora (Windows): 'http://localhost:8081'
// - Emulador de Android: 'http://10.0.2.2:8081'
// - Telefono en la misma red: 'http://<IP de la computadora>:8081'
final Uri direccionServidor = Uri.parse(
  'https://dreamt-broken-broadly.ngrok-free.dev',
);

// Una partida en linea terminada, como la guarda el servidor: el mapa, la
// meta y como le fue a cada jugador (de mas a menos puntos).
class PartidaJugada {
  final DateTime terminada;
  final String mapa;
  final int meta;
  final int rondas;
  final List<({String usuario, int puntos, String situacion, bool gano})>
  jugadores;

  const PartidaJugada({
    required this.terminada,
    required this.mapa,
    required this.meta,
    required this.rondas,
    required this.jugadores,
  });

  factory PartidaJugada.desdeJson(Map<String, dynamic> datos) => PartidaJugada(
    terminada: DateTime.parse(datos['terminada'] as String).toLocal(),
    mapa: datos['mapa'] as String,
    meta: datos['meta'] as int,
    rondas: datos['rondas'] as int,
    jugadores: [
      for (final jugador in datos['jugadores'] as List)
        (
          usuario: jugador['usuario'] as String,
          puntos: jugador['puntos'] as int,
          situacion: jugador['situacion'] as String,
          gano: jugador['gano'] as bool,
        ),
    ],
  );
}

// Las partidas en linea que jugo y gano el usuario, y las ultimas.
class HistorialDeCuenta {
  final int jugadas;
  final int ganadas;
  final List<PartidaJugada> partidas;

  const HistorialDeCuenta({
    required this.jugadas,
    required this.ganadas,
    required this.partidas,
  });
}

// Error al hablar con el servidor, con un mensaje para mostrar al jugador.
class ErrorDeCuenta implements Exception {
  final String mensaje;

  const ErrorDeCuenta(this.mensaje);

  @override
  String toString() => mensaje;
}

// Habla con el servidor de cuentas y guarda la sesion abierta (el JWT) en
// memoria mientras la app esta abierta. Avisa a las pantallas cuando cambia
// la sesion.
class ServicioDeCuenta extends ChangeNotifier {
  final Uri servidor;
  final http.Client _cliente;

  String? _token;
  String? _usuario;

  ServicioDeCuenta({Uri? servidor, http.Client? cliente})
    : servidor = servidor ?? direccionServidor,
      _cliente = cliente ?? http.Client();

  bool get conSesion => _token != null;

  // Nombre del usuario con la sesion abierta, o null si no hay sesion.
  String? get usuario => _usuario;

  // JWT de la sesion abierta; el multijugador lo usa para identificarse.
  String? get token => _token;

  Future<void> crearCuenta(String usuario, String contrasena) async {
    await _pedir(
      'POST',
      '/registro',
      cuerpo: {'usuario': usuario, 'contrasena': contrasena},
      esperado: 201,
    );
  }

  Future<void> iniciarSesion(String usuario, String contrasena) async {
    final datos = await _pedir(
      'POST',
      '/login',
      cuerpo: {'usuario': usuario, 'contrasena': contrasena},
      esperado: 200,
    );
    _token = datos['token'] as String;
    _usuario = datos['usuario'] as String;
    notifyListeners();
  }

  // Pregunta al servidor si la sesion sigue siendo valida. Si no, la cierra.
  Future<bool> comprobarSesion() async {
    if (_token == null) {
      return false;
    }
    try {
      final datos = await _pedir('GET', '/cuenta', esperado: 200);
      _usuario = datos['usuario'] as String;
      return true;
    } on ErrorDeCuenta {
      cerrarSesion();
      return false;
    }
  }

  void cerrarSesion() {
    _token = null;
    _usuario = null;
    notifyListeners();
  }

  // Historial de partidas en linea del usuario con la sesion abierta.
  Future<HistorialDeCuenta> historial() async {
    final datos = await _pedir('GET', '/historial', esperado: 200);
    return HistorialDeCuenta(
      jugadas: datos['jugadas'] as int,
      ganadas: datos['ganadas'] as int,
      partidas: [
        for (final partida in datos['partidas'] as List)
          PartidaJugada.desdeJson((partida as Map).cast<String, dynamic>()),
      ],
    );
  }

  // Borra la cuenta en el servidor (pide la contraseña) y cierra la sesion.
  Future<void> borrarCuenta(String contrasena) async {
    await _pedir(
      'DELETE',
      '/cuenta',
      cuerpo: {'contrasena': contrasena},
      esperado: 204,
    );
    cerrarSesion();
  }

  // Hace la peticion con el JWT (si hay sesion) y devuelve el JSON de la
  // respuesta. Si el servidor responde otro estado, lanza ErrorDeCuenta con
  // su mensaje.
  Future<Map<String, dynamic>> _pedir(
    String metodo,
    String ruta, {
    Map<String, Object?>? cuerpo,
    required int esperado,
  }) async {
    final peticion = http.Request(metodo, servidor.resolve(ruta))
      ..headers['content-type'] = 'application/json'
      // Sin esto, ngrok a veces responde con su pagina de aviso en lugar de
      // pasar la peticion al servidor.
      ..headers['ngrok-skip-browser-warning'] = 'true';
    if (_token != null) {
      peticion.headers['authorization'] = 'Bearer $_token';
    }
    if (cuerpo != null) {
      peticion.body = jsonEncode(cuerpo);
    }

    // El limite de tiempo cubre toda la peticion, tambien la conexion: si el
    // telefono no alcanza al servidor, conectar puede tardar minutos.
    Future<http.Response> enviar() async =>
        http.Response.fromStream(await _cliente.send(peticion));

    final http.Response respuesta;
    try {
      respuesta = await enviar().timeout(const Duration(seconds: 10));
    } on Exception {
      throw const ErrorDeCuenta('No se pudo conectar con el servidor.');
    }

    final datos = respuesta.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    if (respuesta.statusCode != esperado) {
      throw ErrorDeCuenta(
        datos['error'] as String? ??
            'Error del servidor (${respuesta.statusCode}).',
      );
    }
    return datos;
  }
}
