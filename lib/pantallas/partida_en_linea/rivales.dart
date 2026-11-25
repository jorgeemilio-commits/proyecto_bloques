// Tableros de los rivales en la partida en linea.

import 'package:flutter/material.dart';

import '../../constantes.dart';
import '../../mapa.dart';
import '../../multijugador/servicio_sala.dart';
import '../../region.dart';
import '../../tablero.dart';
import '../../widgets/tablero_widget.dart';

// Tablero de un jugador como lo manda el servidor: sus valores iniciales y
// los numeros que coloco. No se puede tocar.
Tablero tableroDeJugador(Mapa mapa, JugadorEnSala? jugador) {
  final tablero = mapa.crearTablero();
  final iniciales = jugador?.iniciales;
  for (var i = 0; i < tablero.celdasIniciales.length; i++) {
    final celda = tablero.celdasIniciales[i];
    celda.esInsertable = false;
    if (iniciales != null && i < iniciales.length) {
      celda.numero = iniciales[i];
    }
  }
  for (final (x, y, numero) in jugador?.casillas ?? const <(int, int, int)>[]) {
    if (x < tablero.columnas && y < tablero.filas) {
      tablero.obtenerCelda(Coordenada(x, y)).numero = numero;
    }
  }
  return tablero;
}

// Tira con el tablero en miniatura de cada rival, sus puntos y su
// situacion. Al tocar uno se ve en grande.
class RivalesDePartida extends StatelessWidget {
  final EstadoSala estado;
  final Mapa mapa;

  const RivalesDePartida({required this.estado, required this.mapa});

  @override
  Widget build(BuildContext context) {
    final rivales = [
      for (final jugador in estado.jugadores)
        if (jugador.usuario != estado.usuario) jugador,
    ];

    return SizedBox(
      height: 118,
      child: ListView.separated(
        key: const ValueKey('rivales'),
        scrollDirection: Axis.horizontal,
        itemCount: rivales.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, indice) =>
            _Rival(jugador: rivales[indice], estado: estado, mapa: mapa),
      ),
    );
  }
}

class _Rival extends StatelessWidget {
  final JugadorEnSala jugador;
  final EstadoSala estado;
  final Mapa mapa;

  const _Rival({
    required this.jugador,
    required this.estado,
    required this.mapa,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colores = tema.colorScheme;
    final ganador = estado.ganadores.contains(jugador.usuario);

    // Que esta haciendo: ganador, en la meta, rendido, desconectado o si ya
    // jugo esta ronda.
    final (IconData icono, Color color) = ganador
        ? (Icons.emoji_events, Colors.amber)
        : !jugador.jugando
        ? (
            jugador.situacion == 'rendido' ? Icons.flag : Icons.check_circle,
            jugador.situacion == 'rendido' ? colores.error : naranjaLogo,
          )
        : !jugador.conectado
        ? (Icons.wifi_off, colores.error)
        : jugador.yaJugo
        ? (Icons.check, colores.primary)
        : (Icons.hourglass_empty, colores.onSurfaceVariant);

    return InkWell(
      key: ValueKey('rival-${jugador.usuario}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _verEnGrande(context),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colores.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: Opacity(
                opacity: jugador.situacion == 'rendido' ? 0.4 : 1,
                child: IgnorePointer(
                  child: TableroWidget(
                    tablero: tableroDeJugador(mapa, jugador),
                    vecesReclamada: (region) => estado.reclamos[region.id] ?? 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icono, size: 13, color: color),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    jugador.usuario,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.labelSmall,
                  ),
                ),
                Text(
                  '${jugador.puntos}',
                  style: tema.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _verEnGrande(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('${jugador.usuario} · ${jugador.puntos} pts'),
        content: SizedBox(
          width: 320,
          child: IgnorePointer(
            child: TableroWidget(
              tablero: tableroDeJugador(mapa, jugador),
              vecesReclamada: (region) => estado.reclamos[region.id] ?? 0,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
