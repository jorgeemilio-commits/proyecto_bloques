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

  // Coordenadas de las seis celdas que deben recibir los valores iniciales.
  final List<Coordenada> coordenadasIniciales;

  // Matriz de celdas organizada como celdas[fila][columna], o sea [y][x].
  final List<List<Celda>> celdas;

  // Construye un tablero con sus dimensiones, regiones y celdas vacias.
  Tablero.desdeRegiones({
    required this.filas,
    required this.columnas,
    required List<Region> regiones,
    required List<Coordenada> coordenadasIniciales,
  })  : regiones = List.unmodifiable(regiones),
        coordenadasIniciales = _validarCoordenadasIniciales(
          coordenadasIniciales,
          filas,
          columnas,
        ),
        celdas = _crearCeldas(filas, columnas);

  // Devuelve la celda que ocupa la coordenada indicada.
  Celda obtenerCelda(Coordenada coordenada) {
    if (coordenada.x < 0 || coordenada.x >= columnas ||
        coordenada.y < 0 || coordenada.y >= filas) {
      throw RangeError('La coordenada esta fuera de los limites del tablero.');
    }

    return celdas[coordenada.y][coordenada.x];
  }

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

  // Comprueba que existan exactamente seis coordenadas iniciales validas.
  static List<Coordenada> _validarCoordenadasIniciales(
    List<Coordenada> coordenadas,
    int filas,
    int columnas,
  ) {
    if (coordenadas.length != 6) {
      throw ArgumentError('El tablero debe tener exactamente seis celdas iniciales.');
    }

    for (var indice = 0; indice < coordenadas.length; indice++) {
      final coordenada = coordenadas[indice];

      if (coordenada.x < 0 || coordenada.x >= columnas ||
          coordenada.y < 0 || coordenada.y >= filas) {
        throw ArgumentError(
          'La coordenada inicial (${coordenada.x}, ${coordenada.y}) '
          'esta fuera de los limites del tablero.',
        );
      }

      for (var anterior = 0; anterior < indice; anterior++) {
        final coordenadaAnterior = coordenadas[anterior];
        if (coordenadaAnterior.x == coordenada.x &&
            coordenadaAnterior.y == coordenada.y) {
          throw ArgumentError(
            'Las coordenadas iniciales no pueden repetirse.',
          );
        }
      }
    }

    return List.unmodifiable(coordenadas);
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
