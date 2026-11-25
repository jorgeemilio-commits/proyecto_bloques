// Lo que se le manda a los jugadores: el estado de la sala, los avisos y los errores.
part of 'salas.dart';

// Metodos de Salas que mandan mensajes a los jugadores.
extension _EstadoDeLasSalas on Salas {
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
                'elo': ?eloDe?.call(otro.nombre),
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
      // Al terminar: cuanto cambio su Elo.
      'cambioElo': sala.cambiosDeElo[participante.nombre],
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
