import 'package:flutter/material.dart';

import '../constantes.dart';
import '../cuenta/servicio_cuenta.dart';
import '../widgets/estilo_cuenta.dart';
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
  bool _verContrasena = false;
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
    final colores = tema.colorScheme;

    return Scaffold(
      key: const ValueKey('pantalla-inicio-sesion'),
      backgroundColor: colores.surfaceContainerLow,
      body: FondoDelLogo(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: anchoMaximoTelefono,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // El logo aparece y crece al abrir la pantalla.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, entrada, logo) => Opacity(
                        opacity: entrada,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * entrada,
                          child: logo,
                        ),
                      ),
                      child: Image.asset(
                        'assets/imagenes/brilliant_logo_3x.png',
                        height: 120,
                        semanticLabel: 'Brilliant',
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '¡Qué bueno verte!',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Inicia sesión para jugar con tus amigos.',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodyLarge?.copyWith(
                        color: colores.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tarjeta con el formulario.
                    Card(
                      elevation: 0,
                      color: colores.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              key: const ValueKey('campo-usuario'),
                              controller: _usuario,
                              enabled: !_cargando,
                              textInputAction: TextInputAction.next,
                              decoration: decoracionDeCampo(
                                'Usuario',
                                Icons.person_outline,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('campo-contrasena'),
                              controller: _contrasena,
                              enabled: !_cargando,
                              obscureText: !_verContrasena,
                              onSubmitted: (_) => _entrar(),
                              decoration:
                                  decoracionDeCampo(
                                    'Contraseña',
                                    Icons.lock_outline,
                                  ).copyWith(
                                    suffixIcon: BotonVerContrasena(
                                      visible: _verContrasena,
                                      onPressed: () => setState(
                                        () => _verContrasena = !_verContrasena,
                                      ),
                                    ),
                                  ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              RecuadroDeError(mensaje: _error!),
                            ],
                            const SizedBox(height: 20),
                            BotonDegradado(
                              key: const ValueKey('boton-entrar'),
                              texto: 'Entrar',
                              cargando: _cargando,
                              onPressed: _entrar,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Wrap: si no cabe en una linea, el boton baja a la otra.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '¿No tienes cuenta?',
                          style: TextStyle(color: colores.onSurfaceVariant),
                        ),
                        TextButton(
                          key: const ValueKey('ir-a-crear-cuenta'),
                          onPressed: _cargando ? null : _irACrearCuenta,
                          child: const Text(
                            'Crear cuenta',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
