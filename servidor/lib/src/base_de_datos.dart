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

// Base de datos SQLite con los usuarios y sus sesiones abiertas. Todas las
// consultas usan parametros (?) para evitar inyeccion de SQL.
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
    _db.execute('PRAGMA foreign_keys = ON;');
    // COLLATE NOCASE: "Ana" y "ana" son el mismo usuario.
    _db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE,
        hash_contrasena TEXT NOT NULL,
        creado TEXT NOT NULL
      );
    ''');
    // Una fila por sesion abierta; el JWT lleva su id. Al borrar el usuario
    // se borran sus sesiones (ON DELETE CASCADE).
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sesiones (
        id TEXT PRIMARY KEY,
        usuario_id INTEGER NOT NULL
          REFERENCES usuarios(id) ON DELETE CASCADE,
        expira TEXT NOT NULL
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

  // Borra el usuario y, por la llave foranea, todas sus sesiones.
  void borrarUsuario(int id) {
    _db.execute('DELETE FROM usuarios WHERE id = ?', [id]);
  }

  void crearSesion(String id, int usuarioId, DateTime expira) {
    _db.execute(
      'INSERT INTO sesiones (id, usuario_id, expira) VALUES (?, ?, ?)',
      [id, usuarioId, expira.toUtc().toIso8601String()],
    );
  }

  // Indica si la sesion existe, es de ese usuario y no ha vencido.
  bool sesionValida(String id, int usuarioId, DateTime ahora) {
    final filas = _db.select(
      'SELECT 1 FROM sesiones WHERE id = ? AND usuario_id = ? AND expira > ?',
      [id, usuarioId, ahora.toUtc().toIso8601String()],
    );
    return filas.isNotEmpty;
  }

  void borrarSesion(String id) {
    _db.execute('DELETE FROM sesiones WHERE id = ?', [id]);
  }

  // Limpieza periodica de sesiones que ya vencieron.
  void borrarSesionesVencidas(DateTime ahora) {
    _db.execute('DELETE FROM sesiones WHERE expira <= ?', [
      ahora.toUtc().toIso8601String(),
    ]);
  }

  int cantidadDeSesiones(int usuarioId) =>
      _db.select('SELECT COUNT(*) AS n FROM sesiones WHERE usuario_id = ?', [
            usuarioId,
          ]).first['n']
          as int;

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
