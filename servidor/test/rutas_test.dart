import 'dart:convert';

import 'package:servidor/src/base_de_datos.dart';
import 'package:servidor/src/rutas.dart';
import 'package:servidor/src/seguridad.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

// Las pruebas llaman al manejador directamente, sin abrir la red.
void main() {
  late BaseDeDatos baseDeDatos;
  late Handler servidor;

  setUp(() {
    baseDeDatos = BaseDeDatos.enMemoria();
    servidor = crearManejador(
      baseDeDatos: baseDeDatos,
      tokens: Tokens(crearSecreto()),
      costoBcrypt: 4,
    );
  });

  tearDown(() => baseDeDatos.cerrar());

  // Hace una peticion y devuelve el estado y el JSON de la respuesta.
  Future<(int, Map<String, dynamic>?)> pedir(
    String metodo,
    String ruta, {
    Object? cuerpo,
    String? token,
  }) async {
    final respuesta = await servidor(
      Request(
        metodo,
        Uri.parse('http://localhost$ruta'),
        body: cuerpo is String ? cuerpo : jsonEncode(cuerpo),
        headers: {if (token != null) 'authorization': 'Bearer $token'},
      ),
    );
    final texto = await respuesta.readAsString();
    return (
      respuesta.statusCode,
      texto.isEmpty ? null : jsonDecode(texto) as Map<String, dynamic>,
    );
  }

  Future<String> registrarYEntrar(String usuario, String contrasena) async {
    await pedir(
      'POST',
      '/registro',
      cuerpo: {'usuario': usuario, 'contrasena': contrasena},
    );
    final (_, datos) = await pedir(
      'POST',
      '/login',
      cuerpo: {'usuario': usuario, 'contrasena': contrasena},
    );
    return datos!['token'] as String;
  }

  test('crear cuenta, y no se puede repetir el nombre', () async {
    final (creada, datos) = await pedir(
      'POST',
      '/registro',
      cuerpo: {'usuario': 'Ana', 'contrasena': 'secreta123'},
    );
    // "ana" es el mismo usuario que "Ana".
    final (repetida, error) = await pedir(
      'POST',
      '/registro',
      cuerpo: {'usuario': 'ana', 'contrasena': 'otra12345'},
    );

    expect(creada, 201);
    expect(datos!['usuario'], 'Ana');
    expect(repetida, 409);
    expect(error!['error'], 'Ese nombre de usuario ya existe.');
  });

  test('crear cuenta rechaza datos no validos', () async {
    final casos = [
      {'usuario': 'ab', 'contrasena': 'secreta123'},
      {'usuario': 'con espacio', 'contrasena': 'secreta123'},
      {'usuario': 'Ana', 'contrasena': 'corta'},
      {'usuario': 'Ana'},
    ];
    for (final cuerpo in casos) {
      final (estado, _) = await pedir('POST', '/registro', cuerpo: cuerpo);
      expect(estado, 400, reason: '$cuerpo');
    }
    final (noEsJson, _) = await pedir('POST', '/registro', cuerpo: 'hola');
    expect(noEsJson, 400);
  });

  test('iniciar sesion da un token que sirve para ver la cuenta', () async {
    final token = await registrarYEntrar('Ana', 'secreta123');
    final (estado, datos) = await pedir('GET', '/cuenta', token: token);

    expect(estado, 200);
    expect(datos!['usuario'], 'Ana');
  });

  test(
    'un login fallido no dice si fallo el usuario o la contraseña',
    () async {
      await registrarYEntrar('Ana', 'secreta123');
      final (malaContrasena, error1) = await pedir(
        'POST',
        '/login',
        cuerpo: {'usuario': 'Ana', 'contrasena': 'equivocada1'},
      );
      final (noExiste, error2) = await pedir(
        'POST',
        '/login',
        cuerpo: {'usuario': 'Nadie', 'contrasena': 'secreta123'},
      );

      expect((malaContrasena, noExiste), (401, 401));
      expect(error1, error2);
    },
  );

  test('la cuenta pide un token valido', () async {
    final (sinToken, _) = await pedir('GET', '/cuenta');
    final (tokenFalso, _) = await pedir('GET', '/cuenta', token: 'falso');

    expect((sinToken, tokenFalso), (401, 401));
  });

  test('borrar la cuenta pide la contraseña y deja el token sin uso', () async {
    final token = await registrarYEntrar('Ana', 'secreta123');

    final (contrasenaMala, _) = await pedir(
      'DELETE',
      '/cuenta',
      token: token,
      cuerpo: {'contrasena': 'equivocada1'},
    );
    final (borrada, _) = await pedir(
      'DELETE',
      '/cuenta',
      token: token,
      cuerpo: {'contrasena': 'secreta123'},
    );
    final (despues, _) = await pedir('GET', '/cuenta', token: token);
    final (entrar, _) = await pedir(
      'POST',
      '/login',
      cuerpo: {'usuario': 'Ana', 'contrasena': 'secreta123'},
    );

    expect(contrasenaMala, 401);
    expect(borrada, 204);
    // El usuario ya no existe: su token y su contraseña dejan de servir.
    expect((despues, entrar), (401, 401));
  });

  test('una ruta que no existe responde 404', () async {
    final (estado, _) = await pedir('GET', '/otra');

    expect(estado, 404);
  });
}
