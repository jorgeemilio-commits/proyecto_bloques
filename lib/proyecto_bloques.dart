// Validador de color Rojo / Amarillo
bool reglaRojoAmarillo(List<int> numeros, int nuevoNumero) {
  // Checa si la lista no contiene duplicados.
  if (numeros.toSet().length != numeros.length) {
    return false;
  }
  // Checa si el nuevo número ya existe en la lista.
  return !numeros.contains(nuevoNumero);
}

// Validador de color Azul
bool reglaAzul(List<int> numeros, int nuevoNumero) {
  // Checa que todos los numeros sean iguales al nuevo 
  return numeros.every((numero) => numero == nuevoNumero);
}

// Validador de color Verde
bool reglaVerde(List<int> numeros, int nuevoNumero) {
  // Siempre es valido en el caso de verde
  return true;
}

// Validador de color Purpura / Lila
bool reglaPurpuraLila(List<int> numeros, int nuevoNumero) {
  return {...numeros, nuevoNumero}.length <= 2;
}

typedef ReglaRegion = bool Function(List<int> numeros, int nuevoNumero);

enum ColorRegion {
  amarillo,
  rojo,
  azul,
  verde,
  lila,
}

class TipoRegion {
  final ColorRegion color;
  final ReglaRegion regla;

  const TipoRegion(this.color, this.regla);

  static const amarillo = TipoRegion(ColorRegion.amarillo, reglaRojoAmarillo);
  static const rojo = TipoRegion(ColorRegion.rojo, reglaRojoAmarillo);
  static const azul = TipoRegion(ColorRegion.azul, reglaAzul);
  static const verde = TipoRegion(ColorRegion.verde, reglaVerde);
  static const lila = TipoRegion(ColorRegion.lila, reglaPurpuraLila);
}

// Regiones de los colores del tablero
enum Region {
  amarillo1(TipoRegion.amarillo),
  amarillo2(TipoRegion.amarillo),
  amarillo3(TipoRegion.amarillo),
  rojo1(TipoRegion.rojo),
  rojo2(TipoRegion.rojo),
  rojo3(TipoRegion.rojo),
  azul1(TipoRegion.azul),
  azul2(TipoRegion.azul),
  azul3(TipoRegion.azul),
  verde1(TipoRegion.verde),
  verde2(TipoRegion.verde),
  verde3(TipoRegion.verde),
  lila1(TipoRegion.lila),
  lila2(TipoRegion.lila),
  lila3(TipoRegion.lila);

  final TipoRegion tipo;

  const Region(this.tipo);
}

// Clase para representar una celda del tablero
class Celda {
  final Region region;
  final int? numero;
  //final bool esFija;
  const Celda({required this.region, this.numero});
}

// Función para obtener los números de una región específica del tablero
List<int> obtenerNumerosRegion(
  List<List<Celda>> tablero,
  Region region,
) {
  return [
    for (final fila in tablero)
      for (final celda in fila)
      // Si la celda es de esa region y tiene un numero, lo extrae
        if (celda.region == region && celda.numero != null) celda.numero!,
  ];
}


