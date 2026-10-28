import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:servidor/src/base_de_datos.dart';
import 'package:servidor/src/preparar_base_de_datos.dart';
import 'package:test/test.dart';

void main() {
  late Directory carpeta;
  late String ruta;

  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('servidor_prueba_');
    ruta = '${carpeta.path}${Platform.pathSeparator}cuentas.db';
  });

  tearDown(() => carpeta.deleteSync(recursive: true));

  test('si no existe, crea la base de datos con los usuarios de prueba', () {
    // Costo minimo de bcrypt para que la prueba sea rapida.
    final seCreo = prepararBaseDeDatos(ruta, costoBcrypt: 4);
    final baseDeDatos = BaseDeDatos.abrir(ruta);
    final usuario = baseDeDatos.usuarioPorNombre('prueba');
    baseDeDatos.cerrar();

    expect(seCreo, isTrue);
    expect(usuario, isNotNull);
    // La contraseña se guarda cifrada, nunca tal cual.
    expect(usuario!.hashContrasena, isNot('prueba1234'));
    expect(BCrypt.checkpw('prueba1234', usuario.hashContrasena), isTrue);
  });

  test('si ya existe, no la modifica', () {
    final real = BaseDeDatos.abrir(ruta);
    real.crearUsuario('real', 'hash', DateTime.now());
    real.cerrar();

    final seCreo = prepararBaseDeDatos(ruta, costoBcrypt: 4);
    final baseDeDatos = BaseDeDatos.abrir(ruta);
    final usuarioReal = baseDeDatos.usuarioPorNombre('real');
    final usuarioDePrueba = baseDeDatos.usuarioPorNombre('prueba');
    baseDeDatos.cerrar();

    expect(seCreo, isFalse);
    expect(usuarioReal, isNotNull);
    expect(usuarioDePrueba, isNull);
  });

  test('los usuarios y sus sesiones se guardan y se borran juntos', () {
    final baseDeDatos = BaseDeDatos.enMemoria();
    final ahora = DateTime.now();
    final ana = baseDeDatos.crearUsuario('Ana', 'hash', ahora)!;

    // El nombre no distingue mayusculas.
    expect(baseDeDatos.crearUsuario('ana', 'hash', ahora), isNull);
    expect(baseDeDatos.usuarioPorNombre('ANA')?.id, ana.id);

    baseDeDatos.crearSesion('s1', ana.id, ahora.add(const Duration(days: 1)));
    baseDeDatos.crearSesion(
      's2',
      ana.id,
      ahora.subtract(const Duration(days: 1)),
    );
    expect(baseDeDatos.sesionValida('s1', ana.id, ahora), isTrue);
    // Una sesion vencida no es valida.
    expect(baseDeDatos.sesionValida('s2', ana.id, ahora), isFalse);

    // Borrar el usuario borra tambien sus sesiones.
    baseDeDatos.borrarUsuario(ana.id);
    expect(baseDeDatos.usuarioPorId(ana.id), isNull);
    expect(baseDeDatos.cantidadDeSesiones(ana.id), 0);
    baseDeDatos.cerrar();
  });
}
