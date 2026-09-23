import 'package:flutter/material.dart';

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
    final colorDeFondo = region == null
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Color.lerp(Colors.white, region!.tipo.color, 0.25)!;

    return InkWell(
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
          celda.numero?.toString() ?? '',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: esInicial ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}