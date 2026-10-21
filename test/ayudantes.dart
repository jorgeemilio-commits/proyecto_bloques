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

// Tablero real con los numeros 1 a 6 en la diagonal: (0,0)=1, (1,1)=2 ...
// (5,5)=6. Es una posicion fija para probar las reglas, sin depender de donde
// esten las casillas iniciales.
Tablero crearTableroConDiagonal() {
  final tablero = mapaClasico.crearTablero();
  for (var indice = 0; indice < 6; indice++) {
    celdaEn(tablero, indice, indice).numero = indice + 1;
  }
  return tablero;
}

Celda celdaEn(Tablero tablero, int x, int y) =>
    tablero.obtenerCelda(Coordenada(x, y));
