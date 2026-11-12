import 'package:flutter/material.dart';

// Fondo con la imagen de dados (assets/imagenes/fondo_dados.png) repetida y
// bajando despacio sin fin. La imagen se repite sin cortes, asi que al bajar
// el alto de una copia vuelve a empezar y no se nota el salto.
class FondoDeDados extends StatefulWidget {
  // Las pruebas lo apagan (test/flutter_test_config.dart): una animacion que
  // nunca termina no deja que la pantalla "se asiente".
  static bool animado = true;

  final Widget child;

  const FondoDeDados({super.key, required this.child});

  @override
  State<FondoDeDados> createState() => _FondoDeDadosState();
}

class _FondoDeDadosState extends State<FondoDeDados>
    with SingleTickerProviderStateMixin {
  // Lado de cada copia de la imagen en pantalla, y cuanto tarda en bajar
  // esa distancia (mas tiempo = mas lento).
  static const double _lado = 420;
  static const Duration _vuelta = Duration(seconds: 30);

  late final AnimationController _bajada = AnimationController(
    vsync: this,
    duration: _vuelta,
  );

  @override
  void initState() {
    super.initState();
    if (FondoDeDados.animado) {
      _bajada.repeat();
    }
  }

  @override
  void dispose() {
    _bajada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, espacio) => ClipRect(
              child: AnimatedBuilder(
                animation: _bajada,
                // Se dibuja una copia de mas arriba y todo baja de -lado a 0.
                builder: (context, imagen) => Transform.translate(
                  offset: Offset(0, -_lado + _bajada.value * _lado),
                  child: imagen,
                ),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: espacio.maxWidth,
                  maxWidth: espacio.maxWidth,
                  minHeight: espacio.maxHeight + _lado,
                  maxHeight: espacio.maxHeight + _lado,
                  child: Image.asset(
                    'assets/imagenes/fondo_dados.png',
                    key: const ValueKey('fondo-dados'),
                    // La imagen mide 2048 px: con esta escala cada copia mide
                    // [_lado] en pantalla.
                    scale: 2048 / _lado,
                    repeat: ImageRepeat.repeat,
                    alignment: Alignment.topLeft,
                    fit: BoxFit.none,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
