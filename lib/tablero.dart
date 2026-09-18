import 'region.dart';

// Clase para representar una celda del tablero
class Celda {
  final Region? region;
  final Coordenada coordenada;
  int? numero;

  Celda({
    this.region,
    required this.coordenada,
    this.numero,
  });
}

class Tablero {
  final int filas;
  final int columnas;
  final List<List<Celda>> celdas;

  Tablero.desdeRegiones({
    required this.filas,
    required this.columnas,
    required List<Region> regiones,
  }) : celdas = _crearCeldas(filas, columnas, regiones);

  static List<List<Celda>> _crearCeldas(
    int filas,
    int columnas,
    List<Region> regiones,
  ) {
    final celdas = List.generate(
      filas,
      (_) => List<Celda?>.filled(columnas, null),
    );

    for (final region in regiones) {
      for (final coordenada in region.coordenadas) {
        celdas[coordenada.y][coordenada.x] = Celda(
          region: region,
          coordenada: coordenada,
        );
      }
    }

    return [
      for (int y = 0; y < filas; y++)
        [
          for (int x = 0; x < columnas; x++)
            celdas[y][x] ??
                Celda(
                  coordenada: Coordenada(x, y),
                ),
        ],
    ];
  }
}
