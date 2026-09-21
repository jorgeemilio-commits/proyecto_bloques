import 'region.dart';

// Clase para representar una celda del tablero
class Celda {
  final Coordenada coordenada;
  int? numero;

  Celda({
    required this.coordenada,
    this.numero,
  });
}

class Tablero {
  final int filas;
  final int columnas;
  final List<Region> regiones;
  final List<List<Celda>> celdas;

  Tablero.desdeRegiones({
    required this.filas,
    required this.columnas,
    required List<Region> regiones,
  })  : regiones = List.unmodifiable(regiones),
        celdas = _crearCeldas(filas, columnas);

  Region? obtenerRegion(Coordenada coordenada) {
    for (final region in regiones.reversed) {
      final coordenadaPerteneceARegion = region.coordenadas.any(
        (coordenadaDeRegion) =>
            coordenadaDeRegion.x == coordenada.x &&
            coordenadaDeRegion.y == coordenada.y,
      );

      if (coordenadaPerteneceARegion) {
        return region;
      }
    }

    return null;
  }

  static List<List<Celda>> _crearCeldas(
    int filas,
    int columnas,
  ) {
    return [
      for (int y = 0; y < filas; y++)
        [
          for (int x = 0; x < columnas; x++)
            Celda(coordenada: Coordenada(x, y)),
        ],
    ];
  }
}
