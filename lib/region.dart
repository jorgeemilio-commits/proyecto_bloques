import 'tipo.dart';

abstract class Region {
  // Identificador de la region dentro de su mapa: letra del color y numero
  // de region de ese color (por ejemplo 'Z1' o 'L2').
  final String id;
  final TipoRegion tipo;
  final List<Coordenada> coordenadas;
  // Si es true, la region se dibuja con rayas para distinguirla de la otra
  // region del mismo color sin cambiar el color.
  final bool conRayas;

  const Region(this.id, this.tipo, this.coordenadas, {this.conRayas = false});
}

class Coordenada {
  final int x;
  final int y;

  const Coordenada(this.x, this.y);
}

// Coordenadas fijas de las seis celdas que se llenan al iniciar el juego,
// en orden de lectura (las marcadas con estrella en el tablero del juego).
const List<Coordenada> coordenadasIniciales = [
  Coordenada(2, 0),
  Coordenada(5, 1),
  Coordenada(1, 3),
  Coordenada(4, 3),
  Coordenada(2, 5),
  Coordenada(4, 6),
];

// Regiones y coordenadas
// super permite que se pueda crear una region de un tipo especifico (por ejemplo, RegionAzulUno hijo de tipo azul y herada sus caracteristicas)
class RegionAzulUno extends Region {
  const RegionAzulUno()
    : super('Z1', TipoRegion.azul, const [
        Coordenada(2, 0),
        Coordenada(2, 1),
        Coordenada(3, 1),
        Coordenada(3, 2),
      ]);
}

class RegionAzulDos extends Region {
  const RegionAzulDos()
    : super('Z2', TipoRegion.azul, const [
        Coordenada(6, 4),
        Coordenada(5, 5),
        Coordenada(6, 5),
        Coordenada(5, 6),
      ], conRayas: true);
}

class RegionRojaUno extends Region {
  const RegionRojaUno()
    : super('R1', TipoRegion.rojo, const [
        Coordenada(1, 2),
        Coordenada(2, 2),
        Coordenada(1, 3),
        Coordenada(1, 4),
        Coordenada(0, 5),
        Coordenada(1, 5),
      ]);
}

class RegionRojaDos extends Region {
  const RegionRojaDos()
    : super('R2', TipoRegion.rojo, const [
        Coordenada(4, 4),
        Coordenada(5, 4),
        Coordenada(3, 5),
        Coordenada(4, 5),
        Coordenada(3, 6),
        Coordenada(4, 6),
      ], conRayas: true);
}

class RegionVerdeUno extends Region {
  const RegionVerdeUno()
    : super('V1', TipoRegion.verde, const [
        Coordenada(1, 0),
        Coordenada(0, 1),
        Coordenada(1, 1),
        Coordenada(0, 2),
        Coordenada(0, 3),
        Coordenada(0, 4),
      ]);
}

class RegionVerdeDos extends Region {
  const RegionVerdeDos()
    : super('V2', TipoRegion.verde, const [
        Coordenada(6, 1),
        Coordenada(5, 2),
        Coordenada(6, 2),
        Coordenada(4, 3),
        Coordenada(5, 3),
        Coordenada(6, 3),
      ], conRayas: true);
}

class RegionLilaUno extends Region {
  const RegionLilaUno()
    : super('L1', TipoRegion.lila, const [
        Coordenada(3, 0),
        Coordenada(4, 0),
        Coordenada(5, 0),
        Coordenada(4, 1),
        Coordenada(5, 1),
        Coordenada(4, 2),
      ]);
}

class RegionLilaDos extends Region {
  const RegionLilaDos()
    : super('L2', TipoRegion.lila, const [
        Coordenada(2, 3),
        Coordenada(2, 4),
        Coordenada(3, 4),
        Coordenada(2, 5),
        Coordenada(1, 6),
        Coordenada(2, 6),
      ], conRayas: true);
}

class RegionAmarilla extends Region {
  const RegionAmarilla()
    : super('A1', TipoRegion.amarillo, const [
        Coordenada(0, 0),
        Coordenada(6, 0),
        Coordenada(3, 3),
        Coordenada(0, 6),
        Coordenada(6, 6),
      ]);
}

const List<Region> regionesMapa = [
  RegionAzulUno(),
  RegionAzulDos(),
  RegionRojaUno(),
  RegionRojaDos(),
  RegionVerdeUno(),
  RegionVerdeDos(),
  RegionLilaUno(),
  RegionLilaDos(),
  RegionAmarilla(),
];

//cual sistema de coordenadas se usa para el tablero
//que dificultad hay de capturar la informacion
//que dificultad hay para mapaearla al modelo

//quien se encarga de que no existan duplicados
