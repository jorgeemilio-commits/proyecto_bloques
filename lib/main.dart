import 'package:flutter/material.dart';

import 'region.dart';
import 'tablero.dart';
import 'widgets/celda_widget.dart';

void main() {
  runApp(const ProyectoBloquesApp());
}

class ProyectoBloquesApp extends StatelessWidget {
  const ProyectoBloquesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto Bloques',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const VistaPreviaCelda(),
    );
  }
}

class VistaPreviaCelda extends StatelessWidget {
  const VistaPreviaCelda({super.key});

  @override
  Widget build(BuildContext context) {
    final celdaInicial = Celda(
      coordenada: const Coordenada(0, 0),
      numero: 4,
    );
    final celdaVacia = Celda(coordenada: const Coordenada(1, 1));
    final celdaConRegion = Celda(coordenada: const Coordenada(2, 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa de celdas')),
      body: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CeldaWidget(
                celda: celdaInicial,
                region: null,
                esInicial: true,
              ),
            ),
            SizedBox(
              width: 72,
              height: 72,
              child: CeldaWidget(
                celda: celdaVacia,
                region: null,
              ),
            ),
            SizedBox(
              width: 72,
              height: 72,
              child: CeldaWidget(
                celda: celdaConRegion,
                region: const RegionAzulUno(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
