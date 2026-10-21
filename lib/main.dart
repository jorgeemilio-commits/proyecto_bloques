import 'package:flutter/material.dart';

import 'pantallas/menu_principal.dart';

// Punto de entrada de la app: configura el tema y abre el menu principal.
// La partida vive en pantallas/partida.dart.
void main() {
  runApp(const ProyectoBloquesApp());
}

class ProyectoBloquesApp extends StatelessWidget {
  const ProyectoBloquesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto Bloques',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ).copyWith(
              // Fondo negro grisaceo y tarjetas un poco mas claras.
              surfaceContainerLow: const Color(0xFF2B2B2E),
              surface: const Color(0xFF38383C),
            ),
        useMaterial3: true,
      ),
      // La app empieza en el menu: Jugar -> elegir mapa -> partida.
      home: const MenuPrincipal(),
    );
  }
}
