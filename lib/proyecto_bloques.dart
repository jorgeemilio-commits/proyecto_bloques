// Validador de color Rojo / Amarillo
bool puedeInsertarRA(List<int> numeros, int nuevoNumero) {
  // Checa si la lista no contiene duplicados.
  if (numeros.toSet().length != numeros.length) {
    return false;
  }
  // Checa si el nuevo número ya existe en la lista.
  return !numeros.contains(nuevoNumero);
}

// Validador de color Azul
bool puedeInsertarZ(List<int> numeros, int nuevoNumero) {
  // Checa que todos los numeros sean iguales al nuevo 
  return numeros.every((numero) => numero == nuevoNumero);
}

// Validador de color Verde
bool puedeInsertarV(List<int> numeros, int nuevoNumero) {
  // Siempre es valido en el caso de verde
  return true;
}

// Validador de color Purpura / Lila
bool puedeInsertarPL(List<int> numeros, int nuevoNumero) {
  return {...numeros, nuevoNumero}.length <= 2;
}

// Regiones de los colores del tablero
enum Region {
  amarillo1,
  amarillo2,
  amarillo3,
  rojo1,
  rojo2,
  rojo3,
  azul1,
  azul2,
  azul3,
  verde1,
  verde2,
  verde3,
  lila1,
  lila2,
  lila3,
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


