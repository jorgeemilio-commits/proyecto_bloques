// Elo de las partidas en linea: puntos fijos segun el lugar en que quedo cada
// jugador. Todos empiezan con [eloInicial] y el Elo nunca baja de 0.

const int eloInicial = 1000;

// Cambio de Elo por lugar (1.º, 2.º, ...) segun cuantos jugaron. Con pocos
// jugadores tambien se pierde, para que el Elo no suba para todos.
const Map<int, List<int>> _cambiosPorLugar = {
  2: [20, -15],
  3: [25, 0, -15],
  4: [25, 10, -5, -15],
  5: [25, 10, 0, -10, -15],
  6: [25, 10, 5, -5, -10, -15],
};

// Como termino un jugador la partida, para ordenar los lugares.
typedef FinalDeJugador = ({
  String nombre,
  int puntos,
  bool gano,
  bool seRindio,
});

// Cambio de Elo de cada jugador (por nombre). El orden es: primero los
// ganadores, luego los demas de mas a menos puntos y al final los que se
// rindieron. Los empatados (todos los ganadores, o mismos puntos en el mismo
// grupo) reciben lo del mejor de sus lugares.
Map<String, int> cambiosDeElo(List<FinalDeJugador> jugadores) {
  final tabla = _cambiosPorLugar[jugadores.length];
  if (tabla == null) {
    return {for (final jugador in jugadores) jugador.nombre: 0};
  }

  // Grupo: 0 = gano, 1 = no gano ni se rindio, 2 = se rindio.
  int grupo(FinalDeJugador jugador) =>
      jugador.gano ? 0 : (jugador.seRindio ? 2 : 1);
  final ordenados = [...jugadores]
    ..sort((a, b) {
      final porGrupo = grupo(a) - grupo(b);
      return porGrupo != 0 ? porGrupo : b.puntos - a.puntos;
    });

  // Empatan si estan en el mismo grupo y, fuera de los ganadores, tienen los
  // mismos puntos.
  bool empatan(FinalDeJugador a, FinalDeJugador b) =>
      grupo(a) == grupo(b) && (grupo(a) == 0 || a.puntos == b.puntos);

  final cambios = <String, int>{};
  for (var lugar = 0; lugar < ordenados.length; lugar++) {
    var mejor = lugar;
    while (mejor > 0 && empatan(ordenados[mejor - 1], ordenados[lugar])) {
      mejor--;
    }
    cambios[ordenados[lugar].nombre] = tabla[mejor];
  }
  return cambios;
}
