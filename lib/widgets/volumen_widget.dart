import 'package:flutter/material.dart';

import '../configuracion.dart';
import '../sonidos.dart';

// Boton con un engrane que abre la configuracion: el volumen (musica y
// efectos) y el modo de control de la partida.
class BotonConfiguracion extends StatelessWidget {
  // En el menu principal va relleno como el boton de la cuenta; en las barras
  // de arriba va simple.
  final bool relleno;

  const BotonConfiguracion({super.key, this.relleno = false});

  @override
  Widget build(BuildContext context) {
    void abrir() => mostrarConfiguracion(context);
    const icono = Icon(Icons.settings_rounded);

    return relleno
        ? IconButton.filledTonal(
            key: const ValueKey('boton-configuracion'),
            tooltip: 'Configuración',
            onPressed: abrir,
            icon: icono,
          )
        : IconButton(
            key: const ValueKey('boton-configuracion'),
            tooltip: 'Configuración',
            onPressed: abrir,
            icon: icono,
          );
  }
}

// Ventana de configuracion: el volumen de la musica y de los efectos, y el
// modo de control de la partida.
Future<void> mostrarConfiguracion(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _VentanaConfiguracion(),
  );
}

class _VentanaConfiguracion extends StatefulWidget {
  const _VentanaConfiguracion();

  @override
  State<_VentanaConfiguracion> createState() => _VentanaConfiguracionState();
}

class _VentanaConfiguracionState extends State<_VentanaConfiguracion> {
  // Para tocar un efecto de ejemplo al soltar la barra de los efectos.
  final Sonidos _sonidos = Sonidos();

  @override
  void dispose() {
    _sonidos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      key: const ValueKey('ventana-configuracion'),
      title: const Text('Configuración'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sonido', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          _FilaVolumen(
            clave: 'musica',
            nombre: 'Música',
            icono: Icons.music_note_rounded,
            volumen: Sonidos.volumenMusica,
          ),
          const SizedBox(height: 8),
          _FilaVolumen(
            clave: 'efectos',
            nombre: 'Efectos',
            icono: Icons.graphic_eq_rounded,
            volumen: Sonidos.volumenEfectos,
            alCambiar: _sonidos.colocar,
          ),
          const SizedBox(height: 16),
          Text('Controles', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          const _ModoDeControl(),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('boton-cerrar-configuracion'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

// Como se coloca el numero en la partida: tocando el ancla y luego la
// casilla, o arrastrando el dado. Se guarda en el telefono.
class _ModoDeControl extends StatelessWidget {
  const _ModoDeControl();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ValueListenableBuilder<ModoDeControl>(
      valueListenable: Configuracion.modoDeControl,
      builder: (context, modo, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ModoDeControl>(
            key: const ValueKey('modo-de-control'),
            segments: const [
              ButtonSegment(
                value: ModoDeControl.tocarAncla,
                icon: Icon(Icons.touch_app_rounded),
                label: Text('Tocar'),
              ),
              ButtonSegment(
                value: ModoDeControl.arrastrar,
                icon: Icon(Icons.pan_tool_alt_rounded),
                label: Text('Arrastrar'),
              ),
            ],
            selected: {modo},
            onSelectionChanged: (elegidos) =>
                Configuracion.elegirModo(elegidos.single),
          ),
          const SizedBox(height: 6),
          Text(
            modo == ModoDeControl.tocarAncla
                ? 'Toca el dado que será el ancla y luego la casilla donde va '
                      'el otro dado.'
                : 'Arrastra un dado a una casilla junto al número del otro '
                      'dado.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// Una barra de volumen con su nombre, el porcentaje y un boton para
// silenciar (al volver a tocarlo regresa al volumen que tenia).
class _FilaVolumen extends StatefulWidget {
  final String clave;
  final String nombre;
  final IconData icono;
  final ValueNotifier<double> volumen;
  // Se llama al terminar de cambiar el volumen (por ejemplo, para que suene
  // un efecto de prueba).
  final VoidCallback? alCambiar;

  const _FilaVolumen({
    required this.clave,
    required this.nombre,
    required this.icono,
    required this.volumen,
    this.alCambiar,
  });

  @override
  State<_FilaVolumen> createState() => _FilaVolumenState();
}

class _FilaVolumenState extends State<_FilaVolumen> {
  // Volumen que tenia antes de silenciarlo.
  double _antesDeSilenciar = 1;

  void _cambiar(double valor) {
    widget.volumen.value = valor;
    Sonidos.guardarVolumen();
    widget.alCambiar?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ValueListenableBuilder<double>(
      valueListenable: widget.volumen,
      builder: (context, volumen, _) {
        final silenciado = volumen == 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icono, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.nombre, style: tema.textTheme.titleSmall),
                ),
                Text(
                  '${(volumen * 100).round()}%',
                  key: ValueKey('porcentaje-${widget.clave}'),
                  style: tema.textTheme.labelLarge?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: ValueKey('silenciar-${widget.clave}'),
                  tooltip: silenciado ? 'Activar' : 'Silenciar',
                  onPressed: () {
                    if (silenciado) {
                      _cambiar(_antesDeSilenciar);
                    } else {
                      _antesDeSilenciar = volumen;
                      _cambiar(0);
                    }
                  },
                  icon: Icon(
                    silenciado
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: ValueKey('barra-${widget.clave}'),
                    value: volumen,
                    divisions: 20,
                    // Mientras se arrastra solo cambia el volumen; al soltar se
                    // guarda y suena el ejemplo.
                    onChanged: (valor) => widget.volumen.value = valor,
                    onChangeEnd: _cambiar,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
