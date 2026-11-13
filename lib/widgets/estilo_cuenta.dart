import 'package:flutter/material.dart';

import '../constantes.dart';
import 'fondo_animado_widget.dart';

// Piezas con el estilo de las pantallas de iniciar sesion y crear cuenta.

// Fondo de iniciar sesion y crear cuenta: la imagen del login bajando
// despacio, con el resplandor de los colores del logo encima, como en el menu.
class FondoDelLogo extends StatelessWidget {
  final Widget child;

  const FondoDelLogo({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FondoAnimado(imagen: fondoLogin, child: _resplandor(child));
  }

  Widget _resplandor(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1,
          colors: [
            rosaLogo.withValues(alpha: 0.2),
            naranjaLogo.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: child,
    );
  }
}

// Estilo de los campos de texto: rellenos y redondeados, con un icono.
InputDecoration decoracionDeCampo(
  String etiqueta,
  IconData icono, {
  String? ayuda,
}) => InputDecoration(
  labelText: etiqueta,
  helperText: ayuda,
  helperMaxLines: 2,
  prefixIcon: Icon(icono),
  filled: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
);

// Boton para mostrar u ocultar una contraseña (el "ojito" del campo).
class BotonVerContrasena extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;

  const BotonVerContrasena({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
      onPressed: onPressed,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }
}

// Recuadro rojo con un icono para los errores del formulario.
class RecuadroDeError extends StatelessWidget {
  final String mensaje;

  const RecuadroDeError({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colores.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              key: const ValueKey('mensaje-error'),
              style: TextStyle(color: colores.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// Boton principal con el degradado del logo, como el boton Jugar del menu.
// Mientras [cargando] muestra un circulo y no se puede presionar.
class BotonDegradado extends StatelessWidget {
  final String texto;
  final bool cargando;
  final VoidCallback onPressed;

  const BotonDegradado({
    super.key,
    required this.texto,
    required this.cargando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(16);

    return Opacity(
      opacity: cargando ? 0.7 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borde,
          gradient: const LinearGradient(colors: [naranjaLogo, rosaLogo]),
          boxShadow: [
            BoxShadow(
              color: rosaLogo.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borde,
          child: InkWell(
            borderRadius: borde,
            onTap: cargando ? null : onPressed,
            child: SizedBox(
              height: 54,
              child: Center(
                child: cargando
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        texto,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
