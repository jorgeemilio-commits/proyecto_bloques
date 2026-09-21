import 'region.dart';

// Representa una casilla: su posición y el número que contiene.
class Celda {
  final Coordenada coordenada;
  int? numero;

  Celda({
    required this.coordenada,
    this.numero,
  });
}

// Representa el tablero de juego, con sus celdas y regiones.
class Tablero {
  final int filas;
  final int columnas;
  final List<Region> regiones;
  // La matriz se consulta como celdas[fila][columna], es decir, [y][x].
  final List<List<Celda>> celdas;

  Tablero.desdeRegiones({
    required this.filas,
    required this.columnas,
    required List<Region> regiones,
  })  : regiones = List.unmodifiable(regiones),
        celdas = _crearCeldas(filas, columnas);

  // Busca qué región contiene una coordenada determinada.
  Region? obtenerRegion(Coordenada coordenada) {
    // Se revisan al revés para conservar la última región en caso de solapamiento.
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

  // Crea todas las celdas del tablero sin asignarles una región.
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
