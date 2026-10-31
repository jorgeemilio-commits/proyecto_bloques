import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Direccion del servidor de cuentas (servidor/bin/servidor.dart), que corre
// en la computadora. Los telefonos se conectan a la zona Wi-Fi que comparte
// esa computadora, donde ella siempre tiene la IP 192.168.137.1. En la misma
// computadora (Windows) se usa localhost, que funciona aunque la zona Wi-Fi
// este apagada. Usa el puerto 8081 porque el 8080 lo ocupa Apache de XAMPP.
final Uri direccionServidor = Uri.parse(
  defaultTargetPlatform == TargetPlatform.windows
      ? 'http://localhost:8081'
      : 'http://192.168.137.1:8081',
);

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
      ..headers['content-type'] = 'application/json';
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
