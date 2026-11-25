// Los tiempos de la partida (rondas y fin), las jugadas y rendirse.
part of 'salas.dart';

// Metodos de Salas que llevan la partida.
extension _PartidaDeLasSalas on Salas {
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

  // Cambia el tiempo de la fase actual de la partida. Con [visible] en
  // false, los jugadores no ven la cuenta regresiva (es solo una pausa).
  void _programar(
    Sala sala,
    Duration espera,
    void Function() alAcabarse, {
    bool visible = true,
  }) {
    sala.temporizador?.cancel();
    sala.limite = visible ? DateTime.now().add(espera) : null;
    sala.temporizador = Timer(espera, alAcabarse);
  }

  // La fase actual no tiene tiempo.
  void _sinTiempo(Sala sala) {
    sala.temporizador?.cancel();
    sala.temporizador = null;
    sala.limite = null;
  }

  // Tira los dados y empieza la siguiente ronda, con su tiempo si el
  // anfitrion eligio uno. Sin limite, la ronda termina cuando juegan todos
  // los conectados.
  void _empezarRonda(Sala sala) {
    final partida = sala.partida!;
    partida.empezarRonda(_azar);
    final segundos = sala.segundosPorRonda;
    if (segundos == null) {
      _sinTiempo(sala);
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
    // Pausa corta para ver los resultados; no se muestra como cuenta
    // regresiva.
    _programar(
      sala,
      esperaEntreRondas,
      () => _empezarRonda(sala),
      visible: false,
    );
    _enviarEstado(sala);
  }

  // La partida termino: se muestran los resultados y, si los jugadores no
  // salen antes, la sala se borra despues de [esperaSalaTerminada].
  void _terminar(Sala sala) {
    if (!sala.guardada && sala.partida!.ronda > 0) {
      sala.guardada = true;
      sala.cambiosDeElo = alTerminarPartida?.call(sala) ?? const {};
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

  // El jugador se rinde (con "rendirse" o por no volver a tiempo): ya no
  // juega, pero se queda en la sala viendo la partida (los tableros y los
  // puntos de los demas) hasta que sale con "salir". Los demas siguen
  // jugando. Si ya no jugaba (ya se habia rendido, llego a la meta o la
  // partida termino), "rendirse" solo lo saca de la sala.
  void _rendirse(Jugador jugador, Sala sala) {
    final partida = sala.partida!;
    final participante = partida.de(jugador.nombre);
    if (participante == null ||
        !participante.jugando ||
        partida.fase == 'terminada') {
      _salirDeLaPartida(jugador, sala);
      return;
    }
    partida.rendir(participante);
    _avisar(sala, '${jugador.nombre} se rindió.', excepto: jugador);
    if (partida.fase == 'terminada') {
      _terminar(sala);
    } else if (partida.fase == 'valoresIniciales' &&
        partida.todosTienenValores) {
      _empezarRonda(sala);
    } else {
      _revisarRonda(sala);
    }
  }

  // Quien ya no juega sale de la sala de la partida: queda libre para entrar
  // a otra, y en la partida sigue apareciendo con su tablero y sus puntos.
  void _salirDeLaPartida(Jugador jugador, Sala sala) {
    _sacarDeLaSala(jugador, sala);
    _enviarEstadoA(jugador);
    if (_salas.containsKey(sala.codigo)) {
      _enviarEstado(sala);
    }
  }
}
