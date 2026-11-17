import 'package:flutter/material.dart';

import '../sonidos.dart';

// Boton con una bocina que abre la ventana del volumen. El icono cambia
// cuando la musica y los efectos estan apagados.
class BotonVolumen extends StatelessWidget {
  // En el menu principal va relleno como el boton de la cuenta; en las barras
  // de arriba va simple.
  final bool relleno;

  const BotonVolumen({super.key, this.relleno = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Sonidos.volumenMusica,
        Sonidos.volumenEfectos,
      ]),
      builder: (context, _) {
        final silencio =
            Sonidos.volumenMusica.value == 0 &&
            Sonidos.volumenEfectos.value == 0;
        final icono = Icon(
          silencio ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        );
        void abrir() => mostrarVolumen(context);

        return relleno
            ? IconButton.filledTonal(
                key: const ValueKey('boton-volumen'),
                tooltip: 'Volumen',
                onPressed: abrir,
                icon: icono,
              )
            : IconButton(
                key: const ValueKey('boton-volumen'),
                tooltip: 'Volumen',
                onPressed: abrir,
                icon: icono,
              );
      },
    );
  }
}

// Ventana con una barra para la musica y otra para los efectos.
Future<void> mostrarVolumen(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _VentanaVolumen(),
  );
}

class _VentanaVolumen extends StatefulWidget {
  const _VentanaVolumen();

  @override
  State<_VentanaVolumen> createState() => _VentanaVolumenState();
}

class _VentanaVolumenState extends State<_VentanaVolumen> {
  // Para tocar un efecto de ejemplo al soltar la barra de los efectos.
  final Sonidos _sonidos = Sonidos();

  @override
  void dispose() {
    _sonidos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('ventana-volumen'),
      title: const Text('Volumen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('boton-cerrar-volumen'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Listo'),
        ),
      ],
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
