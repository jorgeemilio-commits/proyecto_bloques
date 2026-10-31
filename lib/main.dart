import 'package:flutter/material.dart';

import 'cuenta/servicio_cuenta.dart';
import 'pantallas/inicio_sesion.dart';
import 'pantallas/menu_principal.dart';

// Punto de entrada de la app: configura el tema y abre el inicio de sesion
// (o el menu principal si ya hay sesion). La partida vive en
// pantallas/partida.dart.
void main() {
  runApp(const ProyectoBloquesApp());
}

class ProyectoBloquesApp extends StatefulWidget {
  // Las pruebas pasan un servicio con un servidor falso.
  final ServicioDeCuenta? servicio;

  const ProyectoBloquesApp({super.key, this.servicio});

  @override
  State<ProyectoBloquesApp> createState() => _ProyectoBloquesAppState();
}

class _ProyectoBloquesAppState extends State<ProyectoBloquesApp> {
  late final ServicioDeCuenta _servicio = widget.servicio ?? ServicioDeCuenta();

  @override
  void dispose() {
    if (widget.servicio == null) {
      _servicio.dispose();
    }
    super.dispose();
  }

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
      // Sin sesion se ve el inicio de sesion; con sesion, el menu (Jugar ->
      // elegir mapa -> partida). Cambia solo cuando el servicio avisa que
      // entro o salio el jugador.
      home: ListenableBuilder(
        listenable: _servicio,
        builder: (context, _) => _servicio.conSesion
            ? MenuPrincipal(servicio: _servicio)
            : PantallaInicioSesion(
                servicio: _servicio,
                // No hace falta navegar: al iniciar sesion el servicio avisa
                // y aqui se cambia al menu.
                onSesionIniciada: () {},
              ),
      ),
    );
  }
}
