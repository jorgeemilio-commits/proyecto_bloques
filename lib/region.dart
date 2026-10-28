import 'tipo.dart';

// Una region de colores del tablero. Las regiones de cada mapa se leen de su
// archivo de texto en assets/mapas/ (ver lector_mapas.dart).
class Region {
  // Identificador de la region dentro de su mapa: letra del color y numero
  // de region de ese color (por ejemplo 'Z1' o 'L2').
  final String id;
  final TipoRegion tipo;
  final List<Coordenada> coordenadas;
  // Si es true, la region se dibuja con rayas para distinguirla de la otra
  // region del mismo color sin cambiar el color.
  final bool conRayas;
  // Puntos propios de esta region en su mapa (primer, segundo y tercer
  // reclamo). Si es null se usan los del color.
  final Map<int, int>? puntuacionesPropias;

  const Region(
    this.id,
    this.tipo,
    this.coordenadas, {
    this.conRayas = false,
    this.puntuacionesPropias,
  });

  // Puntos que da completar la region: los propios del mapa o, si no tiene,
  // los de su color.
  Map<int, int> get puntuaciones => puntuacionesPropias ?? tipo.puntuaciones;
}

class Coordenada {
  final int x;
  final int y;

  const Coordenada(this.x, this.y);
}

//cual sistema de coordenadas se usa para el tablero
//que dificultad hay de capturar la informacion
//que dificultad hay para mapaearla al modelo

//quien se encarga de que no existan duplicados
