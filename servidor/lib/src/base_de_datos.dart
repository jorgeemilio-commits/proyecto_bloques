import 'package:sqlite3/sqlite3.dart';

// Un usuario registrado. Solo se guarda el hash de su contraseña, nunca la
// contraseña.
class Usuario {
  final int id;
  final String nombre;
  final String hashContrasena;
  final DateTime creado;
  // Sube con cada inicio de sesion. El token lleva el numero con el que se
  // creo, asi que solo vale el del ultimo inicio de sesion: la cuenta solo
  // puede estar abierta en un dispositivo.
  final int versionSesion;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.hashContrasena,
    required this.creado,
    this.versionSesion = 0,
  });
}

// Base de datos SQLite con los usuarios. Todas las consultas usan parametros
// (?) para evitar inyeccion de SQL.
class BaseDeDatos {
  final Database _db;

  BaseDeDatos.abrir(String ruta) : _db = sqlite3.open(ruta) {
    _crearTablas();
  }

  // Para las pruebas: no deja archivos.
  BaseDeDatos.enMemoria() : _db = sqlite3.openInMemory() {
    _crearTablas();
  }

  void _crearTablas() {
    // nombre: como lo escribio el usuario ("José"), para mostrarlo.
    // nombre_clave: en minusculas ("josé"), y es el que no se puede repetir;
    // asi "JOSÉ" y "josé" son el mismo usuario. Se calcula con Dart porque
    // SQLite solo pasa a minusculas las letras sin acento.
    _db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        nombre_clave TEXT NOT NULL,
        hash_contrasena TEXT NOT NULL,
        creado TEXT NOT NULL,
        version_sesion INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Bases de datos creadas antes de nombre_clave: se agrega la columna con
    // los nombres en minusculas (eran solo letras sin acento).
    final columnas = _db.select('PRAGMA table_info(usuarios)');
    if (!columnas.any((columna) => columna['name'] == 'nombre_clave')) {
      _db.execute('ALTER TABLE usuarios ADD COLUMN nombre_clave TEXT');
      _db.execute('UPDATE usuarios SET nombre_clave = lower(nombre)');
    }
    // Bases de datos creadas antes de version_sesion.
    if (!columnas.any((columna) => columna['name'] == 'version_sesion')) {
      _db.execute(
        'ALTER TABLE usuarios ADD COLUMN version_sesion '
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    _db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS usuarios_nombre_clave '
      'ON usuarios (nombre_clave)',
    );
  }

  Usuario? usuarioPorNombre(String nombre) => _unUsuario(
    'SELECT * FROM usuarios WHERE nombre_clave = ?',
    [nombre.toLowerCase()],
  );

  Usuario? usuarioPorId(int id) =>
      _unUsuario('SELECT * FROM usuarios WHERE id = ?', [id]);

  // Crea el usuario y lo devuelve, o null si el nombre ya existe.
  Usuario? crearUsuario(String nombre, String hashContrasena, DateTime ahora) {
    try {
      _db.execute(
        'INSERT INTO usuarios (nombre, nombre_clave, hash_contrasena, creado) '
        'VALUES (?, ?, ?, ?)',
        [
          nombre,
          nombre.toLowerCase(),
          hashContrasena,
          ahora.toUtc().toIso8601String(),
        ],
      );
    } on SqliteException catch (error) {
      if (error.extendedResultCode == 2067) {
        // SQLITE_CONSTRAINT_UNIQUE: el nombre ya esta registrado.
        return null;
      }
      rethrow;
    }
    return usuarioPorId(_db.lastInsertRowId);
  }

  // Empieza una sesion nueva del usuario (al iniciar sesion) y devuelve su
  // numero. Los tokens de sesiones anteriores dejan de valer.
  int nuevaSesion(int id) {
    _db.execute(
      'UPDATE usuarios SET version_sesion = version_sesion + 1 WHERE id = ?',
      [id],
    );
    return usuarioPorId(id)!.versionSesion;
  }

  void borrarUsuario(int id) {
    _db.execute('DELETE FROM usuarios WHERE id = ?', [id]);
  }

  void cerrar() => _db.dispose();

  Usuario? _unUsuario(String consulta, List<Object?> parametros) {
    final filas = _db.select(consulta, parametros);
    if (filas.isEmpty) {
      return null;
    }
    final fila = filas.first;
    return Usuario(
      id: fila['id'] as int,
      nombre: fila['nombre'] as String,
      hashContrasena: fila['hash_contrasena'] as String,
      creado: DateTime.parse(fila['creado'] as String),
      versionSesion: fila['version_sesion'] as int,
    );
  }
}
