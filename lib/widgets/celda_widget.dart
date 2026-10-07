import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../numero_celda_bloc.dart';
import '../region.dart';
import '../tablero.dart';
import '../tipo.dart';
import 'menu_casilla_widget.dart';

// Color de una casilla segun el tipo de su region, mezclado con gris oscuro
// para que no deslumbre sobre el fondo negro.
Color colorDeRegion(TipoRegion tipo) =>
    Color.lerp(const Color(0xFF2A2A2A), tipo.color, 0.5)!;

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
          // En los colores claros (amarillo, verde) el texto va en negro.
          final colorDeTexto = colorDeFondo.computeLuminance() > 0.2
              ? Colors.black87
              : Colors.white;

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
                    ? Border.all(color: colores.onSurface, width: 2)
                    : null,
              ),
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    estado.numero?.toString() ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorDeTexto,
                          fontWeight:
                              esInicial ? FontWeight.w800 : FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
