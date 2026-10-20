import 'package:flutter/material.dart';

import '../main.dart' show anchoMaximoTelefono;
import 'seleccion_mapa.dart';

// Primera pantalla de la app: titulo del juego y boton para jugar.
class MenuPrincipal extends StatelessWidget {
  const MenuPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      key: const ValueKey('menu-principal'),
      backgroundColor: tema.colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Icon(
                    Icons.grid_view_rounded,
                    size: 88,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  // Logo del juego en lugar del titulo en texto.
                  Image.asset(
                    'assets/imagenes/brilliant_logo_3x.png',
                    key: const ValueKey('logo'),
                    width: 300,
                    semanticLabel: 'Brilliant',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Llena las regiones con los dados',
                    style: tema.textTheme.bodyLarge?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      key: const ValueKey('boton-jugar'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SeleccionMapa(),
                        ),
                      ),
                      child: const Text('Jugar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
