import 'dart:math';

// Elo de las partidas en linea, por pares: cada partida cuenta como un duelo
// de cada jugador contra cada uno de los demas. En cada duelo se compara lo
// que paso (quien quedo arriba) con lo que se esperaba segun el Elo de los
// dos: ganarle a alguien mas fuerte da mucho, a alguien mas debil, poco. Lo
// que gana uno lo pierde el otro. Todos empiezan con [eloInicial] y el Elo
// nunca baja de 0.

const int eloInicial = 1000;

// Cuanto se puede mover el Elo en una partida: entre dos jugadores parejos,
// ganar da unos K/2.
const double factorK = 64;

// Si todos menos uno se rinden, la partida solo cuenta para el Elo cuando ya
// se jugaron mas de estas rondas.
const int rondasParaContarRendicion = 10;

// Como termino un jugador la partida y con cuanto Elo llego.
typedef FinalDeJugador = ({
  String nombre,
  int elo,
  int puntos,
  bool gano,
  bool seRindio,
});

// Probabilidad de que un jugador con [elo] le gane a uno con [eloRival].
double probabilidadDeGanar(int elo, int eloRival) =>
    1 / (1 + pow(10, (eloRival - elo) / 400));

// Cambio de Elo de cada jugador (por nombre).
//
// El orden es: primero los ganadores (empatados entre si), luego los demas
// de mas a menos puntos (empatados si tienen los mismos puntos) y al final
// los que se rindieron. En cada duelo, quedar arriba vale 1, empatar 0.5 y
// quedar abajo 0; a eso se le resta la probabilidad de ganar segun el Elo, se
// suma por todos los rivales y se multiplica por K entre el numero de rivales.
//
// Si al terminar al menos dos jugadores no se habian rendido (por ejemplo,
// alguien llego a la meta y otro seguia jugando), la partida cuenta. Si todos
// menos uno se rindieron, solo cuenta cuando ya se habian jugado mas de
// [rondasParaContarRendicion] rondas: asi rendirse al principio no le regala
// Elo a nadie, pero rendirse cuando ya se va perdiendo si cuesta.
Map<String, int> cambiosDeElo(
  List<FinalDeJugador> jugadores, {
  required int rondas,
}) {
  final sinRendirse = jugadores.where((jugador) => !jugador.seRindio).length;
  final cuenta =
      sinRendirse >= 2 ||
      (sinRendirse == 1 && rondas > rondasParaContarRendicion);
  if (jugadores.length < 2 || !cuenta) {
    return {for (final jugador in jugadores) jugador.nombre: 0};
  }

  // Grupo: 0 = gano, 1 = no gano ni se rindio, 2 = se rindio.
  int grupo(FinalDeJugador jugador) =>
      jugador.gano ? 0 : (jugador.seRindio ? 2 : 1);

  // Resultado del duelo de [a] contra [b]: 1 si quedo arriba, 0.5 si
  // empataron y 0 si quedo abajo.
  double resultado(FinalDeJugador a, FinalDeJugador b) {
    final porGrupo = grupo(b) - grupo(a);
    if (porGrupo != 0) {
      return porGrupo > 0 ? 1 : 0;
    }
    // Los ganadores empatan entre si; en los demas grupos, por puntos.
    if (grupo(a) == 0 || a.puntos == b.puntos) {
      return 0.5;
    }
    return a.puntos > b.puntos ? 1 : 0;
  }

  final rivales = jugadores.length - 1;
  return {
    for (final jugador in jugadores)
      jugador.nombre:
          (factorK /
                  rivales *
                  jugadores
                      .where((rival) => rival != jugador)
                      .map(
                        (rival) =>
                            resultado(jugador, rival) -
                            probabilidadDeGanar(jugador.elo, rival.elo),
                      )
                      .fold<double>(0, (suma, valor) => suma + valor))
              .round(),
  };
}
