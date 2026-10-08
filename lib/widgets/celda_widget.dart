import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../numero_celda_bloc.dart';
import '../region.dart';
import '../tablero.dart';
import '../tipo.dart';
import 'menu_casilla_widget.dart';

// Color de una casilla segun el tipo de su region: conserva el tono pero con
// saturacion y luminosidad fijas, para que se vea desaturado sobre el fondo
// oscuro y el texto blanco se lea bien en todos los colores.
Color colorDeRegion(TipoRegion tipo) => HSLColor.fromColor(tipo.color)
    .withSaturation(0.4)
    .withLightness(0.4)
    .toColor();

class CeldaWidget extends StatelessWidget {
  final Celda celda;
  final Region? region;
  final bool esInicial;
  final VoidCallback? onTap;
  final VoidCallback? onNumeroCambiado;

  const CeldaWidget({
    super.key,
    required this.celda,
    required this.region,
    this.esInicial = false,
    this.onTap,
    this.onNumeroCambiado,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NumeroCeldaBloc(celda, onCambio: onNumeroCambiado),
      child: BlocBuilder<NumeroCeldaBloc, NumeroCeldaEstado>(
        builder: (context, estado) {
          final colores = Theme.of(context).colorScheme;
          final colorDeFondo = region == null
              ? colores.surfaceContainerHighest
              : colorDeRegion(region!.tipo);
          const colorDeTexto = Colors.white;

          return MenuCasillaWidget(
            esInsertable: celda.esInsertable,
            bloc: context.read<NumeroCeldaBloc>(),
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorDeFondo,
                borderRadius: BorderRadius.circular(6),
                border: esInicial
                    ? Border.all(
                        color: colores.onSurface.withValues(alpha: 0.25),
                      )
                    : null,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final numero = FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text(
                        estado.numero?.toString() ?? '',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: colorDeTexto,
                                  fontWeight: esInicial
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                      ),
                    ),
                  );

                  if (!esInicial) {
                    return Center(child: numero);
                  }

                  // Estrella en la esquina, como en el tablero del juego de mesa.
                  return Stack(
                    children: [
                      Center(child: numero),
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Icon(
                          Icons.star_rounded,
                          size: constraints.maxWidth * 0.28,
                          color: colorDeTexto.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
