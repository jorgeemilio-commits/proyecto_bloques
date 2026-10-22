import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../numero_celda_bloc.dart';
import '../region.dart';
import '../tablero.dart';
import '../tipo.dart';
import 'menu_casilla_widget.dart';

// Brillo de una region segun cuantas veces se ha reclamado: cada reclamo la
// apaga un poco mas, hasta el tercero (cuando ya no da puntos).
const List<double> _brilloPorReclamos = [1.0, 0.7, 0.45, 0.25];

// Color de una casilla segun el tipo de su region: conserva el tono pero con
// saturacion y luminosidad fijas, para que se vea desaturado sobre el fondo
// oscuro y el texto blanco se lea bien en todos los colores. Mientras mas
// veces se ha reclamado la region, mas apagado se ve.
Color colorDeRegion(TipoRegion tipo, {int vecesReclamada = 0}) {
  final brillo =
      _brilloPorReclamos[vecesReclamada.clamp(
        0,
        _brilloPorReclamos.length - 1,
      )];

  final base = HSLColor.fromColor(tipo.color);

  // El blanco no tiene tono: se dibuja gris claro y se apaga hacia gris.
  if (base.saturation == 0) {
    return base.withLightness(0.72 * (0.75 + 0.25 * brillo)).toColor();
  }

  return base
      .withSaturation(0.4 * brillo)
      .withLightness(0.4 * (0.6 + 0.4 * brillo))
      .toColor();
}

// Color del numero, la estrella y las rayas sobre una region: oscuro en las
// regiones claras (blanca) y blanco en las demas. Se decide con el color sin
// reclamos para que no cambie al apagarse la region.
Color colorDeTextoPara(TipoRegion tipo) =>
    colorDeRegion(tipo).computeLuminance() > 0.4
    ? Colors.black87
    : Colors.white;

class CeldaWidget extends StatelessWidget {
  final Celda celda;
  final Region? region;
  final bool esInicial;
  final VoidCallback? onTap;
  final VoidCallback? onNumeroCambiado;
  // Indica si el dado que se esta arrastrando se puede soltar aqui.
  final bool esDestinoValido;
  // Se llama con el indice del dado (0 o 1) cuando se suelta sobre la celda.
  final ValueChanged<int>? onDadoSoltado;
  // Numeros que no se ofrecen en la rueda de esta celda.
  final Set<int> numerosOcultos;
  // Cuantas veces se ha reclamado la region de esta celda; apaga su color.
  final int vecesReclamada;

  const CeldaWidget({
    super.key,
    required this.celda,
    required this.region,
    this.esInicial = false,
    this.onTap,
    this.onNumeroCambiado,
    this.esDestinoValido = false,
    this.onDadoSoltado,
    this.numerosOcultos = const {},
    this.vecesReclamada = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NumeroCeldaBloc(celda, onCambio: onNumeroCambiado),
      child: BlocBuilder<NumeroCeldaBloc, NumeroCeldaEstado>(
        builder: (context, _) => DragTarget<int>(
          onWillAcceptWithDetails: (_) => esDestinoValido,
          onAcceptWithDetails: (detalles) => onDadoSoltado?.call(detalles.data),
          builder: (context, candidatos, _) =>
              _construirCelda(context, dadoEncima: candidatos.isNotEmpty),
        ),
      ),
    );
  }

  Widget _construirCelda(BuildContext context, {required bool dadoEncima}) {
    final colores = Theme.of(context).colorScheme;
    final colorBase = region == null
        ? colores.surfaceContainerHighest
        : colorDeRegion(region!.tipo, vecesReclamada: vecesReclamada);
    // La casilla bajo el dado se aclara para indicar donde caera.
    final colorDeFondo = dadoEncima
        ? Color.lerp(colorBase, Colors.white, 0.3)!
        : colorBase;
    final colorDeTexto = region == null
        ? Colors.white
        : colorDeTextoPara(region!.tipo);

    return MenuCasillaWidget(
      esInsertable: celda.esInsertable,
      bloc: context.read<NumeroCeldaBloc>(),
      onTap: onTap,
      numerosOcultos: numerosOcultos,
      child: Container(
        alignment: Alignment.center,
        // Recorta las rayas a las esquinas redondeadas.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colorDeFondo,
          borderRadius: BorderRadius.circular(6),
          // Las casillas validas se marcan con borde blanco mientras se
          // arrastra un dado.
          border: esDestinoValido
              ? Border.all(color: Colors.white, width: 2)
              : esInicial
              ? Border.all(color: colores.onSurface.withValues(alpha: 0.25))
              : null,
        ),
        child: CustomPaint(
          key: region?.conRayas == true ? const ValueKey('rayas') : null,
          // Rayas diagonales para distinguir una de las dos regiones del
          // mismo color; quedan detras del numero y de la estrella.
          painter: region?.conRayas == true
              ? PintorDeRayas(color: colorDeTexto)
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final numero = FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    key: const ValueKey('numero-celda'),
                    // Se lee de la celda porque el numero tambien puede
                    // llegar desde un dado, no solo desde el menu.
                    celda.numero?.toString() ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorDeTexto,
                      fontWeight: esInicial ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              );

              if (!esInicial) {
                return Center(child: numero);
              }

              // Estrella en la esquina, como en el tablero del juego de mesa.
              return Stack(
                children: [
                  Center(child: numero),
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Icon(
                      key: const ValueKey('estrella'),
                      Icons.star_rounded,
                      size: constraints.maxWidth * 0.28,
                      color: colorDeTexto.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Dibuja rayas diagonales casi transparentes sobre la casilla, para que la
// region se distinga sin cambiar su color. Son del color del texto de la
// region: blancas en las regiones oscuras y oscuras en la blanca.
class PintorDeRayas extends CustomPainter {
  final Color color;

  const PintorDeRayas({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = size.width * 0.09;
    // Cuatro rayas por casilla, sin importar su tamaño.
    final separacion = size.width / 4;

    // Cada raya va de abajo a la izquierda hacia arriba a la derecha.
    for (var x = -size.height; x < size.width; x += separacion) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(PintorDeRayas oldDelegate) => oldDelegate.color != color;
}
