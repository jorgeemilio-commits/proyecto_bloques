import 'package:flutter/material.dart';

import '../constantes.dart';
import '../cuenta/servicio_cuenta.dart';

// Pantalla de la cuenta del jugador: su nombre, cerrar sesion y borrar la
// cuenta (pide la contraseña para confirmar).
class PantallaCuenta extends StatelessWidget {
  final ServicioDeCuenta servicio;
  // Se llama cuando el jugador ya no tiene sesion (la cerro o borro su
  // cuenta), para volver a iniciar sesion.
  final VoidCallback onSalir;

  const PantallaCuenta({
    super.key,
    required this.servicio,
    required this.onSalir,
  });

  void _cerrarSesion() {
    servicio.cerrarSesion();
    onSalir();
  }

  Future<void> _borrarCuenta(BuildContext context) async {
    final borrada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoBorrarCuenta(servicio: servicio),
    );
    if (borrada ?? false) {
      onSalir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      key: const ValueKey('pantalla-cuenta'),
      backgroundColor: tema.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        centerTitle: true,
        backgroundColor: tema.colorScheme.surfaceContainerLow,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 40,
                    child: Icon(
                      Icons.person,
                      size: 44,
                      color: tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    servicio.usuario ?? '',
                    key: const ValueKey('nombre-usuario'),
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      key: const ValueKey('boton-cerrar-sesion'),
                      onPressed: _cerrarSesion,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: TextButton.icon(
                      key: const ValueKey('boton-borrar-cuenta'),
                      style: TextButton.styleFrom(
                        foregroundColor: tema.colorScheme.error,
                      ),
                      onPressed: () => _borrarCuenta(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Borrar cuenta'),
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

// Confirma el borrado de la cuenta pidiendo la contraseña. Devuelve true si
// la cuenta se borro.
class _DialogoBorrarCuenta extends StatefulWidget {
  final ServicioDeCuenta servicio;

  const _DialogoBorrarCuenta({required this.servicio});

  @override
  State<_DialogoBorrarCuenta> createState() => _DialogoBorrarCuentaState();
}

class _DialogoBorrarCuentaState extends State<_DialogoBorrarCuenta> {
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _borrar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await widget.servicio.borrarCuenta(_contrasena.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ErrorDeCuenta catch (error) {
      if (mounted) {
        setState(() {
          _error = error.mensaje;
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return AlertDialog(
      key: const ValueKey('dialogo-borrar-cuenta'),
      title: const Text('¿Borrar tu cuenta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esto no se puede deshacer. Escribe tu contraseña para confirmar.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('campo-contrasena-borrar'),
            controller: _contrasena,
            enabled: !_cargando,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _borrar(),
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('mensaje-error'),
              style: TextStyle(color: colores.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cargando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('confirmar-borrar-cuenta'),
          style: FilledButton.styleFrom(
            backgroundColor: colores.error,
            foregroundColor: colores.onError,
          ),
          onPressed: _cargando ? null : _borrar,
          child: const Text('Borrar cuenta'),
        ),
      ],
    );
  }
}
