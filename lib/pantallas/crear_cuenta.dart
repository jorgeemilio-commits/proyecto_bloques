import 'package:flutter/material.dart';

import '../constantes.dart';
import '../cuenta/servicio_cuenta.dart';

// Pantalla para crear una cuenta nueva. Al crearla, inicia sesion con ella.
class PantallaCrearCuenta extends StatefulWidget {
  final ServicioDeCuenta servicio;
  final VoidCallback onSesionIniciada;

  const PantallaCrearCuenta({
    super.key,
    required this.servicio,
    required this.onSesionIniciada,
  });

  @override
  State<PantallaCrearCuenta> createState() => _PantallaCrearCuentaState();
}

class _PantallaCrearCuentaState extends State<PantallaCrearCuenta> {
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    // Aqui solo se revisa que las dos contraseñas coincidan; el formato del
    // usuario, el largo de la contraseña y el nombre repetido los revisa el
    // servidor, que responde con su mensaje.
    if (_contrasena.text != _confirmacion.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuario = _usuario.text.trim();
      await widget.servicio.crearCuenta(usuario, _contrasena.text);
      await widget.servicio.iniciarSesion(usuario, _contrasena.text);
      if (mounted) {
        Navigator.of(context).pop();
      }
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

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estiloAyuda = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    InputDecoration decoracion(String etiqueta, IconData icono) =>
        InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          border: const OutlineInputBorder(),
        );

    return Scaffold(
      key: const ValueKey('pantalla-crear-cuenta'),
      backgroundColor: tema.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        centerTitle: true,
        backgroundColor: tema.colorScheme.surfaceContainerLow,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('campo-usuario'),
                    controller: _usuario,
                    enabled: !_cargando,
                    textInputAction: TextInputAction.next,
                    decoration: decoracion('Usuario', Icons.person_outline),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'De 3 a 20 letras (con acentos o ñ), números o guion bajo.',
                    style: estiloAyuda,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('campo-contrasena'),
                    controller: _contrasena,
                    enabled: !_cargando,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: decoracion('Contraseña', Icons.lock_outline),
                  ),
                  const SizedBox(height: 6),
                  Text('Al menos 8 caracteres.', style: estiloAyuda),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('campo-confirmacion'),
                    controller: _confirmacion,
                    enabled: !_cargando,
                    obscureText: true,
                    onSubmitted: (_) => _crear(),
                    decoration: decoracion(
                      'Repite la contraseña',
                      Icons.lock_outline,
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
                      key: const ValueKey('boton-crear-cuenta'),
                      onPressed: _cargando ? null : _crear,
                      child: _cargando
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crear cuenta'),
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
