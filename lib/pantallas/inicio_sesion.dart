import 'package:flutter/material.dart';

import '../constantes.dart';
import '../cuenta/servicio_cuenta.dart';
import 'crear_cuenta.dart';

// Pantalla para iniciar sesion con usuario y contraseña. Desde aqui tambien
// se va a crear una cuenta nueva.
class PantallaInicioSesion extends StatefulWidget {
  final ServicioDeCuenta servicio;
  // Se llama cuando el jugador ya inicio sesion (aqui o al crear su cuenta).
  final VoidCallback onSesionIniciada;

  const PantallaInicioSesion({
    super.key,
    required this.servicio,
    required this.onSesionIniciada,
  });

  @override
  State<PantallaInicioSesion> createState() => _PantallaInicioSesionState();
}

class _PantallaInicioSesionState extends State<PantallaInicioSesion> {
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await widget.servicio.iniciarSesion(
        _usuario.text.trim(),
        _contrasena.text,
      );
      widget.onSesionIniciada();
    } on ErrorDeCuenta catch (error) {
      if (mounted) {
        setState(() => _error = error.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _irACrearCuenta() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaCrearCuenta(
          servicio: widget.servicio,
          onSesionIniciada: widget.onSesionIniciada,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      key: const ValueKey('pantalla-inicio-sesion'),
      backgroundColor: tema.colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/imagenes/brilliant_logo_3x.png',
                    height: 110,
                    semanticLabel: 'Brilliant',
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const ValueKey('campo-usuario'),
                    controller: _usuario,
                    enabled: !_cargando,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('campo-contrasena'),
                    controller: _contrasena,
                    enabled: !_cargando,
                    obscureText: true,
                    onSubmitted: (_) => _entrar(),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const ValueKey('mensaje-error'),
                      style: TextStyle(color: tema.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('boton-entrar'),
                      onPressed: _cargando ? null : _entrar,
                      child: _cargando
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entrar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const ValueKey('ir-a-crear-cuenta'),
                    onPressed: _cargando ? null : _irACrearCuenta,
                    child: const Text('¿No tienes cuenta? Crear cuenta'),
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
