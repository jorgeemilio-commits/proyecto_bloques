import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constantes.dart';

// Aviso de que empezo una ronda nueva: el borde de [child] (el tablero) brilla
// un instante con los colores del logo, y el telefono vibra muy suave. Se
// activa cada vez que cambia [ronda] (a un numero mayor que 0).
class BrilloDeRonda extends StatefulWidget {
  final int ronda;
  final double radio;
  final Widget child;

  const BrilloDeRonda({
    super.key,
    required this.ronda,
    required this.child,
    this.radio = 16,
  });

  @override
  State<BrilloDeRonda> createState() => _BrilloDeRondaState();
}

class _BrilloDeRondaState extends State<BrilloDeRonda>
    with SingleTickerProviderStateMixin {
  late final AnimationController _brillo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(BrilloDeRonda anterior) {
    super.didUpdateWidget(anterior);
    if (widget.ronda != anterior.ronda && widget.ronda > 0) {
      _brillo.forward(from: 0);
      // La vibracion mas ligera que hay; en escritorio no hace nada.
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _brillo,
      builder: (context, tablero) {
        // Sube rapido y baja despacio: 0 -> 1 en el primer 25%, luego a 0.
        final t = _brillo.value;
        final intensidad = !_brillo.isAnimating
            ? 0.0
            : t < 0.25
            ? t / 0.25
            : 1 - Curves.easeOut.transform((t - 0.25) / 0.75);

        final borde = BorderRadius.circular(widget.radio);
        // El resplandor va detras del tablero (solo se ve alrededor) y el
        // borde naranja encima.
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borde,
            boxShadow: [
              BoxShadow(
                color: rosaLogo.withValues(alpha: 0.55 * intensidad),
                blurRadius: 24 * intensidad,
                spreadRadius: 2 * intensidad,
              ),
            ],
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: borde,
              border: Border.all(
                color: Color.lerp(Colors.transparent, naranjaLogo, intensidad)!,
                width: 3,
              ),
            ),
            child: tablero,
          ),
        );
      },
      child: widget.child,
    );
  }
}
