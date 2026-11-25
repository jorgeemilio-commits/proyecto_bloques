// Resultados de la partida en linea y el cambio de Elo.

import 'package:flutter/material.dart';

import '../../juego/constantes.dart';
import '../../multijugador/servicio_sala.dart';
import '../../widgets/elo_widget.dart';
import '../../widgets/estilo_cuenta.dart';

// Al terminar: los ganadores y la tabla de puntos.
//
// Tambien sale cuando la partida se acabo solo para mi (me rendi o llegue a
// la meta) mientras los demas siguen: entonces lo dice, y arriba se siguen
// viendo los tableros de los demas, que se actualizan cada ronda.
class ResultadosDePartida extends StatelessWidget {
  final EstadoSala estado;

  const ResultadosDePartida({required this.estado});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gane = estado.ganadores.contains(estado.usuario);
    final termino = estado.fase == 'terminada';
    final situacion = estado.yo?.situacion;
    final tabla = [...estado.jugadores]
      ..sort((a, b) => b.puntos.compareTo(a.puntos));

    return Column(
      key: const ValueKey('resultados'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          gane
              ? '¡Ganaste!'
              : situacion == 'rendido'
              ? 'Te rendiste'
              : !termino
              ? 'Llegaste a la meta'
              : estado.ganadores.isEmpty
              ? 'Nadie ganó'
              : 'Ganó ${estado.ganadores.join(' y ')}',
          key: const ValueKey('titulo-resultados'),
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: gane ? naranjaLogo : null,
          ),
        ),
        // Al terminar: cuanto cambio mi Elo, con una animacion.
        if (estado.yo?.cambioElo case final cambio?)
          _CambioDeEloAnimado(cambio: cambio),
        if (!termino)
          Text(
            'Los demás siguen jugando: arriba puedes ver sus tableros.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        // La tabla hace scroll si son muchos; el boton queda fijo abajo.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final jugador in tabla)
                  Row(
                    children: [
                      Icon(
                        estado.ganadores.contains(jugador.usuario)
                            ? Icons.emoji_events
                            : jugador.situacion == 'rendido'
                            ? Icons.flag
                            : Icons.person,
                        size: 18,
                        color: estado.ganadores.contains(jugador.usuario)
                            ? Colors.amber
                            : tema.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(jugador.usuario)),
                      Text(
                        '${jugador.puntos} pts',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      // Cuanto cambio su Elo (al terminar la partida).
                      if (jugador.cambioElo case final cambio?)
                        SizedBox(
                          width: 44,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: CambioDeElo(cambio: cambio),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Grande y con el degradado del logo, como "Jugar" en el menu.
        BotonDegradado(
          key: const ValueKey('boton-volver-menu'),
          texto: termino ? 'Volver al menú' : 'Salir de la partida',
          cargando: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

// Mi cambio de Elo al terminar: aparece creciendo y el numero cuenta desde 0
// hasta el cambio ("+25 Elo" en verde o "−15 Elo" en rojo).
class _CambioDeEloAnimado extends StatelessWidget {
  final int cambio;

  const _CambioDeEloAnimado({required this.cambio});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return TweenAnimationBuilder<double>(
      key: const ValueKey('cambio-elo-resultados'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutBack,
      builder: (context, avance, _) => Transform.scale(
        scale: 0.6 + 0.4 * avance.clamp(0, 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CambioDeElo(
              cambio: (cambio * avance.clamp(0, 1)).round(),
              estilo: tema.textTheme.headlineSmall,
            ),
            const SizedBox(width: 6),
            Text(
              'Elo',
              style: tema.textTheme.titleMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
