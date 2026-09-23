import 'region.dart';

// Representa una posicion individual dentro del tablero.
class Celda {
  // Coordenada de la celda: x es la columna y y es la fila.
  final Coordenada coordenada;

  // Numero colocado en la celda; es null cuando aun esta vacia.
  int? numero;

  // Crea una celda indicando su posicion y, opcionalmente, su numero inicial.
  Celda({
    required this.coordenada,
    this.numero,
  });
}

class Tablero {
  final int filas;
  final int columnas;
  // Lista de regiones que componen el tablero.
  final List<Region> regiones;

  // Matriz de celdas organizada como celdas[fila][columna], o sea [y][x].
  final List<List<Celda>> celdas;

  // Construye un tablero con sus dimensiones, regiones y celdas vacias.
  Tablero.desdeRegiones({
    required this.filas,
    required this.columnas,
    required List<Region> regiones,
  })  : regiones = List.unmodifiable(regiones),
        celdas = _crearCeldas(filas, columnas);

  // Devuelve la region que contiene la coordenada indicada.
  // Si no pertenece a ninguna region, devuelve null.
  Region? obtenerRegion(Coordenada coordenada) {
    // Se recorren al reves para que la ultima region tenga prioridad cuando dos regiones comparten una coordenada.
    for (final region in regiones.reversed) {
      // Comprueba si alguna coordenada de la region coincide con la buscada.
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

  // Crea una matriz de celdas vacias con las dimensiones solicitadas.
  static List<List<Celda>> _crearCeldas(
    int filas,
    int columnas,
  ) {
    // El bucle exterior crea las filas y el interior crea sus columnas.
    return [
      for (int y = 0; y < filas; y++)
        [
          for (int x = 0; x < columnas; x++)
            Celda(coordenada: Coordenada(x, y)),
        ],
    ];
  }
}
