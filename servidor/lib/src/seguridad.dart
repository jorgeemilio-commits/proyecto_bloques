import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Cifra una contraseña con bcrypt para guardarla. Cada hash lleva su propia
// sal aleatoria, asi que dos usuarios con la misma contraseña tienen hashes
// distintos. [costo] hace el calculo lento a proposito para dificultar
// adivinar contraseñas; las pruebas usan el minimo (4) para ir rapido.
String cifrarContrasena(String contrasena, {int costo = 10}) =>
    BCrypt.hashpw(contrasena, BCrypt.gensalt(logRounds: costo));

// Indica si la contraseña corresponde al hash guardado.
bool verificarContrasena(String contrasena, String hash) =>
    BCrypt.checkpw(contrasena, hash);

// Crea y verifica los tokens de sesion (JWT firmados con HS256). Solo quien
// conoce el [secreto] (el servidor) puede crear tokens validos.
class Tokens {
  final SecretKey _clave;
  final Duration duracion;

  Tokens(String secreto, {this.duracion = const Duration(days: 7)})
    : _clave = SecretKey(secreto);

  // Token para el usuario: lleva su id (sub) y cuando vence (exp).
  String crear(int usuarioId) => JWT({
    'sub': '$usuarioId',
  }).sign(_clave, algorithm: JWTAlgorithm.HS256, expiresIn: duracion);

  // Devuelve el id del usuario del token, o null si el token es falso, fue
  // modificado o ya vencio.
  int? verificar(String token) {
    try {
      final datos = JWT.verify(token, _clave).payload;
      if (datos is! Map || datos['sub'] is! String) {
        return null;
      }
      return int.tryParse(datos['sub'] as String);
    } on JWTException {
      return null;
    }
  }
}

// Clave secreta aleatoria para firmar los JWT. El servidor la crea una vez y
// la guarda en su carpeta de datos.
String crearSecreto() {
  final azar = Random.secure();
  return base64Url.encode([for (var i = 0; i < 32; i++) azar.nextInt(256)]);
}
