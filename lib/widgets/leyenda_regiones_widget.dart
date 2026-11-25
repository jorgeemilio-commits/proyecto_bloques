import 'package:flutter/material.dart';

import '../juego/tipo.dart';
import 'celda_widget.dart';

// Leyenda compacta con el color y la regla de cada tipo de region.
class LeyendaRegiones extends StatelessWidget {
  const LeyendaRegiones({super.key});

  static const List<(TipoRegion, String)> _entradas = [
    (TipoRegion.azul, 'Iguales'),
    (TipoRegion.rojo, 'Distintos'),
    (TipoRegion.amarillo, 'Distintos'),
    (TipoRegion.lila, 'Máx. 2 valores'),
    (TipoRegion.verde, 'Libre'),
    (TipoRegion.blanco, 'Iguales'),
    (TipoRegion.naranjaBaja, '1–3 · rayada 4–6'),
  ];

  @override
  Widget build(BuildContext context) {
    final estiloTexto = Theme.of(context).textTheme.labelMedium;

    return Wrap(
      key: const ValueKey('leyenda'),
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (tipo, regla) in _entradas)
          Row(
            key: ValueKey('leyenda-${tipo.nombre}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colorDeRegion(tipo),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(regla, style: estiloTexto),
            ],
          ),
      ],
    );
  }
}
