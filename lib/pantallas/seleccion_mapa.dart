import 'package:flutter/material.dart';

import '../constantes.dart';
import '../lector_mapas.dart';
import '../mapa.dart';
import '../widgets/tablero_widget.dart';
import 'partida.dart';

// Pantalla para elegir el mapa de la partida. Muestra una tarjeta por cada
// archivo de assets/mapas/; al tocar una empieza la partida con ese mapa.
class SeleccionMapa extends StatefulWidget {
  const SeleccionMapa({super.key});

  @override
  State<SeleccionMapa> createState() => _SeleccionMapaState();
}

class _SeleccionMapaState extends State<SeleccionMapa> {
  // La lista de archivos se pide una sola vez al abrir la pantalla.
  late final Future<List<String>> _rutas = rutasDeMapas();

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
            child: FutureBuilder<List<String>>(
              future: _rutas,
              builder: (context, carga) {
                final rutas = carga.data;
                if (rutas == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final ruta in rutas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ArchivoDeMapa(
                          key: ValueKey('mapa-${_nombreDeArchivo(ruta)}'),
                          ruta: ruta,
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

// Nombre del archivo sin carpeta ni extension: 'assets/mapas/borde.txt' ->
// 'borde'.
String _nombreDeArchivo(String ruta) =>
    ruta.substring(ruta.lastIndexOf('/') + 1).replaceAll('.txt', '');

// Carga un archivo de mapa y muestra su tarjeta. Si el archivo tiene un error,
// muestra el error en su lugar sin afectar a los demas mapas.
class _ArchivoDeMapa extends StatefulWidget {
  final String ruta;

  const _ArchivoDeMapa({super.key, required this.ruta});

  @override
  State<_ArchivoDeMapa> createState() => _ArchivoDeMapaState();
}

class _ArchivoDeMapaState extends State<_ArchivoDeMapa> {
  // El mapa se lee una sola vez.
  late final Future<Mapa> _mapa = cargarMapa(widget.ruta);

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return FutureBuilder<Mapa>(
      future: _mapa,
      builder: (context, carga) {
        if (carga.hasError) {
          // Por ejemplo, un error de formato dentro del archivo.
          final error = carga.error;
          return Card(
            elevation: 0,
            color: colores.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No se pudo leer ${_nombreDeArchivo(widget.ruta)}.txt: '
                '${error is FormatException ? error.message : error}',
                key: const ValueKey('error-mapa'),
                style: TextStyle(color: colores.onErrorContainer),
              ),
            ),
          );
        }
        final mapa = carga.data;
        if (mapa == null) {
          return const SizedBox(
            height: 136,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return _TarjetaMapa(
          mapa: mapa,
          onElegir: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VistaPreviaTablero(mapa: mapa),
            ),
          ),
        );
      },
    );
  }
}

// Tarjeta de un mapa con su vista previa, nombre y tamaño.
class _TarjetaMapa extends StatelessWidget {
  final Mapa mapa;
  final VoidCallback onElegir;

  const _TarjetaMapa({required this.mapa, required this.onElegir});

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
