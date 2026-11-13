import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'partida.dart';

// Salas de juego en linea (ver PROTOCOLO_MULTIJUGADOR.md en la raiz del
// repositorio). Aqui estan el lobby y los tiempos de la partida, sin nada de
// red: rutas.dart conecta cada WebSocket con una Conexion, y las reglas de la
// partida estan en partida.dart.

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
// Tiempos por ronda que puede elegir el anfitrion, en segundos. Sin elegir
// ninguno (null), las rondas no tienen limite.
const List<int> tiemposPorRonda = [20, 30, 40, 60, 90];

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
  // Jugadores en el orden en que entraron; el primero es el anfitrion. En la
  // partida, quien se rinde sale de esta lista (pero sigue en la partida).
  final List<Jugador> jugadores = [];
  String mapa = 'clasico';
  // Segundos por ronda que eligio el anfitrion, o null si no hay limite.
  int? segundosPorRonda;
  // null mientras se esta en el lobby.
  Partida? partida;
  // Tiempo de la fase actual de la partida (valores iniciales, ronda o entre
  // rondas) y cuando se acaba.
  Timer? temporizador;
  DateTime? limite;
  // Si la partida ya se guardo en el historial (se guarda una sola vez).
  bool guardada = false;
  // Jugadores del lobby que marcaron "Listo". La partida solo se puede
  // iniciar cuando todos lo estan.
  final Set<Jugador> listos = {};

  bool get todosListos => jugadores.every(listos.contains);

  Sala(this.codigo);

  Jugador get anfitrion => jugadores.first;
  bool get enLobby => partida == null;
  String get fase => partida?.fase ?? 'lobby';
}

class Salas {
  // Devuelve el nombre del usuario del token, o null si no es valido.
  final String? Function(String token) usuarioDelToken;
  // Se llama una vez cuando termina una partida (con al menos una ronda
  // jugada), para guardarla en el historial.
  final void Function(Sala sala)? alTerminarPartida;
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
        // Empieza la partida: la sala se cierra a nuevos jugadores, la meta
        // queda fija y hay un tiempo para poner los valores iniciales; al
        // acabarse, quien no los puso los recibe al azar.
        final partida = Partida([
          for (final otro in sala.jugadores) otro.nombre,
        ]);
        sala.partida = partida;
        _programar(sala, esperaValoresIniciales, () {
          partida.valoresAlAzar(_azar);
          _empezarRonda(sala);
        });
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

  // Sala, partida y participante del jugador que juega; si no esta en una
  // partida, lanza un error.
  (Sala, Partida, Participante) _enLaPartida(Jugador jugador) {
    final sala = jugador.sala;
    final partida = sala?.partida;
    final participante = partida?.de(jugador.nombre);
    if (sala == null || partida == null || participante == null) {
      throw _mensajeInvalido;
    }
    return (sala, partida, participante);
  }

  // Lee la jugada de un mensaje "colocar"; si no es valida, lanza un error.
  Jugada _leerJugada(Map<String, dynamic> mensaje) {
    final x = mensaje['x'];
    final y = mensaje['y'];
    final numero = mensaje['numero'];
    final reclamo = mensaje['reclamo'];
    if (x is! int ||
        y is! int ||
        numero is! int ||
        x < 0 ||
        y < 0 ||
        numero < 1 ||
        numero > 6) {
      throw _mensajeInvalido;
    }
    if (reclamo == null) {
      return Jugada(x: x, y: y, numero: numero);
    }
    final region = reclamo is Map ? reclamo['region'] : null;
    final premios = reclamo is Map ? reclamo['premios'] : null;
    if (region is! String ||
        premios is! List ||
        premios.any((premio) => premio is! int)) {
      throw _mensajeInvalido;
    }
    return Jugada(
      x: x,
      y: y,
      numero: numero,
      region: region,
      premios: premios.cast<int>(),
    );
  }

  // Cambia el tiempo de la fase actual de la partida.
  void _programar(Sala sala, Duration espera, void Function() alAcabarse) {
    sala.temporizador?.cancel();
    sala.limite = DateTime.now().add(espera);
    sala.temporizador = Timer(espera, alAcabarse);
  }

  // Tira los dados y empieza la siguiente ronda, con su tiempo si el
  // anfitrion eligio uno. Sin limite, la ronda termina cuando juegan todos
  // los conectados.
  void _empezarRonda(Sala sala) {
    final partida = sala.partida!;
    partida.empezarRonda(_azar);
    final segundos = sala.segundosPorRonda;
    if (segundos == null) {
      sala.temporizador?.cancel();
      sala.temporizador = null;
      sala.limite = null;
    } else {
      _programar(sala, segundo * segundos, () => _terminarRonda(sala));
    }
    _enviarEstado(sala);
  }

  // Si ya jugaron todos los conectados que siguen jugando, termina la ronda;
  // si no, solo avisa del cambio. Los desconectados no se esperan (pasan).
  // Si no hay nadie conectado, se espera a que se acabe el tiempo.
  void _revisarRonda(Sala sala) {
    final partida = sala.partida;
    if (partida != null && partida.fase == 'ronda') {
      final conectados = [
        for (final participante in partida.participantes)
          if (participante.jugando && _sigueConectado(participante, sala))
            participante,
      ];
      if (conectados.isNotEmpty &&
          conectados.every((participante) => participante.yaJugo)) {
        _terminarRonda(sala);
        return;
      }
    }
    _enviarEstado(sala);
  }

  // Termina la ronda: se reparten los puntos y, tras un momento para ver los
  // resultados, empieza la siguiente (o se acaba la partida).
  void _terminarRonda(Sala sala) {
    final partida = sala.partida!;
    partida.resolverRonda();
    if (partida.fase == 'terminada') {
      _terminar(sala);
      return;
    }
    _programar(sala, esperaEntreRondas, () => _empezarRonda(sala));
    _enviarEstado(sala);
  }

  // La partida termino: se muestran los resultados y, si los jugadores no
  // salen antes, la sala se borra despues de [esperaSalaTerminada].
  void _terminar(Sala sala) {
    if (!sala.guardada && sala.partida!.ronda > 0) {
      sala.guardada = true;
      alTerminarPartida?.call(sala);
    }
    sala.limite = null;
    sala.temporizador?.cancel();
    sala.temporizador = Timer(esperaSalaTerminada, () {
      final quedan = [...sala.jugadores];
      for (final jugador in quedan) {
        _sacarDeLaSala(jugador, sala);
      }
      for (final jugador in quedan) {
        _enviarEstadoA(jugador);
      }
      _salas.remove(sala.codigo);
    });
    _enviarEstado(sala);
  }

  // El participante sigue en la sala (no se rindio ni salio) y conectado.
  bool _sigueConectado(Participante participante, Sala sala) {
    final jugador = _jugadores[participante.nombre];
    return jugador != null && jugador.sala == sala && jugador.conectado;
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

  // El jugador deja la partida (con "rendirse" o por no volver a tiempo):
  // queda libre para entrar a otra sala, pero sigue en la partida como
  // rendido, con su tablero y sus puntos, y los demas siguen jugando. Si ya
  // habia llegado a la meta (o la partida termino), solo sale.
  void _rendirse(Jugador jugador, Sala sala) {
    final partida = sala.partida!;
    final participante = partida.de(jugador.nombre);
    final seguiaJugando = participante?.jugando ?? false;
    if (participante != null) {
      partida.rendir(participante);
    }
    _sacarDeLaSala(jugador, sala);
    _enviarEstadoA(jugador);
    if (!_salas.containsKey(sala.codigo)) {
      return;
    }
    if (seguiaJugando) {
      _avisar(sala, '${jugador.nombre} se rindió.');
    }
    if (partida.fase == 'terminada') {
      _terminar(sala);
    } else if (partida.fase == 'valoresIniciales' &&
        partida.todosTienenValores) {
      _empezarRonda(sala);
    } else {
      _revisarRonda(sala);
    }
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
    final partida = sala?.partida;
    final limite = sala?.limite;
    jugador.enviar({
      'tipo': 'estado',
      'fase': sala?.fase ?? 'sinSala',
      'usuario': jugador.nombre,
      if (sala != null) ...{
        'codigo': sala.codigo,
        'anfitrion': sala.anfitrion.nombre,
        'mapa': sala.mapa,
        'segundosPorRonda': sala.segundosPorRonda,
        'maximo': maximoDeJugadores,
        if (partida == null)
          'jugadores': [
            for (final otro in sala.jugadores)
              {
                'usuario': otro.nombre,
                'conectado': otro.conectado,
                'listo': sala.listos.contains(otro),
              },
          ]
        else ...{
          'meta': partida.meta,
          'ronda': partida.ronda,
          'dados': partida.dados,
          // Lo que le queda a los valores iniciales o a la ronda.
          if (limite != null &&
              (partida.fase == 'valoresIniciales' || partida.fase == 'ronda'))
            'restanteMs': max(
              0,
              limite.difference(DateTime.now()).inMilliseconds,
            ),
          'ganadores': partida.ganadores,
          // Veces que se ha reclamado cada region, por su id.
          'reclamos': partida.reclamos,
          'jugadores': [
            for (final participante in partida.participantes)
              _participanteEnJson(participante, sala, partida, jugador),
          ],
        },
      },
    });
  }

  // Un participante como lo ve [para]. Los valores iniciales de los demas no
  // se ven hasta que empieza la primera ronda, para que nadie copie.
  Map<String, Object?> _participanteEnJson(
    Participante participante,
    Sala sala,
    Partida partida,
    Jugador para,
  ) {
    final reclamo = participante.ultimoReclamo;
    final verIniciales =
        partida.fase != 'valoresIniciales' ||
        participante.nombre == para.nombre;
    return {
      'usuario': participante.nombre,
      'conectado': _sigueConectado(participante, sala),
      'situacion': participante.situacion,
      'yaJugo': participante.yaJugo,
      'puntos': participante.puntos,
      'iniciales': verIniciales ? participante.iniciales : null,
      'casillas': participante.casillas,
      'ultimoReclamo': reclamo == null
          ? null
          : {'region': reclamo.region, 'puntos': reclamo.puntos},
    };
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
