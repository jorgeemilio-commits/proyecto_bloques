import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../numero_celda_bloc.dart';
import '../region.dart';
import '../tablero.dart';
import 'menu_casilla_widget.dart';

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
              : Color.lerp(Colors.white, region!.tipo.color, 0.35)!;

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
                          color: Colors.black87,
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
