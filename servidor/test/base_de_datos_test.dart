import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:servidor/src/base_de_datos.dart';
import 'package:servidor/src/preparar_base_de_datos.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  test('una base de datos con la tabla anterior se actualiza sola', () {
    final carpeta = Directory.systemTemp.createTempSync('servidor_vieja_');
    final ruta = '${carpeta.path}${Platform.pathSeparator}cuentas.db';
    // Tabla como era antes de aceptar acentos (sin nombre_clave).
    final vieja = sqlite3.open(ruta)
      ..execute('''
        CREATE TABLE usuarios (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL UNIQUE COLLATE NOCASE,
          hash_contrasena TEXT NOT NULL,
          creado TEXT NOT NULL
        );
      ''')
      ..execute(
        "INSERT INTO usuarios (nombre, hash_contrasena, creado) "
        "VALUES ('Prueba', 'hash', '2026-10-28T00:00:00Z')",
      );
    vieja.dispose();

    final baseDeDatos = BaseDeDatos.abrir(ruta);
    final existente = baseDeDatos.usuarioPorNombre('PRUEBA');
    final repetido = baseDeDatos.crearUsuario('prueba', 'h', DateTime.now());
    final nuevo = baseDeDatos.crearUsuario('Iñaki', 'h', DateTime.now());
    baseDeDatos.cerrar();
    carpeta.deleteSync(recursive: true);

    // El usuario de antes sigue ahi y se encuentra sin importar mayusculas.
    expect(existente?.nombre, 'Prueba');
    expect(repetido, isNull);
    expect(nuevo?.nombre, 'Iñaki');
  });

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

  test('los usuarios se guardan, se buscan y se borran', () {
    final baseDeDatos = BaseDeDatos.enMemoria();
    final ana = baseDeDatos.crearUsuario('Ana', 'hash', DateTime.now())!;

    // El nombre no distingue mayusculas.
    expect(baseDeDatos.crearUsuario('ana', 'hash', DateTime.now()), isNull);
    expect(baseDeDatos.usuarioPorNombre('ANA')?.id, ana.id);

    baseDeDatos.borrarUsuario(ana.id);
    expect(baseDeDatos.usuarioPorId(ana.id), isNull);
    baseDeDatos.cerrar();
  });
}
