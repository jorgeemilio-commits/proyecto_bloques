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

// Regiones de los colores del tablero
enum Region {
  amarillo1(ColorRegion.amarillo, reglaRojoAmarillo),
  amarillo2(ColorRegion.amarillo, reglaRojoAmarillo),
  amarillo3(ColorRegion.amarillo, reglaRojoAmarillo),
  rojo1(ColorRegion.rojo, reglaRojoAmarillo),
  rojo2(ColorRegion.rojo, reglaRojoAmarillo),
  rojo3(ColorRegion.rojo, reglaRojoAmarillo),
  azul1(ColorRegion.azul, reglaAzul),
  azul2(ColorRegion.azul, reglaAzul),
  azul3(ColorRegion.azul, reglaAzul),
  verde1(ColorRegion.verde, reglaVerde),
  verde2(ColorRegion.verde, reglaVerde),
  verde3(ColorRegion.verde, reglaVerde),
  lila1(ColorRegion.lila, reglaPurpuraLila),
  lila2(ColorRegion.lila, reglaPurpuraLila),
  lila3(ColorRegion.lila, reglaPurpuraLila);

  final ColorRegion color;
  final ReglaRegion regla;

  const Region(this.color, this.regla);
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


