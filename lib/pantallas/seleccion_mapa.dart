import 'package:flutter/material.dart';

import '../constantes.dart';
import '../lector_mapas.dart';
import '../mapa.dart';
import '../widgets/tablero_widget.dart';
import 'partida.dart';

// Pantalla para elegir el mapa de la partida. Por ahora solo existe el mapa
// clasico, que se lee de assets/mapas/; al tocarlo empieza la partida.
class SeleccionMapa extends StatefulWidget {
  const SeleccionMapa({super.key});

  @override
  State<SeleccionMapa> createState() => _SeleccionMapaState();
}

class _SeleccionMapaState extends State<SeleccionMapa> {
  // Se carga una sola vez al abrir la pantalla.
  late final Future<Mapa> _mapaClasico = cargarMapa(rutaMapaClasico);

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
            child: FutureBuilder<Mapa>(
              future: _mapaClasico,
              builder: (context, carga) {
                if (carga.hasError) {
                  // Por ejemplo, un error de formato en el archivo del mapa.
                  final error = carga.error;
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudo leer el mapa: '
                      '${error is FormatException ? error.message : error}',
                      key: const ValueKey('error-mapa'),
                      style: TextStyle(color: colores.error),
                    ),
                  );
                }
                final mapa = carga.data;
                if (mapa == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _TarjetaMapa(
                      key: const ValueKey('mapa-clasico'),
                      mapa: mapa,
                      onElegir: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => VistaPreviaTablero(mapa: mapa),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
