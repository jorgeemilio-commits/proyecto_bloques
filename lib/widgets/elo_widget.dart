import 'package:flutter/material.dart';

// Cuanto cambio el Elo: "+20" en verde, "−15" en rojo o "±0" en gris.
class CambioDeElo extends StatelessWidget {
  final int cambio;
  final TextStyle? estilo;

  const CambioDeElo({super.key, required this.cambio, this.estilo});

  static String texto(int cambio) => cambio > 0
      ? '+$cambio'
      : cambio < 0
      ? '−${-cambio}'
      : '±0';

  @override
  Widget build(BuildContext context) {
    final color = cambio > 0
        ? Colors.green.shade400
        : cambio < 0
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Text(
      texto(cambio),
      style: (estilo ?? const TextStyle()).copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
