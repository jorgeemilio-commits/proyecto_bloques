import 'package:flutter/material.dart';

import '../juego/region.dart';
import '../juego/tablero.dart';
import 'celda_widget.dart';
import 'celebracion_widget.dart';

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
  // Region recien completada: sus casillas brillan y salen los puntos.
  final Destello? destello;

  const TableroWidget({
    super.key,
    required this.tablero,
    this.onCeldaTap,
    this.onNumeroCambiado,
    this.destinosValidos = const {},
    this.onDadoSoltado,
    this.vecesReclamada,
    this.destello,
  });

  @override
  Widget build(BuildContext context) {
    final destello = this.destello;

    // Siempre es un Stack (aunque no haya destello) para que las casillas no
    // se vuelvan a crear al aparecer o quitarse la celebracion.
    return Stack(
      alignment: Alignment.center,
      children: [
        _cuadricula(),
        if (destello != null && destello.puntos > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: PuntosFlotantes(
                  key: ValueKey('puntos-${destello.id}'),
                  puntos: destello.puntos,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _cuadricula() {
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
          final brilla =
              destello != null &&
              region != null &&
              region.id == destello!.regionId;

          final casilla = CeldaWidget(
            key: ValueKey('celda-${celda.coordenada.x}-${celda.coordenada.y}'),
            celda: celda,
            region: region,
            vecesReclamada: region == null || vecesReclamada == null
                ? 0
                : vecesReclamada!(region),
            esInicial: esInicial,
            // En una casilla inicial no se ofrecen los numeros que ya estan
            // en las otras casillas iniciales ni los que no permite la regla
            // de su region (por ejemplo, un 2 en una naranja de 4 a 6).
            numerosOcultos: esInicial
                ? {
                    for (final otra in tablero.celdasIniciales)
                      if (otra != celda) ?otra.numero,
                    for (var numero = 1; numero <= 6; numero++)
                      if (!tablero
                          .numerosPermitidosEnInicial(celda)
                          .contains(numero))
                        numero,
                  }
                : const {},
            onTap: onCeldaTap == null ? null : () => onCeldaTap!(celda),
            onNumeroCambiado: onNumeroCambiado,
            esDestinoValido: destinosValidos.contains(celda),
            onDadoSoltado: onDadoSoltado == null
                ? null
                : (indiceDado) => onDadoSoltado!(celda, indiceDado),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              casilla,
              if (brilla)
                IgnorePointer(
                  child: DestelloCelda(
                    key: ValueKey('destello-${destello!.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
