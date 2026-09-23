import 'package:flutter/material.dart';

import '../tablero.dart';
import 'celda_widget.dart';

class TableroWidget extends StatelessWidget {
  final Tablero tablero;
  final ValueChanged<Celda>? onCeldaTap;

  const TableroWidget({
    super.key,
    required this.tablero,
    this.onCeldaTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: tablero.columnas / tablero.filas,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: tablero.columnas,
        ),
        itemCount: tablero.filas * tablero.columnas,
        itemBuilder: (context, indice) {
          final fila = indice ~/ tablero.columnas;
          final columna = indice % tablero.columnas;
          final celda = tablero.celdas[fila][columna];

          return CeldaWidget(
            celda: celda,
            region: tablero.obtenerRegion(celda.coordenada),
            esInicial: tablero.celdasIniciales.contains(celda),
            onTap: onCeldaTap == null ? null : () => onCeldaTap!(celda),
          );
        },
      ),
    );
  }
}