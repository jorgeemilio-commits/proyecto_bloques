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
          final colorDeFondo = region == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Color.lerp(Colors.white, region!.tipo.color, 0.25)!;

          return MenuCasillaWidget(
            esInsertable: celda.esInsertable,
            bloc: context.read<NumeroCeldaBloc>(),
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorDeFondo,
                border: Border.all(
                  color: esInicial
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: esInicial ? 2 : 1,
                ),
              ),
              child: Text(
                estado.numero?.toString() ?? '',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight:
                          esInicial ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}
