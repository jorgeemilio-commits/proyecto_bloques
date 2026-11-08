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

// Como le fue a un jugador en una partida, para guardarla en el historial.
typedef ResultadoDeJugador = ({
  int usuarioId,
  int puntos,
  String situacion,
  bool gano,
});

// Una partida del historial con el resultado de cada jugador.
class PartidaDelHistorial {
  final DateTime terminada;
  final String mapa;
  final int meta;
  final int rondas;
  final List<({String nombre, int puntos, String situacion, bool gano})>
  jugadores;

  const PartidaDelHistorial({
    required this.terminada,
    required this.mapa,
    required this.meta,
    required this.rondas,
    required this.jugadores,
  });
}

// Las partidas jugadas y ganadas de un usuario y sus ultimas partidas.
class Historial {
  final int jugadas;
  final int ganadas;
  final List<PartidaDelHistorial> partidas;

  const Historial({
    required this.jugadas,
    required this.ganadas,
    required this.partidas,
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

    // Historial: cada partida en linea terminada y como le fue a cada
    // jugador en ella (situacion: 'jugando', 'llegoALaMeta' o 'rendido').
    _db.execute('''
      CREATE TABLE IF NOT EXISTS partidas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        terminada TEXT NOT NULL,
        mapa TEXT NOT NULL,
        meta INTEGER NOT NULL,
        rondas INTEGER NOT NULL
      );
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS resultados (
        partida_id INTEGER NOT NULL,
        usuario_id INTEGER NOT NULL,
        puntos INTEGER NOT NULL,
        situacion TEXT NOT NULL,
        gano INTEGER NOT NULL,
        PRIMARY KEY (partida_id, usuario_id)
      );
    ''');
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

  // Borra al usuario y sus resultados del historial.
  void borrarUsuario(int id) {
    _db.execute('DELETE FROM resultados WHERE usuario_id = ?', [id]);
    _db.execute('DELETE FROM usuarios WHERE id = ?', [id]);
  }

  // Guarda una partida en linea terminada con el resultado de cada jugador.
  void guardarPartida({
    required String mapa,
    required int meta,
    required int rondas,
    required DateTime terminada,
    required List<ResultadoDeJugador> resultados,
  }) {
    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO partidas (terminada, mapa, meta, rondas) '
        'VALUES (?, ?, ?, ?)',
        [terminada.toUtc().toIso8601String(), mapa, meta, rondas],
      );
      final partidaId = _db.lastInsertRowId;
      for (final resultado in resultados) {
        _db.execute(
          'INSERT INTO resultados '
          '(partida_id, usuario_id, puntos, situacion, gano) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            partidaId,
            resultado.usuarioId,
            resultado.puntos,
            resultado.situacion,
            resultado.gano ? 1 : 0,
          ],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Cuantas partidas jugo y gano el usuario, y sus ultimas [limite] partidas
  // (la mas reciente primero) con el resultado de todos los jugadores.
  Historial historial(int usuarioId, {int limite = 20}) {
    final totales = _db.select(
      'SELECT COUNT(*) AS jugadas, COALESCE(SUM(gano), 0) AS ganadas '
      'FROM resultados WHERE usuario_id = ?',
      [usuarioId],
    ).first;
    final partidas = _db.select(
      'SELECT p.id, p.terminada, p.mapa, p.meta, p.rondas '
      'FROM partidas p JOIN resultados r ON r.partida_id = p.id '
      'WHERE r.usuario_id = ? ORDER BY p.id DESC LIMIT ?',
      [usuarioId, limite],
    );
    return Historial(
      jugadas: totales['jugadas'] as int,
      ganadas: totales['ganadas'] as int,
      partidas: [
        for (final partida in partidas)
          PartidaDelHistorial(
            terminada: DateTime.parse(partida['terminada'] as String),
            mapa: partida['mapa'] as String,
            meta: partida['meta'] as int,
            rondas: partida['rondas'] as int,
            // Los jugadores que ya borraron su cuenta no aparecen.
            jugadores: [
              for (final fila in _db.select(
                'SELECT u.nombre, r.puntos, r.situacion, r.gano '
                'FROM resultados r JOIN usuarios u ON u.id = r.usuario_id '
                'WHERE r.partida_id = ? ORDER BY r.puntos DESC',
                [partida['id']],
              ))
                (
                  nombre: fila['nombre'] as String,
                  puntos: fila['puntos'] as int,
                  situacion: fila['situacion'] as String,
                  gano: fila['gano'] == 1,
                ),
            ],
          ),
      ],
    );
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
