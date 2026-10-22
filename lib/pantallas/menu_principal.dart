import 'package:flutter/material.dart';

import '../constantes.dart';
import '../lector_mapas.dart';
import '../mapa.dart';
import '../region.dart';
import '../widgets/celda_widget.dart';
import 'seleccion_mapa.dart';

// Colores del logo, usados en el fondo y en el boton Jugar.
const Color _naranjaLogo = Color(0xFFF7A21B);
const Color _rosaLogo = Color(0xFFE8197D);

// Primera pantalla de la app: un tablero pequeño de adorno, el logo y el
// boton para jugar.
class MenuPrincipal extends StatelessWidget {
  const MenuPrincipal({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      key: const ValueKey('menu-principal'),
      backgroundColor: tema.colorScheme.surfaceContainerLow,
      body: DecoratedBox(
        // Resplandor suave con los colores del logo detras del titulo.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 0.9,
            colors: [
              _rosaLogo.withValues(alpha: 0.18),
              _naranjaLogo.withValues(alpha: 0.06),
              Colors.transparent,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Entrada animada: el tablero baja y aparece, y el logo
                    // crece hasta su tamaño.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, entrada, _) => Column(
                        children: [
                          Opacity(
                            opacity: entrada,
                            child: Transform.translate(
                              offset: Offset(0, -24 * (1 - entrada)),
                              child: const _TableroDeAdorno(),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Opacity(
                            opacity: entrada,
                            child: Transform.scale(
                              scale: 0.85 + 0.15 * entrada,
                              child: Image.asset(
                                'assets/imagenes/brilliant_logo_3x.png',
                                key: const ValueKey('logo'),
                                width: 300,
                                semanticLabel: 'Brilliant',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Llena las regiones con los dados',
                      style: tema.textTheme.bodyLarge?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(flex: 3),
                    _BotonJugar(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SeleccionMapa(),
                        ),
                      ),
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

// Tablero pequeño con el mapa clasico, inclinado como el logo. Solo adorna.
class _TableroDeAdorno extends StatefulWidget {
  const _TableroDeAdorno();

  @override
  State<_TableroDeAdorno> createState() => _TableroDeAdornoState();
}

class _TableroDeAdornoState extends State<_TableroDeAdorno> {
  static const double _casilla = 24;
  static const double _espacio = 3;
  // Tamaño del tablero de 7x7 con su marco, para reservar el espacio mientras
  // se lee el mapa y que el logo no salte.
  static const double _tamanoReservado = 7 * _casilla + 6 * _espacio + 16;

  // El mapa se lee del archivo una sola vez.
  late final Future<Mapa> _mapa = cargarMapa(rutaMapaClasico);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Mapa>(
      future: _mapa,
      builder: (context, carga) {
        final mapa = carga.data;
        return mapa == null
            ? const SizedBox.square(dimension: _tamanoReservado)
            : _dibujar(context, mapa);
      },
    );
  }

  Widget _dibujar(BuildContext context, Mapa mapa) {
    final tablero = mapa.crearTablero();
    final iniciales = mapa.coordenadasIniciales;

    return Transform.rotate(
      angle: -0.12,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _rosaLogo.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var y = 0; y < tablero.filas; y++)
              Padding(
                padding: EdgeInsets.only(top: y == 0 ? 0 : _espacio),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var x = 0; x < tablero.columnas; x++)
                      Padding(
                        padding: EdgeInsets.only(left: x == 0 ? 0 : _espacio),
                        child: _casillaDeAdorno(
                          tablero.obtenerRegion(Coordenada(x, y)),
                          esInicial: iniciales.any((c) => c.x == x && c.y == y),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _casillaDeAdorno(Region? region, {required bool esInicial}) {
    return Container(
      width: _casilla,
      height: _casilla,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: region == null
            ? Colors.grey.shade800
            : colorDeRegion(region.tipo),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Stack(
        children: [
          if (region?.conRayas ?? false)
            const CustomPaint(
              painter: PintorDeRayas(),
              child: SizedBox.expand(),
            ),
          if (esInicial)
            const Center(
              child: Icon(Icons.star_rounded, size: 14, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

// Boton grande con el degradado del logo.
class _BotonJugar extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotonJugar({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(18);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borde,
        gradient: const LinearGradient(colors: [_naranjaLogo, _rosaLogo]),
        boxShadow: [
          BoxShadow(
            color: _rosaLogo.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borde,
        child: InkWell(
          key: const ValueKey('boton-jugar'),
          borderRadius: borde,
          onTap: onPressed,
          child: const SizedBox(
            width: double.infinity,
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                SizedBox(width: 6),
                Text(
                  'Jugar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
