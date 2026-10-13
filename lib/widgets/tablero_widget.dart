import 'package:flutter/material.dart';

import '../region.dart';
import '../tablero.dart';
import 'celda_widget.dart';

class TableroWidget extends StatelessWidget {
  final Tablero tablero;
  final ValueChanged<Celda>? onCeldaTap;
  final VoidCallback? onNumeroCambiado;
  // Celdas donde se puede soltar el dado que se esta arrastrando.
  final Set<Celda> destinosValidos;
  // Se llama cuando se suelta el dado [indiceDado] sobre una celda.
  final void Function(Celda celda, int indiceDado)? onDadoSoltado;
  // Cuantas veces se ha reclamado cada region; si es null, ninguna se apaga.
  final int Function(Region region)? vecesReclamada;

  const TableroWidget({
    super.key,
    required this.tablero,
    this.onCeldaTap,
    this.onNumeroCambiado,
    this.destinosValidos = const {},
    this.onDadoSoltado,
    this.vecesReclamada,
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
          final esInicial = tablero.celdasIniciales.contains(celda);
          final region = tablero.obtenerRegion(celda.coordenada);

          return CeldaWidget(
            key: ValueKey('celda-${celda.coordenada.x}-${celda.coordenada.y}'),
            celda: celda,
            region: region,
            vecesReclamada: region == null || vecesReclamada == null
                ? 0
                : vecesReclamada!(region),
            esInicial: esInicial,
            // En una casilla inicial no se ofrecen los numeros que ya estan
            // en las otras casillas iniciales.
            numerosOcultos: esInicial
                ? {
                    for (final otra in tablero.celdasIniciales)
                      if (otra != celda) ?otra.numero,
                  }
                : const {},
            onTap: onCeldaTap == null ? null : () => onCeldaTap!(celda),
            onNumeroCambiado: onNumeroCambiado,
            esDestinoValido: destinosValidos.contains(celda),
            onDadoSoltado: onDadoSoltado == null
                ? null
                : (indiceDado) => onDadoSoltado!(celda, indiceDado),
          );
        },
      ),
    );
  }
}
