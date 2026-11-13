import 'package:flutter/material.dart';

// Imagenes de fondo (assets/imagenes/). Todas son patrones que se repiten sin
// cortes, de 2048 x 2048.
const String fondoDados = 'assets/imagenes/fondo_dados.png';
const String fondoJuego = 'assets/imagenes/fondo_juego.png';
const String fondoLogin = 'assets/imagenes/fondo_login.png';
const String fondoResultados = 'assets/imagenes/fondo_resultados.png';

// Fondo con una imagen repetida que baja despacio sin fin, detras de
// [child]. Como la imagen se repite sin cortes, al bajar el alto de una copia
// vuelve a empezar y no se nota el salto. Si cambia la [imagen], la nueva
// aparece con un fundido sobre la anterior.
class FondoAnimado extends StatelessWidget {
  // Las pruebas lo apagan (test/flutter_test_config.dart): una animacion que
  // nunca termina no deja que la pantalla "se asiente".
  static bool animado = true;

  final String imagen;
  final Widget child;

  const FondoAnimado({super.key, required this.imagen, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 700),
            child: _ImagenQueBaja(key: ValueKey(imagen), imagen: imagen),
          ),
        ),
        child,
      ],
    );
  }
}

class _ImagenQueBaja extends StatefulWidget {
  final String imagen;

  const _ImagenQueBaja({super.key, required this.imagen});

  @override
  State<_ImagenQueBaja> createState() => _ImagenQueBajaState();
}

class _ImagenQueBajaState extends State<_ImagenQueBaja>
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
    if (FondoAnimado.animado) {
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
    return LayoutBuilder(
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
              widget.imagen,
              key: ValueKey('fondo-${widget.imagen}'),
              // Las imagenes miden 2048 px: con esta escala cada copia mide
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
    );
  }
}
