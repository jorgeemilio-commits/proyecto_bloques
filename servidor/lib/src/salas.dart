import 'dart:async';
import 'dart:convert';
import 'dart:math';

// Salas de juego en linea (ver PROTOCOLO_MULTIJUGADOR.md en la raiz del
// repositorio). Aqui esta toda la logica del lobby, sin nada de red: rutas.dart
// conecta cada WebSocket con una Conexion.

// Una conexion de un jugador: por donde se le mandan mensajes.
abstract interface class Conexion {
  void enviar(Map<String, Object?> mensaje);
  void cerrar();
}

// Error que se le manda al jugador, con un mensaje listo para mostrar.
class _ErrorDeSala implements Exception {
  final String codigo;
  final String mensaje;

  const _ErrorDeSala(this.codigo, this.mensaje);
}

const _sesionInvalida = _ErrorDeSala(
  'sesionInvalida',
  'Tu sesión no es válida. Vuelve a iniciar sesión.',
);
const _mensajeInvalido = _ErrorDeSala('mensajeInvalido', 'Mensaje no válido.');

// Letras y numeros del codigo de invitacion: sin 0, O, 1, I ni L, que se
// confunden al dictarlos.
const _letrasDelCodigo = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int largoDelCodigo = 6;
const int maximoDeJugadores = 6;
const int minimoDeJugadores = 2;

// Puntos para ganar segun cuantos jugadores empiezan la partida.
int metaPara(int jugadores) => switch (jugadores) {
  2 => 26,
  3 => 24,
  4 => 22,
  _ => 20,
};

class Sala {
  final String codigo;
  // Jugadores en el orden en que entraron; el primero es el anfitrion.
  final List<String> jugadores = [];
  String mapa = 'clasico';
  // 'lobby' o, ya iniciada, 'valoresIniciales'.
  String fase = 'lobby';
  // Puntos para ganar; se fija al iniciar la partida.
  int? meta;

  Sala(this.codigo);

  String get anfitrion => jugadores.first;
  bool get enLobby => fase == 'lobby';
}

class Salas {
  // Devuelve el nombre del usuario del token, o null si no es valido.
  final String? Function(String token) usuarioDelToken;
  // Tiempo para mandar "hola" al conectarse.
  final Duration esperaHola;
  // Tiempo que un jugador desconectado sigue en la sala esperando volver.
  final Duration esperaReconexion;
  final Random _azar;

  final Map<String, Sala> _salas = {};
  // Conexion actual de cada usuario (solo de los que ya mandaron "hola").
  final Map<String, Conexion> _conexiones = {};
  final Map<Conexion, String> _usuarios = {};
  // Sala en la que esta cada usuario.
  final Map<String, Sala> _salaDe = {};
  final Map<Conexion, Timer> _esperandoHola = {};
  final Map<String, Timer> _esperandoReconexion = {};

  Salas({
    required this.usuarioDelToken,
    this.esperaHola = const Duration(seconds: 10),
    this.esperaReconexion = const Duration(seconds: 80),
    Random? azar,
  }) : _azar = azar ?? Random.secure();

  Sala? sala(String codigo) => _salas[codigo];

  // Una conexion nueva: tiene [esperaHola] para identificarse.
  void conectar(Conexion conexion) {
    _esperandoHola[conexion] = Timer(esperaHola, () {
      _esperandoHola.remove(conexion);
      _enviarError(conexion, _sesionInvalida);
      conexion.cerrar();
    });
  }

  // La conexion se cerro (el jugador salio o se le cayo la red).
  void desconectar(Conexion conexion) {
    _esperandoHola.remove(conexion)?.cancel();
    final usuario = _usuarios.remove(conexion);
    // Si ya la reemplazo una conexion nueva del mismo usuario, no pasa nada.
    if (usuario == null || _conexiones[usuario] != conexion) {
      return;
    }
    _conexiones.remove(usuario);

    final sala = _salaDe[usuario];
    if (sala == null) {
      return;
    }
    _avisar(sala, '$usuario se desconectó.', excepto: usuario);
    _enviarEstado(sala);
    // Si no vuelve a tiempo: en el lobby sale de la sala; en la partida
    // cuenta como que se rindio.
    _esperandoReconexion[usuario] = Timer(esperaReconexion, () {
      _esperandoReconexion.remove(usuario);
      if (_salaDe[usuario] != sala || _conexiones.containsKey(usuario)) {
        return;
      }
      if (sala.enLobby) {
        _salirDelLobby(usuario, sala);
      } else {
        _rendirse(usuario, sala);
      }
    });
  }

  // Llego un mensaje de texto por la conexion.
  void recibir(Conexion conexion, String texto) {
    final Map<String, dynamic> mensaje;
    try {
      final datos = jsonDecode(texto);
      if (datos is! Map<String, dynamic> || datos['tipo'] is! String) {
        throw const FormatException();
      }
      mensaje = datos;
    } on FormatException {
      _enviarError(conexion, _mensajeInvalido);
      return;
    }

    final usuario = _usuarios[conexion];
    try {
      if (usuario == null) {
        _hola(conexion, mensaje);
      } else {
        _atender(usuario, mensaje);
      }
    } on _ErrorDeSala catch (error) {
      _enviarError(conexion, error);
    }
  }

  // Cancela todos los tiempos de espera (al detener el servidor).
  void cerrar() {
    for (final espera in [
      ..._esperandoHola.values,
      ..._esperandoReconexion.values,
    ]) {
      espera.cancel();
    }
  }

  void _hola(Conexion conexion, Map<String, dynamic> mensaje) {
    final token = mensaje['token'];
    final usuario = mensaje['tipo'] == 'hola' && token is String
        ? usuarioDelToken(token)
        : null;
    if (usuario == null) {
      _esperandoHola.remove(conexion)?.cancel();
      _enviarError(conexion, _sesionInvalida);
      conexion.cerrar();
      return;
    }
    _esperandoHola.remove(conexion)?.cancel();

    // Una cuenta, una conexion: la nueva reemplaza a la vieja.
    final vieja = _conexiones[usuario];
    if (vieja != null) {
      _usuarios.remove(vieja);
      _enviarError(
        vieja,
        const _ErrorDeSala(
          'sesionReemplazada',
          'Abriste la partida en otro dispositivo.',
        ),
      );
      vieja.cerrar();
    }
    _conexiones[usuario] = conexion;
    _usuarios[conexion] = usuario;

    // Si estaba en una sala, vuelve a ella.
    _esperandoReconexion.remove(usuario)?.cancel();
    final sala = _salaDe[usuario];
    if (sala == null) {
      _enviarEstadoA(usuario);
    } else {
      if (vieja == null) {
        _avisar(sala, '$usuario volvió.', excepto: usuario);
      }
      _enviarEstado(sala);
    }
  }

  // Atiende un mensaje de un usuario ya identificado.
  void _atender(String usuario, Map<String, dynamic> mensaje) {
    switch (mensaje['tipo']) {
      case 'crearSala':
        _sinSala(usuario);
        final sala = Sala(_codigoNuevo());
        _salas[sala.codigo] = sala;
        _entrar(usuario, sala);
      case 'unirse':
        _sinSala(usuario);
        final codigo = mensaje['codigo'];
        final sala = codigo is String
            ? _salas[codigo.trim().toUpperCase()]
            : null;
        if (sala == null) {
          throw const _ErrorDeSala(
            'salaNoExiste',
            'No existe una sala con ese código.',
          );
        }
        if (!sala.enLobby) {
          throw const _ErrorDeSala('partidaEmpezada', 'Esa partida ya empezó.');
        }
        if (sala.jugadores.length >= maximoDeJugadores) {
          throw const _ErrorDeSala(
            'salaLlena',
            'La sala ya tiene $maximoDeJugadores jugadores.',
          );
        }
        _entrar(usuario, sala);
      case 'salir':
        final sala = _salaDe[usuario];
        // En la partida no se sale: se rinde (paso de desconexiones).
        if (sala == null || !sala.enLobby) {
          throw _mensajeInvalido;
        }
        _salirDelLobby(usuario, sala);
      case 'rendirse':
        final sala = _salaDe[usuario];
        if (sala == null || sala.enLobby) {
          throw _mensajeInvalido;
        }
        _rendirse(usuario, sala);
      case 'elegirMapa':
        final sala = _salaDelAnfitrion(usuario);
        final mapa = mensaje['mapa'];
        if (mapa is! String || !RegExp(r'^[a-z0-9_]+$').hasMatch(mapa)) {
          throw _mensajeInvalido;
        }
        sala.mapa = mapa;
        _enviarEstado(sala);
      case 'iniciar':
        final sala = _salaDelAnfitrion(usuario);
        if (sala.jugadores.length < minimoDeJugadores) {
          throw const _ErrorDeSala(
            'faltanJugadores',
            'Se necesitan al menos $minimoDeJugadores jugadores para empezar.',
          );
        }
        // La partida en si se agrega en el siguiente paso; por ahora solo
        // cierra la sala a nuevos jugadores y fija la meta.
        sala.fase = 'valoresIniciales';
        sala.meta = metaPara(sala.jugadores.length);
        _enviarEstado(sala);
      default:
        throw _mensajeInvalido;
    }
  }

  // Lanza un error si el usuario ya esta en una sala.
  void _sinSala(String usuario) {
    if (_salaDe.containsKey(usuario)) {
      throw const _ErrorDeSala('yaEnSala', 'Ya estás en una sala.');
    }
  }

  // Devuelve la sala del usuario si es el anfitrion; si no, lanza un error.
  Sala _salaDelAnfitrion(String usuario) {
    final sala = _salaDe[usuario];
    if (sala == null || !sala.enLobby) {
      throw _mensajeInvalido;
    }
    if (sala.anfitrion != usuario) {
      throw const _ErrorDeSala(
        'soloAnfitrion',
        'Solo el anfitrión puede hacer eso.',
      );
    }
    return sala;
  }

  // Agrega al usuario a la sala y le manda el estado a todos.
  void _entrar(String usuario, Sala sala) {
    sala.jugadores.add(usuario);
    _salaDe[usuario] = sala;
    _enviarEstado(sala);
  }

  // El usuario sale de la sala en el lobby (con "salir" o por no volver a
  // tiempo). Si es el anfitrion, la sala se deshace y salen todos.
  void _salirDelLobby(String usuario, Sala sala) {
    if (usuario == sala.anfitrion) {
      _avisar(sala, 'El anfitrión cerró la sala.', excepto: usuario);
      final todos = [...sala.jugadores];
      for (final jugador in todos) {
        _sacarDeLaSala(jugador, sala);
      }
      for (final jugador in todos) {
        _enviarEstadoA(jugador);
      }
      return;
    }
    _sacarDeLaSala(usuario, sala);
    _avisar(sala, '$usuario salió de la sala.');
    _enviarEstadoA(usuario);
    _enviarEstado(sala);
  }

  // El usuario se rinde en la partida (con "rendirse" o por no volver a
  // tiempo): sale de la sala y los demas siguen. (En el paso de la partida se
  // quedara en la lista como rendido, con sus puntos.)
  void _rendirse(String usuario, Sala sala) {
    _sacarDeLaSala(usuario, sala);
    _avisar(sala, '$usuario se rindió.');
    _enviarEstadoA(usuario);
    _enviarEstado(sala);
  }

  // Saca al usuario de la sala; si ya no queda nadie, la sala se borra.
  void _sacarDeLaSala(String usuario, Sala sala) {
    sala.jugadores.remove(usuario);
    _salaDe.remove(usuario);
    _esperandoReconexion.remove(usuario)?.cancel();
    if (sala.jugadores.isEmpty) {
      _salas.remove(sala.codigo);
    }
  }

  // Genera un codigo de invitacion que no este en uso.
  String _codigoNuevo() {
    while (true) {
      final codigo = String.fromCharCodes([
        for (var i = 0; i < largoDelCodigo; i++)
          _letrasDelCodigo.codeUnitAt(_azar.nextInt(_letrasDelCodigo.length)),
      ]);
      if (!_salas.containsKey(codigo)) {
        return codigo;
      }
    }
  }

  // Manda el estado de la sala a todos los jugadores conectados.
  void _enviarEstado(Sala sala) {
    for (final usuario in sala.jugadores) {
      _enviarEstadoA(usuario);
    }
  }

  // Manda el estado de la sala a un jugador, o "sinSala" si no esta en ninguna.
  void _enviarEstadoA(String usuario) {
    final conexion = _conexiones[usuario];
    if (conexion == null) {
      return;
    }
    final sala = _salaDe[usuario];
    conexion.enviar({
      'tipo': 'estado',
      'fase': sala?.fase ?? 'sinSala',
      'usuario': usuario,
      if (sala != null) ...{
        'codigo': sala.codigo,
        'anfitrion': sala.anfitrion,
        'mapa': sala.mapa,
        'maximo': maximoDeJugadores,
        if (sala.meta != null) 'meta': sala.meta,
        'jugadores': [
          for (final jugador in sala.jugadores)
            {'usuario': jugador, 'conectado': _conexiones.containsKey(jugador)},
        ],
      },
    });
  }

  // Manda un aviso a todos los jugadores conectados de la sala, excepto a [excepto].
  void _avisar(Sala sala, String texto, {String? excepto}) {
    for (final usuario in sala.jugadores) {
      if (usuario != excepto) {
        _conexiones[usuario]?.enviar({'tipo': 'aviso', 'texto': texto});
      }
    }
  }

  // Manda un error a la conexion del jugador.
  void _enviarError(Conexion conexion, _ErrorDeSala error) {
    conexion.enviar({
      'tipo': 'error',
      'codigo': error.codigo,
      'mensaje': error.mensaje,
    });
  }
}
