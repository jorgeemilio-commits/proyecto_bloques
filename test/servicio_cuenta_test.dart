import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:proyecto_bloques/cuenta/servicio_cuenta.dart';
import 'ayudantes.dart';
import 'consola.dart';

void main() {
  test('crear cuenta, iniciar sesion y cerrar sesion', () async {
    final servicio = ServicioDeCuenta(cliente: servidorFalso());
    var avisos = 0;
    servicio.addListener(() => avisos++);

    await servicio.crearCuenta('Ana', 'secreta123');
    final antes = servicio.conSesion;
    await servicio.iniciarSesion('Ana', 'secreta123');
    final durante = (servicio.conSesion, servicio.usuario);
    final valida = await servicio.comprobarSesion();
    servicio.cerrarSesion();

    expect(antes, isFalse);
    expect(durante, (true, 'Ana'));
    expect(valida, isTrue);
    expect((servicio.conSesion, servicio.usuario), (false, null));
    // Avisa a las pantallas al entrar y al salir.
    expect(avisos, 2);
    mostrar('Cuenta creada; sesion de $durante; al cerrar, sin sesion.');
  });

  test('los errores del servidor llegan con su mensaje', () async {
    final servicio = ServicioDeCuenta(cliente: servidorFalso());
    await servicio.crearCuenta('Ana', 'secreta123');

    Future<String> mensajeDe(Future<void> accion) async {
      try {
        await accion;
        return 'sin error';
      } on ErrorDeCuenta catch (error) {
        return error.mensaje;
      }
    }

    final repetida = await mensajeDe(servicio.crearCuenta('Ana', 'otra12345'));
    final malaContrasena = await mensajeDe(
      servicio.iniciarSesion('Ana', 'equivocada'),
    );

    expect(repetida, 'Ese nombre de usuario ya existe.');
    expect(malaContrasena, 'Usuario o contraseña incorrectos.');
    expect(servicio.conSesion, isFalse);
    mostrar('Errores: "$repetida" y "$malaContrasena".');
  });

  test('borrar la cuenta pide la contraseña y cierra la sesion', () async {
    final servicio = ServicioDeCuenta(cliente: servidorFalso());
    await servicio.crearCuenta('Ana', 'secreta123');
    await servicio.iniciarSesion('Ana', 'secreta123');

    await expectLater(
      servicio.borrarCuenta('equivocada'),
      throwsA(isA<ErrorDeCuenta>()),
    );
    final sigueConSesion = servicio.conSesion;
    await servicio.borrarCuenta('secreta123');

    expect(sigueConSesion, isTrue);
    expect(servicio.conSesion, isFalse);
    // La cuenta ya no existe: no se puede volver a entrar.
    await expectLater(
      servicio.iniciarSesion('Ana', 'secreta123'),
      throwsA(isA<ErrorDeCuenta>()),
    );
    mostrar(
      'Con la contraseña mala no se borra; con la buena se borra y sale.',
    );
  });

  test('sin servidor da un error claro', () async {
    final servicio = ServicioDeCuenta(
      cliente: MockClient((_) => throw const SocketExceptionFalsa()),
    );

    await expectLater(
      servicio.iniciarSesion('Ana', 'secreta123'),
      throwsA(
        isA<ErrorDeCuenta>().having(
          (error) => error.mensaje,
          'mensaje',
          'No se pudo conectar con el servidor.',
        ),
      ),
    );
    mostrar('Sin servidor: "No se pudo conectar con el servidor."');
  });
}

// Error de conexion como el que da http cuando el servidor no responde.
class SocketExceptionFalsa implements Exception {
  const SocketExceptionFalsa();
}
