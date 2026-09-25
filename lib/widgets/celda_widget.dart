import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../numero_celda_bloc.dart';
import '../region.dart';
import '../tablero.dart';

class CeldaWidget extends StatelessWidget {
  final Celda celda;
  final Region? region;
  final bool esInicial;
  final VoidCallback? onTap;

  const CeldaWidget({
    super.key,
    required this.celda,
    required this.region,
    this.esInicial = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NumeroCeldaBloc(celda),
      child: BlocBuilder<NumeroCeldaBloc, NumeroCeldaEstado>(
        builder: (context, estado) {
          final colorDeFondo = region == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Color.lerp(Colors.white, region!.tipo.color, 0.25)!;

          return InkWell(
            onTap: () {
              onTap?.call();
              _mostrarSelectorNumero(context);
            },
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

  Future<void> _mostrarSelectorNumero(BuildContext context) async {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }
    final bloc = context.read<NumeroCeldaBloc>();

    final centroDeLaCelda = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar selector de numero',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, _, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            const tamanoMenu = 190.0;
            final left = (centroDeLaCelda.dx - tamanoMenu / 2).clamp(
              8.0,
              constraints.maxWidth - tamanoMenu - 8,
            );
            final top = (centroDeLaCelda.dy - tamanoMenu / 2).clamp(
              8.0,
              constraints.maxHeight - tamanoMenu - 8,
            );

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: _menuRadial(
                    context: context,
                    dialogContext: dialogContext,
                    bloc: bloc,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _menuRadial({
    required BuildContext context,
    required BuildContext dialogContext,
    required NumeroCeldaBloc bloc,
  }) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var numero = 1; numero <= 6; numero++)
            _botonRadial(
              context: context,
              dialogContext: dialogContext,
              bloc: bloc,
              numero: numero,
            ),
          IconButton(
            tooltip: 'Borrar',
            onPressed: () {
              bloc.add(const NumeroCeldaBorrado());
              Navigator.of(dialogContext).pop();
            },
            icon: Icon(
              Icons.backspace_outlined,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonRadial({
    required BuildContext context,
    required BuildContext dialogContext,
    required NumeroCeldaBloc bloc,
    required int numero,
  }) {
    const radio = 66.0;
    final angulo = -math.pi / 2 + (numero - 1) * (math.pi * 2 / 6);

    return Transform.translate(
      offset: Offset(radio * math.cos(angulo), radio * math.sin(angulo)),
      child: SizedBox(
        width: 56,
        height: 56,
        child: TextButton(
          onPressed: () {
            bloc.add(NumeroCeldaSeleccionado(numero));
            Navigator.of(dialogContext).pop();
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color.fromRGBO(210, 210, 210, 0.72),
            foregroundColor: Colors.grey.shade900,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            side: const BorderSide(
              color: Color.fromRGBO(120, 120, 120, 0.72),
              width: 2,
            ),
            elevation: 2,
          ),
          child: Text(
            numero.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
