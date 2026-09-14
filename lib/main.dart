import 'package:flutter/material.dart';

import 'proyecto_bloques.dart';

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
      home: const TableroPage(),
    );
  }
}

class TableroPage extends StatelessWidget {
  const TableroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final regiones = Region.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyecto Bloques'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: regiones.length,
        itemBuilder: (context, index) {
          final region = regiones[index];

          return Card(
            color: region.tipo.color,
            child: Center(
              child: Text(
                region.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}