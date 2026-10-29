import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:servidor/src/seguridad.dart';
import 'package:test/test.dart';

void main() {
  test('la contraseña se guarda cifrada y se puede verificar', () {
    final hash = cifrarContrasena('secreta123', costo: 4);

    expect(hash, isNot('secreta123'));
    expect(verificarContrasena('secreta123', hash), isTrue);
    expect(verificarContrasena('otra123456', hash), isFalse);
    // La misma contraseña da un hash distinto cada vez (sal aleatoria).
    expect(cifrarContrasena('secreta123', costo: 4), isNot(hash));
  });

  test('un token valido devuelve el id del usuario', () {
    final tokens = Tokens(crearSecreto());

    expect(tokens.verificar(tokens.crear(7)), 7);
  });

  test('se rechazan tokens falsos, modificados o vencidos', () {
    final secreto = crearSecreto();
    final tokens = Tokens(secreto);
    final token = tokens.crear(7);

    // Firmado con otra clave: alguien que no es el servidor.
    final deOtroServidor = Tokens(crearSecreto()).crear(7);
    // Un caracter cambiado: la firma ya no coincide.
    final modificado =
        '${token.substring(0, token.length - 2)}'
        '${token.endsWith('A') ? 'B' : 'A'}${token[token.length - 1]}';
    // Firmado con la clave correcta pero ya vencido.
    final vencido = JWT({
      'sub': '7',
    }).sign(SecretKey(secreto), expiresIn: const Duration(seconds: -10));

    expect(tokens.verificar(deOtroServidor), isNull);
    expect(tokens.verificar(modificado), isNull);
    expect(tokens.verificar(vencido), isNull);
    expect(tokens.verificar('no-es-un-token'), isNull);
  });
}
