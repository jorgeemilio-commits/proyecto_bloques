import 'dart:math';

import 'package:flutter/material.dart';

import '../constantes.dart';
import '../tipo.dart';

// Una region que el jugador acaba de completar, para celebrarla en su
// tablero. Cada reclamo lleva su propio [id] para que la animacion se repita
// aunque se complete otra region del mismo color.
class Destello {
  final int id;
  final String regionId;
  final int puntos;

  const Destello({
    required this.id,
    required this.regionId,
    required this.puntos,
  });
}

// Brillo que cubre una casilla de la region recien completada: aparece
// blanco con borde naranja y se desvanece en menos de un segundo.
class DestelloCelda extends StatelessWidget {
  const DestelloCelda({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOut,
      builder: (context, intensidad, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6 * intensidad),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: naranjaLogo.withValues(alpha: intensidad),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: naranjaLogo.withValues(alpha: 0.7 * intensidad),
              blurRadius: 12 * intensidad,
            ),
          ],
        ),
      ),
    );
  }
}

// "+N" grande que salta en medio del tablero, sube un poco y se desvanece.
class PuntosFlotantes extends StatelessWidget {
  final int puntos;

  const PuntosFlotantes({super.key, required this.puntos});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      builder: (context, t, hijo) {
        // Rebota al entrar (primer 35%), sube despacio y se apaga al final.
        final escala = Curves.elasticOut.transform((t / 0.35).clamp(0, 1));
        final opacidad = t < 0.65 ? 1.0 : (1 - t) / 0.35;
        return Opacity(
          opacity: opacidad.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -50 * t),
            child: Transform.scale(scale: escala, child: hijo),
          ),
        );
      },
      child: Text(
        '+$puntos',
        key: const ValueKey('puntos-flotantes'),
        style: const TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w900,
          color: naranjaLogo,
          shadows: [
            Shadow(color: Colors.black87, blurRadius: 12),
            Shadow(color: rosaLogo, blurRadius: 24),
          ],
        ),
      ),
    );
  }
}

// Lluvia de confeti que cae una vez por toda la pantalla (al ganar).
class Confeti extends StatefulWidget {
  const Confeti({super.key});

  @override
  State<Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<Confeti> with SingleTickerProviderStateMixin {
  late final AnimationController _tiempo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  )..forward();

  late final List<_Papelito> _papelitos = _crearPapelitos();

  static List<_Papelito> _crearPapelitos() {
    final azar = Random();
    // Los colores de las regiones y del logo.
    final colores = [
      naranjaLogo,
      rosaLogo,
      for (final tipo in const [
        TipoRegion.amarillo,
        TipoRegion.rojo,
        TipoRegion.azul,
        TipoRegion.verde,
        TipoRegion.lila,
      ])
        HSLColor.fromColor(tipo.color).withLightness(0.6).toColor(),
    ];
    return [
      for (var i = 0; i < 90; i++)
        _Papelito(
          x: azar.nextDouble(),
          retraso: azar.nextDouble() * 0.35,
          velocidad: 0.8 + azar.nextDouble() * 0.7,
          vaiven: 10 + azar.nextDouble() * 25,
          giro: azar.nextDouble() * 2 * pi,
          velocidadGiro: (azar.nextDouble() - 0.5) * 16,
          tamano: 6 + azar.nextDouble() * 6,
          color: colores[azar.nextInt(colores.length)],
        ),
    ];
  }

  @override
  void dispose() {
    _tiempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        key: const ValueKey('confeti'),
        size: Size.infinite,
        painter: _PintorDeConfeti(_papelitos, _tiempo),
      ),
    );
  }
}

class _Papelito {
  // Posicion horizontal (0 a 1 del ancho).
  final double x;
  // Cuanto tarda en empezar a caer (fraccion de la animacion).
  final double retraso;
  // Que tan rapido cae, relativo al alto de la pantalla.
  final double velocidad;
  // Cuanto se mece de lado a lado, en pixeles.
  final double vaiven;
  final double giro;
  final double velocidadGiro;
  final double tamano;
  final Color color;

  const _Papelito({
    required this.x,
    required this.retraso,
    required this.velocidad,
    required this.vaiven,
    required this.giro,
    required this.velocidadGiro,
    required this.tamano,
    required this.color,
  });
}

class _PintorDeConfeti extends CustomPainter {
  final List<_Papelito> papelitos;
  final Animation<double> tiempo;

  _PintorDeConfeti(this.papelitos, this.tiempo) : super(repaint: tiempo);

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint();
    for (final papelito in papelitos) {
      final t = (tiempo.value - papelito.retraso) / (1 - papelito.retraso);
      if (t <= 0) {
        continue;
      }
      // Empieza arriba de la pantalla y cae hasta pasar el borde de abajo.
      final y = -20 + t * papelito.velocidad * (size.height + 40);
      final x =
          papelito.x * size.width +
          sin(t * 8 + papelito.giro) * papelito.vaiven;
      // Se desvanece en el ultimo 20% de la animacion.
      final opacidad = tiempo.value < 0.8 ? 1.0 : (1 - tiempo.value) / 0.2;
      pincel.color = papelito.color.withValues(alpha: opacidad.clamp(0, 1));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(papelito.giro + t * papelito.velocidadGiro);
      // Rectangulos delgados que parecen voltearse al girar.
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: papelito.tamano,
          height: papelito.tamano * 0.5 * (0.3 + cos(t * 12).abs()),
        ),
        pincel,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PintorDeConfeti oldDelegate) => false;
}
