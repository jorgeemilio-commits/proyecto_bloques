import 'package:flutter/material.dart';

// Panel que se desliza desde la derecha. Una pestaña pegada a su borde
// izquierdo lo abre o cierra al tocarla, y tanto la pestaña como el panel se
// pueden arrastrar. Mientras esta abierto, tocar fuera lo cierra.
class PanelLateral extends StatefulWidget {
  final Widget child;
  final double ancho;

  const PanelLateral({super.key, required this.child, this.ancho = 300});

  @override
  State<PanelLateral> createState() => _PanelLateralState();
}

class _PanelLateralState extends State<PanelLateral>
    with SingleTickerProviderStateMixin {
  // Angosta para no tapar el borde del tablero cuando esta cerrado.
  static const double _anchoPestana = 18;

  // 0 = cerrado, 1 = abierto.
  late final AnimationController _apertura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void dispose() {
    _apertura.dispose();
    super.dispose();
  }

  void _abrir() => _apertura.animateTo(1, curve: Curves.easeOutCubic);

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

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _apertura,
      builder: (context, panel) {
        final apertura = _apertura.value;

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
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: widget.ancho + _anchoPestana,
              child: Transform.translate(
                offset: Offset((1 - apertura) * widget.ancho, 0),
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

  Widget _pestana(ColorScheme colores, {required bool abierto}) {
    return GestureDetector(
      key: const ValueKey('pestana-panel'),
      onTap: _alternar,
      child: Container(
        width: _anchoPestana,
        height: 76,
        decoration: BoxDecoration(
          color: colores.surface,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(-2, 0),
            ),
          ],
        ),
        child: Icon(
          abierto ? Icons.chevron_right_rounded : Icons.palette_outlined,
          size: 16,
          color: colores.onSurfaceVariant,
        ),
      ),
    );
  }
}
