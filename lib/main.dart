import 'package:flutter/material.dart';

import 'region.dart';
import 'tablero.dart';
import 'widgets/tablero_widget.dart';

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
      home: const VistaPreviaTablero(),
    );
  }
}

class VistaPreviaTablero extends StatelessWidget {
  const VistaPreviaTablero({super.key});

  @override
  Widget build(BuildContext context) {
    final tablero = Tablero.desdeRegiones(
      filas: 7,
      columnas: 7,
      regiones: regionesMapa,
    );
    tablero.celdasIniciales.first.numero = 4;

    return Scaffold(
      appBar: AppBar(title: const Text('Tablero de Proyecto Bloques')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: TableroWidget(tablero: tablero),
          ),
        ),
      ),
    );
  }
}
