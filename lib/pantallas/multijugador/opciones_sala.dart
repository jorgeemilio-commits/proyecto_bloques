// Opciones de la sala que elige el anfitrion: el mapa y el tiempo por ronda.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../lector_mapas.dart';
import '../../mapa.dart';
import '../seleccion_mapa.dart';

// Mapa de la sala con su vista previa, como en la eleccion de mapa offline.
// El anfitrion lo toca para cambiarlo (se abre la misma pantalla de elegir
// mapa); los demas solo lo ven.
class MapaDeLaSala extends StatefulWidget {
  final String mapa;
  final ValueChanged<String>? onElegir;

  const MapaDeLaSala({required this.mapa, this.onElegir});

  @override
  State<MapaDeLaSala> createState() => _MapaDeLaSalaState();
}

class _MapaDeLaSalaState extends State<MapaDeLaSala> {
  late Future<Mapa> _carga = _cargar();

  Future<Mapa> _cargar() => cargarMapa('$carpetaMapas${widget.mapa}.txt');

  @override
  void didUpdateWidget(MapaDeLaSala anterior) {
    super.didUpdateWidget(anterior);
    // El anfitrion cambio el mapa.
    if (anterior.mapa != widget.mapa) {
      _carga = _cargar();
    }
  }

  void _cambiar(ValueChanged<String> onElegir) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (contextoRuta) => SeleccionMapa(
          alElegir: (archivo) {
            Navigator.of(contextoRuta).pop();
            if (archivo != widget.mapa) {
              onElegir(archivo);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onElegir = widget.onElegir;

    return FutureBuilder<Mapa>(
      future: _carga,
      builder: (context, carga) {
        final mapa = carga.data;
        if (mapa == null) {
          return SizedBox(
            height: 136,
            child: Center(
              child: carga.hasError
                  ? Text('No se pudo leer el mapa "${widget.mapa}".')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return TarjetaMapa(
          key: const ValueKey('mapa-de-la-sala'),
          mapa: mapa,
          onElegir: onElegir == null ? null : () => _cambiar(onElegir),
          detalle: onElegir == null ? null : 'Toca para cambiar el mapa',
        );
      },
    );
  }
}

// Tiempo por ronda de la sala. El anfitrion elige entre "Sin limite" y
// varios tiempos; los demas solo ven el elegido.
class TiempoPorRonda extends StatelessWidget {
  // Los mismos que acepta el servidor; null = sin limite.
  static const List<int?> _opciones = [null, 20, 30, 40, 60, 90];

  final int? segundos;
  final ValueChanged<int?>? onElegir;

  const TiempoPorRonda({required this.segundos, this.onElegir});

  static String _texto(int? segundos) =>
      segundos == null ? 'Sin límite' : '$segundos s';

  @override
  Widget build(BuildContext context) {
    final onElegir = this.onElegir;
    if (onElegir == null) {
      return InputDecorator(
        decoration: const InputDecoration(border: OutlineInputBorder()),
        child: Text(
          segundos == null
              ? 'Sin límite: la ronda espera a que todos jueguen'
              : '${_texto(segundos)} por ronda',
          key: const ValueKey('tiempo-de-la-sala'),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opcion in _opciones)
          ChoiceChip(
            key: ValueKey('tiempo-${opcion ?? 'sin-limite'}'),
            label: Text(_texto(opcion)),
            selected: opcion == segundos,
            onSelected: (_) {
              if (opcion != segundos) {
                onElegir(opcion);
              }
            },
          ),
      ],
    );
  }
}
