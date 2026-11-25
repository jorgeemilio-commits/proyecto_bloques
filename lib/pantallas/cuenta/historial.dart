// Historial de la cuenta: el Elo, las estadisticas y las ultimas partidas.

import 'package:flutter/material.dart';

import '../../cuenta/servicio_cuenta.dart';
import '../../juego/constantes.dart';
import '../../juego/lector_mapas.dart';
import '../../widgets/elo_widget.dart';

// Las estadisticas del jugador y la lista de sus ultimas partidas.
class HistorialDelJugador extends StatelessWidget {
  final HistorialDeCuenta historial;
  // Para encontrar mi cambio de Elo en la ultima partida.
  final String? usuario;

  const HistorialDelJugador({required this.historial, this.usuario});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final porcentaje = historial.jugadas == 0
        ? 0
        : (historial.ganadas * 100 / historial.jugadas).round();

    // Cuanto cambio mi Elo en la ultima partida (la primera de la lista).
    final ultima = historial.partidas.isEmpty
        ? null
        : historial.partidas.first.jugadores
              .where((jugador) => jugador.usuario == usuario)
              .firstOrNull;

    return Column(
      key: const ValueKey('historial'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TarjetaDeElo(elo: historial.elo, ultimoCambio: ultima?.cambioElo),
        const SizedBox(height: 8),
        Row(
          children: [
            _Estadistica(
              llave: 'partidas-jugadas',
              valor: '${historial.jugadas}',
              texto: 'Jugadas',
            ),
            const SizedBox(width: 8),
            _Estadistica(
              llave: 'partidas-ganadas',
              valor: '${historial.ganadas}',
              texto: 'Ganadas',
            ),
            const SizedBox(width: 8),
            _Estadistica(
              llave: 'porcentaje-victorias',
              valor: '$porcentaje%',
              texto: 'Victorias',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Tus últimas partidas', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: historial.partidas.isEmpty
              ? Center(
                  child: Text(
                    'Todavía no juegas partidas en línea.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: historial.partidas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, indice) => _PartidaDelHistorial(
                    partida: historial.partidas[indice],
                    usuario: usuario,
                  ),
                ),
        ),
      ],
    );
  }
}

// Mi Elo en grande, y cuanto cambio en la ultima partida.
class _TarjetaDeElo extends StatelessWidget {
  final int elo;
  final int? ultimoCambio;

  const _TarjetaDeElo({required this.elo, this.ultimoCambio});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      key: const ValueKey('tarjeta-elo'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            naranjaLogo.withValues(alpha: 0.25),
            rosaLogo.withValues(alpha: 0.25),
          ],
        ),
        border: Border.all(color: naranjaLogo.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.military_tech_rounded, color: naranjaLogo, size: 32),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elo',
                style: tema.textTheme.labelLarge?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$elo',
                key: const ValueKey('elo'),
                style: tema.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (ultimoCambio != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CambioDeElo(
                  key: const ValueKey('ultimo-cambio-elo'),
                  cambio: ultimoCambio!,
                  estilo: tema.textTheme.titleLarge,
                ),
                Text(
                  'última partida',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Estadistica extends StatelessWidget {
  final String llave;
  final String valor;
  final String texto;

  const _Estadistica({
    required this.llave,
    required this.valor,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              valor,
              key: ValueKey(llave),
              style: tema.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: naranjaLogo,
              ),
            ),
            Text(
              texto,
              style: tema.textTheme.labelMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Una partida del historial: el mapa, la meta, las rondas, la fecha y los
// puntos de todos (el ganador con un trofeo).
class _PartidaDelHistorial extends StatelessWidget {
  final PartidaJugada partida;
  // Mi fila se marca en negritas.
  final String? usuario;

  const _PartidaDelHistorial({required this.partida, this.usuario});

  static String _dosDigitos(int numero) => numero.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final fecha = partida.terminada;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colores.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${nombreDeMapa(partida.mapa)} · meta ${partida.meta} · '
            '${partida.rondas} rondas · '
            '${fecha.day}/${fecha.month}/${fecha.year} '
            '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}',
            style: tema.textTheme.labelMedium?.copyWith(
              color: colores.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          for (final jugador in partida.jugadores)
            Row(
              children: [
                Icon(
                  jugador.gano
                      ? Icons.emoji_events
                      : jugador.situacion == 'rendido'
                      ? Icons.flag
                      : Icons.person,
                  size: 16,
                  color: jugador.gano ? Colors.amber : colores.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    jugador.usuario,
                    style: jugador.usuario == usuario
                        ? const TextStyle(fontWeight: FontWeight.w700)
                        : null,
                  ),
                ),
                Text(
                  '${jugador.puntos} pts',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                // Cuanto cambio su Elo en esa partida.
                SizedBox(
                  width: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: CambioDeElo(cambio: jugador.cambioElo),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
