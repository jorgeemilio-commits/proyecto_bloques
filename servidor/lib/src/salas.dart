import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'partida.dart';

part 'sala.dart';
part 'salas_estado.dart';
part 'salas_partida.dart';

// Salas de juego en linea (ver PROTOCOLO_MULTIJUGADOR.md en la raiz del
// repositorio), sin nada de red: rutas.dart conecta cada WebSocket con una
// Conexion. Aqui estan las conexiones, los mensajes y el lobby; el resto de
// la clase esta en sus partes: sala.dart (Jugador, Sala y constantes),
// salas_partida.dart (tiempos de la partida y rendirse) y salas_estado.dart
// (los mensajes que se mandan). Las reglas de la partida estan en partida.dart.

class Salas {
  // Devuelve el nombre del usuario del token, o null si no es valido.
  final String? Function(String token) usuarioDelToken;
  // Se llama una vez cuando termina una partida (con al menos una ronda
  // jugada), para guardarla en el historial. Devuelve cuanto cambio el Elo
  // de cada jugador, para mostrarlo en los resultados.
  final Map<String, int> Function(Sala sala)? alTerminarPartida;
  // Elo de un jugador por su nombre (para mostrarlo en la sala de espera), o
  // null si no se sabe.
  final int? Function(String nombre)? eloDe;
  // Tiempo para mandar "hola" al conectarse.
  final Duration esperaHola;
  // Tiempo que un jugador desconectado sigue en la sala esperando volver.
  final Duration esperaReconexion;
  // Tiempos de la partida: para poner los valores iniciales y para ver los
  // resultados antes de la siguiente ronda. El de cada ronda lo elige el
  // anfitrion (segundosPorRonda).
  final Duration esperaValoresIniciales;
  final Duration esperaEntreRondas;
  // Cuanto dura "un segundo" del tiempo por ronda. Es un segundo de verdad;
  // las pruebas lo acortan para no tener que esperar.
  final Duration segundo;
  // Tiempo que se guarda una sala con la partida terminada.
  final Duration esperaSalaTerminada;
  // Codigos de invitacion, dados y valores iniciales al azar.
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
    this.alTerminarPartida,
    this.eloDe,
    this.esperaHola = const Duration(seconds: 10),
    this.esperaReconexion = const Duration(seconds: 15),
    this.esperaValoresIniciales = const Duration(minutes: 1),
    this.segundo = const Duration(seconds: 1),
    this.esperaEntreRondas = const Duration(seconds: 1),
    this.esperaSalaTerminada = const Duration(minutes: 5),
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
    // En la ronda no se le espera: si ya jugaron todos los conectados, la
    // ronda termina (el desconectado pasa).
    _revisarRonda(sala);
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
        if (jugador.sala == sala) {
          _salirDeLaPartida(jugador, sala);
        }
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
  // Su lugar en la sala se guarda los 15 segundos de siempre, por si entra
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
    for (final sala in _salas.values) {
      sala.temporizador?.cancel();
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
        if (sala == null) {
          throw _mensajeInvalido;
        }
        if (sala.enLobby) {
          _salirDelLobby(jugador, sala);
        } else {
          // En la partida solo sale quien ya no juega (se rindio, llego a la
          // meta o ya termino); quien sigue jugando primero se rinde.
          final partida = sala.partida!;
          final sigueJugando = partida.de(jugador.nombre)?.jugando ?? false;
          if (sigueJugando && partida.fase != 'terminada') {
            throw _mensajeInvalido;
          }
          _salirDeLaPartida(jugador, sala);
        }
      case 'rendirse':
        final sala = jugador.sala;
        if (sala == null || sala.enLobby) {
          throw _mensajeInvalido;
        }
        _rendirse(jugador, sala);
      case 'listo':
        final sala = jugador.sala;
        final listo = mensaje['listo'];
        if (sala == null || !sala.enLobby || listo is! bool) {
          throw _mensajeInvalido;
        }
        if (listo) {
          sala.listos.add(jugador);
        } else {
          sala.listos.remove(jugador);
        }
        _enviarEstado(sala);
      case 'elegirMapa':
        final sala = _salaDelAnfitrion(jugador);
        final mapa = mensaje['mapa'];
        if (mapa is! String || !RegExp(r'^[a-z0-9_]+$').hasMatch(mapa)) {
          throw _mensajeInvalido;
        }
        // Con otro mapa, todos vuelven a confirmar que estan listos.
        if (mapa != sala.mapa) {
          sala.listos.clear();
        }
        sala.mapa = mapa;
        _enviarEstado(sala);
      case 'elegirTiempo':
        final sala = _salaDelAnfitrion(jugador);
        final segundos = mensaje['segundos'];
        if (segundos != null &&
            (segundos is! int || !tiemposPorRonda.contains(segundos))) {
          throw _mensajeInvalido;
        }
        // Con otro tiempo, todos vuelven a confirmar que estan listos.
        if (segundos != sala.segundosPorRonda) {
          sala.listos.clear();
        }
        sala.segundosPorRonda = segundos as int?;
        _enviarEstado(sala);
      case 'iniciar':
        final sala = _salaDelAnfitrion(jugador);
        if (sala.jugadores.length < minimoDeJugadores) {
          throw const _ErrorDeSala(
            'faltanJugadores',
            'Se necesitan al menos $minimoDeJugadores jugadores para empezar.',
          );
        }
        if (!sala.todosListos) {
          throw const _ErrorDeSala(
            'faltanListos',
            'Todos los jugadores deben estar listos para empezar.',
          );
        }
        // Empieza la partida: la sala se cierra a nuevos jugadores y la meta
        // queda fija. Si el anfitrion eligio tiempo por ronda, tambien hay un
        // tiempo para poner los valores iniciales; al acabarse, quien no los
        // puso los recibe al azar. Sin limite se espera a que todos los
        // pongan (quien se desconecta y no vuelve se rinde y ya no se le
        // espera).
        final partida = Partida([
          for (final otro in sala.jugadores) otro.nombre,
        ]);
        sala.partida = partida;
        if (sala.segundosPorRonda != null) {
          _programar(sala, esperaValoresIniciales, () {
            partida.valoresAlAzar(_azar);
            _empezarRonda(sala);
          });
        } else {
          _sinTiempo(sala);
        }
        _enviarEstado(sala);
      case 'valoresIniciales':
        final (sala, partida, participante) = _enLaPartida(jugador);
        final valores = mensaje['valores'];
        if (valores is! List ||
            valores.any((valor) => valor is! int) ||
            !partida.ponerValores(participante, valores.cast<int>())) {
          throw _mensajeInvalido;
        }
        if (partida.todosTienenValores) {
          _empezarRonda(sala);
        } else {
          _enviarEstado(sala);
        }
      case 'colocar':
      case 'pasar':
        final (sala, partida, participante) = _enLaPartida(jugador);
        // Una jugada vieja (de otra ronda) que llego tarde no cuenta.
        if (mensaje['ronda'] != partida.ronda) {
          throw _mensajeInvalido;
        }
        final jugada = mensaje['tipo'] == 'colocar'
            ? _leerJugada(mensaje)
            : null;
        if (!partida.jugar(participante, jugada)) {
          throw _mensajeInvalido;
        }
        _revisarRonda(sala);
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

  // Saca al jugador de la sala; si ya no queda nadie, la sala se borra.
  void _sacarDeLaSala(Jugador jugador, Sala sala) {
    sala.listos.remove(jugador);
    sala.jugadores.remove(jugador);
    jugador.sala = null;
    jugador.esperaReconexion?.cancel();
    jugador.esperaReconexion = null;
    if (sala.jugadores.isEmpty) {
      sala.temporizador?.cancel();
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
}
