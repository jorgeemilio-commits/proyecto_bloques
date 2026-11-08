import 'package:flutter/material.dart';

import '../constantes.dart';
import '../cuenta/servicio_cuenta.dart';
import '../widgets/estilo_cuenta.dart';

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
  bool _verContrasenas = false;
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
    final colores = tema.colorScheme;
    // El mismo "ojito" muestra u oculta las dos contraseñas.
    final ojito = BotonVerContrasena(
      visible: _verContrasenas,
      onPressed: () => setState(() => _verContrasenas = !_verContrasenas),
    );

    return Scaffold(
      key: const ValueKey('pantalla-crear-cuenta'),
      backgroundColor: colores.surfaceContainerLow,
      // La barra de arriba es transparente para que se vea el fondo.
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: FondoDelLogo(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              // Arriba se deja lugar para la flecha de regresar.
              padding: const EdgeInsets.fromLTRB(24, kToolbarHeight, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: anchoMaximoTelefono,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/imagenes/brilliant_logo_3x.png',
                      height: 80,
                      semanticLabel: 'Brilliant',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Crea tu cuenta',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Elige tu nombre de jugador y una contraseña para '
                      'empezar a jugar.',
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
                                ayuda:
                                    'De 3 a 20 letras (con acentos o ñ), '
                                    'números o guion bajo.',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('campo-contrasena'),
                              controller: _contrasena,
                              enabled: !_cargando,
                              obscureText: !_verContrasenas,
                              textInputAction: TextInputAction.next,
                              decoration: decoracionDeCampo(
                                'Contraseña',
                                Icons.lock_outline,
                                ayuda: 'Al menos 8 caracteres.',
                              ).copyWith(suffixIcon: ojito),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('campo-confirmacion'),
                              controller: _confirmacion,
                              enabled: !_cargando,
                              obscureText: !_verContrasenas,
                              onSubmitted: (_) => _crear(),
                              decoration: decoracionDeCampo(
                                'Repite la contraseña',
                                Icons.lock_outline,
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              RecuadroDeError(mensaje: _error!),
                            ],
                            const SizedBox(height: 20),
                            BotonDegradado(
                              key: const ValueKey('boton-crear-cuenta'),
                              texto: 'Crear cuenta',
                              cargando: _cargando,
                              onPressed: _crear,
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
                          '¿Ya tienes cuenta?',
                          style: TextStyle(color: colores.onSurfaceVariant),
                        ),
                        TextButton(
                          key: const ValueKey('ir-a-iniciar-sesion'),
                          onPressed: _cargando
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Iniciar sesión',
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
