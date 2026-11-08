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
const _sesionReemplazada = _ErrorDeSala(
  'sesionReemplazada',
  'Tu cuenta se abrió en otro dispositivo.',
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

// Un jugador que se identifico con "hola": su conexion actual, la sala en la
// que esta y, si se desconecto estando en una sala, el tiempo que le queda
// para volver. Su lugar en la sala dura mas que su conexion.
class Jugador {
  final String nombre;
  // null si esta desconectado.
  Conexion? conexion;
  Sala? sala;
  Timer? esperaReconexion;

  Jugador(this.nombre);

  bool get conectado => conexion != null;

  void enviar(Map<String, Object?> mensaje) => conexion?.enviar(mensaje);
}

class Sala {
  final String codigo;
  // Jugadores en el orden en que entraron; el primero es el anfitrion.
  final List<Jugador> jugadores = [];
  String mapa = 'clasico';
  // 'lobby' o, ya iniciada, 'valoresIniciales'.
  String fase = 'lobby';
  // Puntos para ganar; se fija al iniciar la partida.
  int? meta;

  Sala(this.codigo);

  Jugador get anfitrion => jugadores.first;
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

  // Salas por su codigo de invitacion.
  final Map<String, Sala> _salas = {};
  // Jugadores por su nombre: los conectados y los que esperan volver a su
  // sala.
  final Map<String, Jugador> _jugadores = {};
  // De quien es cada conexion (solo las que ya mandaron "hola").
  final Map<Conexion, Jugador> _duenos = {};
  // Conexiones que todavia no mandan "hola", con su tiempo para hacerlo.
  final Map<Conexion, Timer> _esperandoHola = {};

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
    final jugador = _duenos.remove(conexion);
    // Si ya la reemplazo una conexion nueva del mismo jugador, no pasa nada.
    if (jugador == null || jugador.conexion != conexion) {
      return;
    }
    jugador.conexion = null;

    final sala = jugador.sala;
    if (sala == null) {
      _olvidarSiSobra(jugador);
      return;
    }
    _avisar(sala, '${jugador.nombre} se desconectó.', excepto: jugador);
    _enviarEstado(sala);
    // Si no vuelve a tiempo: en el lobby sale de la sala; en la partida
    // cuenta como que se rindio.
    jugador.esperaReconexion = Timer(esperaReconexion, () {
      jugador.esperaReconexion = null;
      if (jugador.sala != sala || jugador.conectado) {
        return;
      }
      if (sala.enLobby) {
        _salirDelLobby(jugador, sala);
      } else {
        _rendirse(jugador, sala);
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

    final jugador = _duenos[conexion];
    try {
      if (jugador == null) {
        _hola(conexion, mensaje);
      } else {
        _atender(jugador, mensaje);
      }
    } on _ErrorDeSala catch (error) {
      _enviarError(conexion, error);
    }
  }

  // El usuario inicio sesion de nuevo (en otro dispositivo): si tenia una
  // conexion abierta, se le avisa y se cierra, como si se le cayera la red.
  // Su lugar en la sala se guarda los 80 segundos de siempre, por si entra
  // desde el dispositivo nuevo.
  void sesionNueva(String usuario) {
    final conexion = _jugadores[usuario]?.conexion;
    if (conexion == null) {
      return;
    }
    _enviarError(conexion, _sesionReemplazada);
    desconectar(conexion);
    conexion.cerrar();
  }

  // Cancela todos los tiempos de espera (al detener el servidor).
  void cerrar() {
    for (final espera in _esperandoHola.values) {
      espera.cancel();
    }
    for (final jugador in _jugadores.values) {
      jugador.esperaReconexion?.cancel();
    }
  }

  void _hola(Conexion conexion, Map<String, dynamic> mensaje) {
    _esperandoHola.remove(conexion)?.cancel();
    final token = mensaje['token'];
    final usuario = mensaje['tipo'] == 'hola' && token is String
        ? usuarioDelToken(token)
        : null;
    if (usuario == null) {
      _enviarError(conexion, _sesionInvalida);
      conexion.cerrar();
      return;
    }

    final jugador = _jugadores.putIfAbsent(usuario, () => Jugador(usuario));
    // Una cuenta, una conexion: la nueva reemplaza a la vieja.
    final vieja = jugador.conexion;
    if (vieja != null) {
      _duenos.remove(vieja);
      _enviarError(vieja, _sesionReemplazada);
      vieja.cerrar();
    }
    jugador.conexion = conexion;
    _duenos[conexion] = jugador;

    // Si estaba en una sala, vuelve a ella.
    jugador.esperaReconexion?.cancel();
    jugador.esperaReconexion = null;
    final sala = jugador.sala;
    if (sala == null) {
      _enviarEstadoA(jugador);
    } else {
      if (vieja == null) {
        _avisar(sala, '${jugador.nombre} volvió.', excepto: jugador);
      }
      _enviarEstado(sala);
    }
  }

  // Atiende un mensaje de un jugador ya identificado.
  void _atender(Jugador jugador, Map<String, dynamic> mensaje) {
    switch (mensaje['tipo']) {
      case 'crearSala':
        _sinSala(jugador);
        final sala = Sala(_codigoNuevo());
        _salas[sala.codigo] = sala;
        _entrar(jugador, sala);
      case 'unirse':
        _sinSala(jugador);
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
        _entrar(jugador, sala);
      case 'salir':
        final sala = jugador.sala;
        // En la partida no se sale: se rinde.
        if (sala == null || !sala.enLobby) {
          throw _mensajeInvalido;
        }
        _salirDelLobby(jugador, sala);
      case 'rendirse':
        final sala = jugador.sala;
        if (sala == null || sala.enLobby) {
          throw _mensajeInvalido;
        }
        _rendirse(jugador, sala);
      case 'elegirMapa':
        final sala = _salaDelAnfitrion(jugador);
        final mapa = mensaje['mapa'];
        if (mapa is! String || !RegExp(r'^[a-z0-9_]+$').hasMatch(mapa)) {
          throw _mensajeInvalido;
        }
        sala.mapa = mapa;
        _enviarEstado(sala);
      case 'iniciar':
        final sala = _salaDelAnfitrion(jugador);
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

  // Lanza un error si el jugador ya esta en una sala.
  void _sinSala(Jugador jugador) {
    if (jugador.sala != null) {
      throw const _ErrorDeSala('yaEnSala', 'Ya estás en una sala.');
    }
  }

  // Devuelve la sala del jugador si es el anfitrion; si no, lanza un error.
  Sala _salaDelAnfitrion(Jugador jugador) {
    final sala = jugador.sala;
    if (sala == null || !sala.enLobby) {
      throw _mensajeInvalido;
    }
    if (sala.anfitrion != jugador) {
      throw const _ErrorDeSala(
        'soloAnfitrion',
        'Solo el anfitrión puede hacer eso.',
      );
    }
    return sala;
  }

  // Agrega al jugador a la sala y le manda el estado a todos.
  void _entrar(Jugador jugador, Sala sala) {
    sala.jugadores.add(jugador);
    jugador.sala = sala;
    _enviarEstado(sala);
  }

  // El jugador sale de la sala en el lobby (con "salir" o por no volver a
  // tiempo). Si es el anfitrion, la sala se deshace y salen todos.
  void _salirDelLobby(Jugador jugador, Sala sala) {
    if (jugador == sala.anfitrion) {
      _avisar(sala, 'El anfitrión cerró la sala.', excepto: jugador);
      final todos = [...sala.jugadores];
      for (final otro in todos) {
        _sacarDeLaSala(otro, sala);
      }
      for (final otro in todos) {
        _enviarEstadoA(otro);
      }
      return;
    }
    _sacarDeLaSala(jugador, sala);
    _avisar(sala, '${jugador.nombre} salió de la sala.');
    _enviarEstadoA(jugador);
    _enviarEstado(sala);
  }

  // El jugador se rinde en la partida (con "rendirse" o por no volver a
  // tiempo): sale de la sala y los demas siguen. (En el paso de la partida se
  // quedara en la lista como rendido, con sus puntos.)
  void _rendirse(Jugador jugador, Sala sala) {
    _sacarDeLaSala(jugador, sala);
    _avisar(sala, '${jugador.nombre} se rindió.');
    _enviarEstadoA(jugador);
    _enviarEstado(sala);
  }

  // Saca al jugador de la sala; si ya no queda nadie, la sala se borra.
  void _sacarDeLaSala(Jugador jugador, Sala sala) {
    sala.jugadores.remove(jugador);
    jugador.sala = null;
    jugador.esperaReconexion?.cancel();
    jugador.esperaReconexion = null;
    if (sala.jugadores.isEmpty) {
      _salas.remove(sala.codigo);
    }
    _olvidarSiSobra(jugador);
  }

  // Un jugador desconectado y sin sala ya no hace falta guardarlo.
  void _olvidarSiSobra(Jugador jugador) {
    if (!jugador.conectado && jugador.sala == null) {
      _jugadores.remove(jugador.nombre);
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
    for (final jugador in sala.jugadores) {
      _enviarEstadoA(jugador);
    }
  }

  // Manda el estado de su sala a un jugador, o "sinSala" si no esta en
  // ninguna.
  void _enviarEstadoA(Jugador jugador) {
    final sala = jugador.sala;
    jugador.enviar({
      'tipo': 'estado',
      'fase': sala?.fase ?? 'sinSala',
      'usuario': jugador.nombre,
      if (sala != null) ...{
        'codigo': sala.codigo,
        'anfitrion': sala.anfitrion.nombre,
        'mapa': sala.mapa,
        'maximo': maximoDeJugadores,
        if (sala.meta != null) 'meta': sala.meta,
        'jugadores': [
          for (final otro in sala.jugadores)
            {'usuario': otro.nombre, 'conectado': otro.conectado},
        ],
      },
    });
  }

  // Manda un aviso a los jugadores conectados de la sala, excepto a
  // [excepto].
  void _avisar(Sala sala, String texto, {Jugador? excepto}) {
    for (final jugador in sala.jugadores) {
      if (jugador != excepto) {
        jugador.enviar({'tipo': 'aviso', 'texto': texto});
      }
    }
  }

  // Manda un error por la conexion.
  void _enviarError(Conexion conexion, _ErrorDeSala error) {
    conexion.enviar({
      'tipo': 'error',
      'codigo': error.codigo,
      'mensaje': error.mensaje,
    });
  }
}
