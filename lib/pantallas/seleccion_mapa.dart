import 'package:flutter/material.dart';

import '../main.dart' show anchoMaximoTelefono, VistaPreviaTablero;
import '../mapa.dart';
import '../widgets/tablero_widget.dart';

// Pantalla para elegir el mapa de la partida. Por ahora solo existe el mapa
// clasico; al tocarlo empieza la partida.
class SeleccionMapa extends StatelessWidget {
  const SeleccionMapa({super.key});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('seleccion-mapa'),
      backgroundColor: colores.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Elige un mapa'),
        centerTitle: true,
        backgroundColor: colores.surfaceContainerLow,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TarjetaMapa(
                  key: const ValueKey('mapa-clasico'),
                  mapa: mapaClasico,
                  onElegir: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const VistaPreviaTablero(mapa: mapaClasico),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tarjeta de un mapa con su vista previa, nombre y tamaño.
class _TarjetaMapa extends StatelessWidget {
  final Mapa mapa;
  final VoidCallback onElegir;

  const _TarjetaMapa({super.key, required this.mapa, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      elevation: 0,
      color: tema.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onElegir,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Vista previa del tablero; no se puede tocar.
              SizedBox(
                width: 112,
                child: IgnorePointer(
                  child: TableroWidget(tablero: mapa.crearTablero()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mapa.nombre,
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${mapa.columnas}×${mapa.filas} · '
                      '${mapa.regiones.length} regiones',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
