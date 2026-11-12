import 'package:flutter/material.dart';

import '../constantes.dart';
import '../cuenta/servicio_cuenta.dart';
import '../lector_mapas.dart';
import '../mapa.dart';
import '../region.dart';
import '../widgets/celda_widget.dart';
import '../widgets/fondo_dados_widget.dart';
import '../multijugador/servicio_sala.dart';
import 'cuenta.dart';
import 'multijugador.dart';
import 'seleccion_mapa.dart';

// Pantalla despues de iniciar sesion: el saludo y el boton de la cuenta, un
// tablero pequeño de adorno, el logo, el lema con lo que ofrece el juego y los
// botones para jugar en linea u offline.
class MenuPrincipal extends StatelessWidget {
  final ServicioDeCuenta servicio;

  const MenuPrincipal({super.key, required this.servicio});

  void _abrirCuenta(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaCuenta(
          servicio: servicio,
          // Al salir de la cuenta se quita esta pantalla; debajo ya esta el
          // inicio de sesion porque el servicio aviso que no hay sesion.
          onSalir: () => Navigator.of(context).popUntil((ruta) => ruta.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      key: const ValueKey('menu-principal'),
      backgroundColor: tema.colorScheme.surfaceContainerLow,
      // Dados bajando despacio detras de todo.
      body: FondoDeDados(
        child: DecoratedBox(
          // Resplandor suave con los colores del logo detras del titulo.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 0.9,
              colors: [
                rosaLogo.withValues(alpha: 0.18),
                naranjaLogo.withValues(alpha: 0.06),
                Colors.transparent,
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: anchoMaximoTelefono,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    children: [
                      // Saludo con el nombre del jugador y el boton de la cuenta.
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Hola, ${servicio.usuario ?? 'jugador'}!',
                                  key: const ValueKey('saludo'),
                                  overflow: TextOverflow.ellipsis,
                                  style: tema.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '¿Listo para tu próxima partida?',
                                  style: tema.textTheme.bodySmall?.copyWith(
                                    color: tema.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            key: const ValueKey('boton-cuenta'),
                            tooltip: 'Mi cuenta',
                            onPressed: () => _abrirCuenta(context),
                            icon: const Icon(Icons.person),
                          ),
                        ],
                      ),
                      // El tablero, el logo y el lema ocupan el espacio libre y
                      // se encogen si no caben (pantallas bajitas).
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              children: [
                                // Entrada animada: el tablero baja y aparece, y
                                // el logo crece hasta su tamaño.
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, entrada, _) => Column(
                                    children: [
                                      Opacity(
                                        opacity: entrada,
                                        child: Transform.translate(
                                          offset: Offset(
                                            0,
                                            -24 * (1 - entrada),
                                          ),
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
                                const SizedBox(height: 16),
                                // Ancho fijo para que el texto se acomode en
                                // varias lineas dentro del FittedBox.
                                SizedBox(
                                  width: 330,
                                  child: Column(
                                    children: [
                                      Text(
                                        'Tira, coloca y reclama.',
                                        textAlign: TextAlign.center,
                                        style: tema.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Usa los dados para llenar cada región '
                                        'antes que tus rivales, roba los mejores '
                                        'premios y sé el primero en llegar a la '
                                        'meta.',
                                        textAlign: TextAlign.center,
                                        style: tema.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: tema
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // "Jugar" es en linea, con otros jugadores.
                      _BotonJugar(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PantallaMultijugador(
                              sala: ServicioDeSala(cuenta: servicio),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          key: const ValueKey('boton-jugar-offline'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SeleccionMapa(),
                            ),
                          ),
                          icon: const Icon(Icons.wifi_off_rounded),
                          label: const Text('Jugar offline'),
                        ),
                      ),
                    ],
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
              color: rosaLogo.withValues(alpha: 0.25),
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
    final colorDeTexto = region == null
        ? Colors.white
        : colorDeTextoPara(region.tipo);

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
            CustomPaint(
              painter: PintorDeRayas(color: colorDeTexto),
              child: const SizedBox.expand(),
            ),
          if (esInicial)
            Center(
              child: Icon(
                Icons.star_rounded,
                size: 14,
                color: colorDeTexto.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

// Boton grande con el degradado del logo: "Jugar" en linea.
class _BotonJugar extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotonJugar({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(18);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borde,
        gradient: const LinearGradient(colors: [naranjaLogo, rosaLogo]),
        boxShadow: [
          BoxShadow(
            color: rosaLogo.withValues(alpha: 0.4),
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
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                SizedBox(width: 8),
                // Flexible: si no cabe, el texto se corta en lugar de
                // desbordarse.
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jugar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Crea una sala o únete con un código',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
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
