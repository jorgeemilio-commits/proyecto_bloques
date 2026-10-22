import 'package:flutter/material.dart';

import '../region.dart';
import 'celda_widget.dart';

// Codigo de colores del tablero: cada region con su muestra (apagada segun
// sus reclamos y con rayas si las lleva) y los puntos que da completarla.
class MenuRegionesWidget extends StatelessWidget {
  final List<Region> regiones;
  // Cuantas veces se ha reclamado cada region.
  final int Function(Region region) vecesReclamada;

  const MenuRegionesWidget({
    super.key,
    required this.regiones,
    required this.vecesReclamada,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListView(
      key: const ValueKey('menu-regiones'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        Text(
          'Regiones',
          style: tema.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Puntos por completar cada región. El resaltado es el que se '
          'gana ahora.',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final (indice, region) in regiones.indexed) ...[
          _FilaRegion(
            key: ValueKey('menu-region-$indice'),
            region: region,
            vecesReclamada: vecesReclamada(region),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FilaRegion extends StatelessWidget {
  final Region region;
  final int vecesReclamada;

  const _FilaRegion({
    super.key,
    required this.region,
    required this.vecesReclamada,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tipo = region.tipo;
    final nombre =
        '${tipo.nombre[0].toUpperCase()}${tipo.nombre.substring(1)}'
        '${region.conRayas ? ' rayada' : ''}';
    final premios = [
      for (var nivel = 1; nivel <= tipo.puntuaciones.length; nivel++)
        tipo.puntuaciones[nivel]!,
    ];
    final agotada = vecesReclamada >= premios.length;

    return Row(
      children: [
        // Muestra igual a una casilla de la region en el tablero.
        Container(
          width: 36,
          height: 36,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorDeRegion(tipo, vecesReclamada: vecesReclamada),
            borderRadius: BorderRadius.circular(6),
          ),
          child: region.conRayas
              ? CustomPaint(
                  painter: PintorDeRayas(color: colorDeTextoPara(tipo)),
                  child: const SizedBox.expand(),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: tema.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                agotada ? 'Ya no da puntos.' : tipo.descripcion,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        for (final (indice, puntos) in premios.indexed)
          _Premio(
            puntos: puntos,
            // indice 0 es el primer reclamo, 1 el segundo, etc.
            yaReclamado: indice < vecesReclamada,
            esElActual: indice == vecesReclamada,
          ),
      ],
    );
  }
}

// Un premio de la region: tachado si ya se reclamo, resaltado si es el que se
// gana ahora.
class _Premio extends StatelessWidget {
  final int puntos;
  final bool yaReclamado;
  final bool esElActual;

  const _Premio({
    required this.puntos,
    required this.yaReclamado,
    required this.esElActual,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 28,
      padding: const EdgeInsets.symmetric(vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: esElActual ? Colors.amber.shade300 : null,
        borderRadius: BorderRadius.circular(6),
        border: esElActual
            ? null
            : Border.all(color: colores.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$puntos',
        style: TextStyle(
          fontWeight: esElActual ? FontWeight.w800 : FontWeight.w500,
          color: esElActual
              ? Colors.black87
              : yaReclamado
              ? colores.onSurfaceVariant.withValues(alpha: 0.5)
              : colores.onSurface,
          decoration: yaReclamado ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
