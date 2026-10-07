import 'package:flutter/material.dart';

import '../tablero.dart';
import 'celda_widget.dart';

class TableroWidget extends StatelessWidget {
  final Tablero tablero;
  final ValueChanged<Celda>? onCeldaTap;
  final VoidCallback? onNumeroCambiado;

  const TableroWidget({
    super.key,
    required this.tablero,
    this.onCeldaTap,
    this.onNumeroCambiado,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: tablero.columnas / tablero.filas,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: tablero.columnas,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
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
            onNumeroCambiado: onNumeroCambiado,
          );
        },
      ),
    );
  }
}