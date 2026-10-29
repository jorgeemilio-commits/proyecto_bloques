import 'package:sqlite3/sqlite3.dart';

// Un usuario registrado. Solo se guarda el hash de su contraseña, nunca la
// contraseña.
class Usuario {
  final int id;
  final String nombre;
  final String hashContrasena;
  final DateTime creado;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.hashContrasena,
    required this.creado,
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
    // COLLATE NOCASE: "Ana" y "ana" son el mismo usuario.
    _db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE,
        hash_contrasena TEXT NOT NULL,
        creado TEXT NOT NULL
      );
    ''');
  }

  Usuario? usuarioPorNombre(String nombre) => _unUsuario(
    'SELECT * FROM usuarios WHERE nombre = ? COLLATE NOCASE',
    [nombre],
  );

  Usuario? usuarioPorId(int id) =>
      _unUsuario('SELECT * FROM usuarios WHERE id = ?', [id]);

  // Crea el usuario y lo devuelve, o null si el nombre ya existe.
  Usuario? crearUsuario(String nombre, String hashContrasena, DateTime ahora) {
    try {
      _db.execute(
        'INSERT INTO usuarios (nombre, hash_contrasena, creado) '
        'VALUES (?, ?, ?)',
        [nombre, hashContrasena, ahora.toUtc().toIso8601String()],
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
    );
  }
}
