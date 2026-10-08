import 'region.dart';

// Representa una posicion individual dentro del tablero.
class Celda {
  // Coordenada de la celda: x es la columna y y es la fila.
  final Coordenada coordenada;

  // Numero colocado en la celda; es null cuando aun esta vacia.
  int? numero;

  // Indica si las reglas actuales permiten insertar o borrar un numero.
  bool esInsertable;

  // Crea una celda indicando su posicion y, opcionalmente, su numero inicial.
  Celda({
    required this.coordenada,
    this.numero,
    this.esInsertable = false,
  });
}

class Tablero {
  final int filas;
  final int columnas;
  // Lista de regiones que componen el tablero.
  final List<Region> regiones;

  // Celdas fijas que deben recibir los valores iniciales.
  late final List<Celda> celdasIniciales;

  // Matriz de celdas organizada como celdas[fila][columna], o sea [y][x].
  final List<List<Celda>> celdas;

  // Construye un tablero con sus dimensiones, regiones y celdas vacias.
  Tablero.desdeRegiones({
    required this.filas,
    required this.columnas,
    required List<Region> regiones,
  })  : regiones = List.unmodifiable(regiones),
        celdas = _crearCeldas(filas, columnas) {
    // Relaciona las coordenadas fijas con las celdas reales del tablero.
    celdasIniciales = List.unmodifiable(
      coordenadasIniciales.map(obtenerCelda),
    );
    for (final celda in celdasIniciales) {
      celda.esInsertable = true;
    }
  }

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

  // Devuelve las celdas de arriba, abajo, izquierda y derecha que existen.
  List<Celda> vecinas(Celda celda) {
    final x = celda.coordenada.x;
    final y = celda.coordenada.y;

    return [
      for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)])
        if (x + dx >= 0 && x + dx < columnas && y + dy >= 0 && y + dy < filas)
          celdas[y + dy][x + dx],
    ];
  }

  // Numeros que ya estan colocados dentro de una region.
  List<int> numerosEnRegion(Region region) => [
        for (final coordenada in region.coordenadas)
          ?obtenerCelda(coordenada).numero,
      ];

  // Indica si todas las casillas de la region ya tienen un numero.
  bool regionCompleta(Region region) => region.coordenadas.every(
        (coordenada) => obtenerCelda(coordenada).numero != null,
      );

  // Indica si se puede colocar [numero] en [destino] usando [ancla]:
  // el destino debe estar vacio, tener al lado una casilla con el numero del
  // ancla y respetar la regla del color de su region.
  bool puedeColocar(Celda destino, {required int numero, required int ancla}) {
    if (destino.numero != null) {
      return false;
    }

    final tieneAnclaAlLado = vecinas(destino).any(
      (vecina) => vecina.numero == ancla,
    );
    if (!tieneAnclaAlLado) {
      return false;
    }

    final region = obtenerRegion(destino.coordenada);
    return region == null ||
        region.tipo.esPosibleAgregar(numerosEnRegion(region), numero);
  }

  // Todas las celdas donde se puede colocar [numero] usando [ancla].
  Set<Celda> destinosValidos({required int numero, required int ancla}) => {
        for (final fila in celdas)
          for (final celda in fila)
            if (puedeColocar(celda, numero: numero, ancla: ancla)) celda,
      };

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
