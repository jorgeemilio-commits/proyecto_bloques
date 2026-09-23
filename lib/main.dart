import 'package:flutter/material.dart';

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
    );
  }
}
