// Entrada al multijugador: crear una sala o unirse con su codigo.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../multijugador/servicio_sala.dart';
import '../../widgets/estilo_cuenta.dart';

// Crear una sala nueva o unirse a una con su codigo.
class EntradaDeSala extends StatefulWidget {
  final ServicioDeSala sala;

  const EntradaDeSala({required this.sala});

  @override
  State<EntradaDeSala> createState() => _EntradaState();
}

class _EntradaState extends State<EntradaDeSala>
    with SingleTickerProviderStateMixin {
  final _codigo = TextEditingController();
  // Error al unirse (por ejemplo, "Esa partida ya empezó."): se muestra
  // debajo del codigo hasta que se escribe otro.
  String? _error;
  late final StreamSubscription<String> _errores;
  // Sacudida del campo del codigo cuando hay un error.
  late final AnimationController _sacudida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void initState() {
    super.initState();
    _errores = widget.sala.erroresAlUnirse.listen((mensaje) {
      if (!mounted) {
        return;
      }
      setState(() => _error = mensaje);
      _sacudida.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _errores.cancel();
    _sacudida.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _unirse() {
    final codigo = _codigo.text.trim();
    if (codigo.isNotEmpty) {
      widget.sala.unirse(codigo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      key: const ValueKey('entrada-sala'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Juega con tus amigos',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Crea una sala y comparte el código, o únete con el código de '
          'un amigo.',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('boton-crear-sala'),
            onPressed: widget.sala.crearSala,
            icon: const Icon(Icons.add),
            label: const Text('Crear sala'),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o',
                style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        // El campo se sacude de lado a lado cuando hay un error.
        AnimatedBuilder(
          animation: _sacudida,
          builder: (context, campo) {
            final t = _sacudida.value;
            final desplazamiento = _sacudida.isAnimating
                ? sin(t * pi * 6) * 10 * (1 - t)
                : 0.0;
            return Transform.translate(
              offset: Offset(desplazamiento, 0),
              child: campo,
            );
          },
          child: TextField(
            key: const ValueKey('campo-codigo'),
            controller: _codigo,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: tema.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
            onSubmitted: (_) => _unirse(),
            // Al escribir otro codigo se quita el error.
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Código de la sala',
              border: const OutlineInputBorder(),
              counterText: '',
              // Borde rojo mientras hay un error.
              enabledBorder: _error == null
                  ? null
                  : OutlineInputBorder(
                      borderSide: BorderSide(
                        color: tema.colorScheme.error,
                        width: 2,
                      ),
                    ),
              focusedBorder: _error == null
                  ? null
                  : OutlineInputBorder(
                      borderSide: BorderSide(
                        color: tema.colorScheme.error,
                        width: 2,
                      ),
                    ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          RecuadroDeError(mensaje: _error!),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('boton-unirse'),
            onPressed: _unirse,
            icon: const Icon(Icons.login),
            label: const Text('Unirse'),
          ),
        ),
      ],
    );
  }
}
