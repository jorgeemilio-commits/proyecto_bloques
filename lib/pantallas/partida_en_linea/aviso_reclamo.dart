// Aviso de que un rival completo una region.

import 'package:flutter/material.dart';

import '../../constantes.dart';
import '../../region.dart';
import '../../widgets/celda_widget.dart';

// Una region que completo un rival, para avisarlo.
class ReclamoDeRival {
  final int id;
  final String usuario;
  // null si la region no esta en el mapa (no deberia pasar).
  final Region? region;
  final int puntos;

  const ReclamoDeRival({
    required this.id,
    required this.usuario,
    required this.region,
    required this.puntos,
  });
}

// Aviso pequeño de que un rival completo una region: entra deslizandose
// desde la izquierda, se queda un momento y se regresa por donde vino. Al
// terminar se quita.
class AvisoDeReclamo extends StatefulWidget {
  final ReclamoDeRival reclamo;
  final VoidCallback alTerminar;

  const AvisoDeReclamo({
    super.key,
    required this.reclamo,
    required this.alTerminar,
  });

  @override
  State<AvisoDeReclamo> createState() => _AvisoDeReclamoState();
}

class _AvisoDeReclamoState extends State<AvisoDeReclamo>
    with SingleTickerProviderStateMixin {
  // Todo el aviso dura 3.5 segundos: entra en el primer 10% del tiempo, se
  // queda, y en el ultimo 15% se regresa a la izquierda por donde vino.
  late final AnimationController _tiempo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3500),
  )..forward().whenComplete(widget.alTerminar);

  late final Animation<Offset> _posicion = TweenSequence<Offset>([
    TweenSequenceItem(
      tween: Tween(
        begin: const Offset(-1.2, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 10,
    ),
    TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 75),
    TweenSequenceItem(
      tween: Tween(
        begin: Offset.zero,
        end: const Offset(-1.2, 0),
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 15,
    ),
  ]).animate(_tiempo);

  @override
  void dispose() {
    _tiempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final reclamo = widget.reclamo;
    final region = reclamo.region;
    final color = region == null ? naranjaLogo : colorDeRegion(region.tipo);
    final premio = reclamo.puntos > 0 ? '+${reclamo.puntos}' : 'sin puntos';

    return SlideTransition(
      position: _posicion,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: tema.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(12),
          ),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: reclamo.usuario,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          ' completó una región '
                          '${region?.tipo.nombre ?? ''} · ',
                    ),
                    TextSpan(
                      text: premio,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: reclamo.puntos > 0 ? naranjaLogo : null,
                      ),
                    ),
                  ],
                ),
                key: const ValueKey('texto-aviso-reclamo'),
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
