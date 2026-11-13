import 'dart:math';

import 'package:flutter/material.dart';

import '../constantes.dart';

// Panel que se desliza desde la derecha. Una pestaña pegada a su borde
// izquierdo lo abre o cierra al tocarla, y tanto la pestaña como el panel se
// pueden arrastrar. Mientras esta abierto, tocar fuera lo cierra.
//
// Para que los jugadores sepan que existe, la pestaña es llamativa (con el
// degradado del logo y el texto "REGIONES") y, hasta que alguien abre el
// panel por primera vez, al empezar se asoma un par de veces y muestra un
// globo de ayuda que desaparece solo.
class PanelLateral extends StatefulWidget {
  final Widget child;
  final double ancho;

  const PanelLateral({super.key, required this.child, this.ancho = 300});

  @override
  State<PanelLateral> createState() => _PanelLateralState();
}

class _PanelLateralState extends State<PanelLateral>
    with TickerProviderStateMixin {
  static const double _anchoPestana = 28;
  static const double _altoPestana = 132;

  // Si ya se abrio el panel alguna vez mientras la app sigue abierta: ya no
  // hace falta la ayuda.
  static bool _yaSeAbrio = false;

  // 0 = cerrado, 1 = abierto.
  late final AnimationController _apertura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  // Ayuda del principio: la pestaña se asoma y el globo aparece, se queda y
  // se va. Dura 7 segundos en total.
  late final AnimationController _ayuda = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    if (!_yaSeAbrio) {
      _ayuda.forward();
    }
  }

  @override
  void dispose() {
    _apertura.dispose();
    _ayuda.dispose();
    super.dispose();
  }

  void _abrir() {
    _yaSeAbrio = true;
    _ayuda.stop();
    _ayuda.value = 1;
    _apertura.animateTo(1, curve: Curves.easeOutCubic);
  }

  void _cerrar() => _apertura.animateTo(0, curve: Curves.easeOutCubic);

  void _alternar() => _apertura.value >= 0.5 ? _cerrar() : _abrir();

  // Arrastrar a la izquierda abre; a la derecha cierra.
  void _arrastrar(DragUpdateDetails detalles) {
    _apertura.value -= (detalles.primaryDelta ?? 0) / widget.ancho;
  }

  // Al soltar: un movimiento rapido decide la direccion; si no, se queda del
  // lado donde quedo la mayor parte del panel.
  void _soltar(DragEndDetails detalles) {
    final velocidad = detalles.primaryVelocity ?? 0;
    if (velocidad.abs() > 300) {
      velocidad < 0 ? _abrir() : _cerrar();
    } else {
      _apertura.value >= 0.5 ? _abrir() : _cerrar();
    }
  }

  // Cuanto se asoma la pestaña hacia la izquierda: dos saltitos en los
  // primeros 2 segundos de la ayuda.
  double get _asomo {
    final t = _ayuda.value * 7;
    if (!_ayuda.isAnimating || t > 2) {
      return 0;
    }
    return 10 * sin(t * pi).abs();
  }

  // Opacidad del globo de ayuda: aparece en medio segundo, se queda y se va
  // en el ultimo segundo.
  double get _opacidadGlobo {
    final t = _ayuda.value * 7;
    if (!_ayuda.isAnimating) {
      return 0;
    }
    if (t < 0.5) {
      return t / 0.5;
    }
    if (t > 6) {
      return 7 - t;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_apertura, _ayuda]),
      builder: (context, panel) {
        final apertura = _apertura.value;
        final globo = _opacidadGlobo;

        return Stack(
          children: [
            // Fondo oscuro detras del panel abierto; tocarlo lo cierra.
            if (apertura > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _cerrar,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35 * apertura),
                  ),
                ),
              ),
            // Globo de ayuda a la izquierda de la pestaña.
            if (globo > 0 && apertura == 0)
              Positioned(
                top: 0,
                bottom: 0,
                right: _anchoPestana + 6,
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: globo,
                      child: const _GloboDeAyuda(),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: widget.ancho + _anchoPestana,
              child: Transform.translate(
                offset: Offset((1 - apertura) * widget.ancho - _asomo, 0),
                child: GestureDetector(
                  onHorizontalDragUpdate: _arrastrar,
                  onHorizontalDragEnd: _soltar,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _anchoPestana,
                        child: Center(
                          child: _pestana(colores, abierto: apertura >= 0.5),
                        ),
                      ),
                      Expanded(child: panel!),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colores.surface,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(16),
          ),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
        ),
        child: widget.child,
      ),
    );
  }

  // Pestaña con el degradado del logo, el icono de paleta y "REGIONES"
  // escrito de lado.
  Widget _pestana(ColorScheme colores, {required bool abierto}) {
    return GestureDetector(
      key: const ValueKey('pestana-panel'),
      onTap: _alternar,
      child: Container(
        width: _anchoPestana,
        height: _altoPestana,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [naranjaLogo, rosaLogo],
          ),
          borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 8,
              offset: Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              abierto ? Icons.chevron_right_rounded : Icons.palette_outlined,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(height: 6),
            const RotatedBox(
              quarterTurns: 3,
              child: Text(
                'REGIONES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Globo que apunta a la pestaña: dice que ahi estan los puntos de las
// regiones.
class _GloboDeAyuda extends StatelessWidget {
  const _GloboDeAyuda();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      key: const ValueKey('ayuda-panel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 170),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tema.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
          ),
          child: Text(
            'Toca aquí para ver los puntos de cada región',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onInverseSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Flechita hacia la pestaña.
        Icon(
          Icons.arrow_right_rounded,
          size: 28,
          color: tema.colorScheme.inverseSurface,
        ),
      ],
    );
  }
}
