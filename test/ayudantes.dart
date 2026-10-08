// Ayudantes compartidos por las pruebas.
import 'dart:math';

import 'package:proyecto_bloques/proyecto_bloques.dart';

// Random que devuelve las caras indicadas en orden, para saber que saldra.
class AzarFijo implements Random {
  final List<int> caras;
  int _siguiente = 0;

  AzarFijo(this.caras);

  @override
  int nextInt(int max) => caras[_siguiente++ % caras.length] - 1;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

// Tablero real con las casillas iniciales (diagonal) llenas del 1 al 6.
Tablero crearTableroConIniciales() {
  final tablero = Tablero.desdeRegiones(
    filas: 7,
    columnas: 7,
    regiones: regionesMapa,
  );
  for (var indice = 0; indice < tablero.celdasIniciales.length; indice++) {
    tablero.celdasIniciales[indice].numero = indice + 1;
  }
  return tablero;
}

Celda celdaEn(Tablero tablero, int x, int y) =>
    tablero.obtenerCelda(Coordenada(x, y));
