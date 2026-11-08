import 'package:flutter/material.dart';

import '../constantes.dart';
import '../lector_mapas.dart';
import '../mapa.dart';
import '../widgets/tablero_widget.dart';
import 'partida.dart';

// Pantalla para elegir el mapa de la partida. Muestra una tarjeta por cada
// archivo de assets/mapas/; al tocar una empieza la partida con ese mapa. Si
// se pasa [alElegir] (desde una sala en linea), al tocar un mapa se llama con
// su nombre de archivo ('clasico', 'borde'...) en lugar de empezar.
class SeleccionMapa extends StatefulWidget {
  final ValueChanged<String>? alElegir;

  const SeleccionMapa({super.key, this.alElegir});

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
                          key: ValueKey('mapa-${nombreDeArchivo(ruta)}'),
                          ruta: ruta,
                          alElegir: widget.alElegir,
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
String nombreDeArchivo(String ruta) =>
    ruta.substring(ruta.lastIndexOf('/') + 1).replaceAll('.txt', '');

// Carga un archivo de mapa y muestra su tarjeta. Si el archivo tiene un error,
// muestra el error en su lugar sin afectar a los demas mapas.
class _ArchivoDeMapa extends StatefulWidget {
  final String ruta;
  final ValueChanged<String>? alElegir;

  const _ArchivoDeMapa({super.key, required this.ruta, this.alElegir});

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
                'No se pudo leer ${nombreDeArchivo(widget.ruta)}.txt: '
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

        final alElegir = widget.alElegir;
        return TarjetaMapa(
          mapa: mapa,
          onElegir: alElegir != null
              ? () => alElegir(nombreDeArchivo(widget.ruta))
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VistaPreviaTablero(mapa: mapa),
                  ),
                ),
        );
      },
    );
  }
}

// Tarjeta de un mapa con su vista previa, nombre y tamaño. Sin [onElegir]
// solo se muestra (no se puede tocar). [detalle] reemplaza el texto del tamaño.
class TarjetaMapa extends StatelessWidget {
  final Mapa mapa;
  final VoidCallback? onElegir;
  final String? detalle;

  const TarjetaMapa({
    super.key,
    required this.mapa,
    this.onElegir,
    this.detalle,
  });

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
                      detalle ??
                          '${mapa.columnas}×${mapa.filas} · '
                              '${mapa.regiones.length} regiones',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onElegir != null)
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
