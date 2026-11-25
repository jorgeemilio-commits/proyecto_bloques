// Sala de espera: los jugadores, su Elo, el boton de Listo y la barra de abajo.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../juego/constantes.dart';
import '../../multijugador/servicio_sala.dart';
import 'opciones_sala.dart';

// Sala de espera: el codigo, los jugadores, el mapa y el boton para iniciar.
class SalaDeEspera extends StatelessWidget {
  final ServicioDeSala sala;
  final EstadoSala estado;

  const SalaDeEspera({required this.sala, required this.estado});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final codigo = estado.codigo ?? '';

    return Column(
      key: const ValueKey('sala-de-espera'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Código de la sala',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              codigo,
              key: const ValueKey('codigo-sala'),
              style: tema.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
              ),
            ),
            IconButton(
              tooltip: 'Copiar código',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codigo));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Código copiado.')),
                  );
              },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Jugadores (${estado.jugadores.length}/${estado.maximo})',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: tema.colorScheme.surface,
          child: Column(
            children: [
              for (final jugador in estado.jugadores)
                ListTile(
                  key: ValueKey('jugador-${jugador.usuario}'),
                  leading: Icon(
                    Icons.person,
                    color: jugador.conectado
                        ? tema.colorScheme.primary
                        : tema.colorScheme.outline,
                  ),
                  title: Text(
                    jugador.usuario == estado.usuario
                        ? '${jugador.usuario} (tú)'
                        : jugador.usuario,
                  ),
                  // Su Elo y, si se cayo, que se le espera.
                  subtitle: jugador.elo == null && jugador.conectado
                      ? null
                      : Text(
                          [
                            if (jugador.elo != null) 'Elo ${jugador.elo}',
                            if (!jugador.conectado)
                              'Desconectado, esperando que vuelva…',
                          ].join(' · '),
                          key: ValueKey('elo-${jugador.usuario}'),
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (jugador.usuario == estado.anfitrion) ...[
                        const Chip(label: Text('Anfitrión')),
                        const SizedBox(width: 6),
                      ],
                      // Si ya marco que esta listo.
                      Tooltip(
                        message: jugador.listo ? 'Listo' : 'No está listo',
                        child: Icon(
                          jugador.listo
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          key: ValueKey('listo-${jugador.usuario}'),
                          color: jugador.listo
                              ? Colors.green
                              : tema.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Mapa', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        MapaDeLaSala(
          mapa: estado.mapa ?? 'clasico',
          // Solo el anfitrion lo cambia; los demas solo lo ven.
          onElegir: estado.soyAnfitrion ? sala.elegirMapa : null,
        ),
        const SizedBox(height: 20),
        Text('Tiempo por ronda', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        TiempoPorRonda(
          segundos: estado.segundosPorRonda,
          // Solo el anfitrion lo cambia; los demas solo lo ven.
          onElegir: estado.soyAnfitrion ? sala.elegirTiempo : null,
        ),
        const SizedBox(height: 28),
        // La unica forma de salir de la sala: el anfitrion la borra (salen
        // todos) y los demas solo salen ellos.
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const ValueKey('boton-salir-sala'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tema.colorScheme.error,
              side: BorderSide(color: tema.colorScheme.error),
            ),
            onPressed: sala.salir,
            icon: Icon(
              estado.soyAnfitrion ? Icons.delete_outline : Icons.logout,
            ),
            label: Text(
              estado.soyAnfitrion ? 'Borrar sala' : 'Salir de la sala',
            ),
          ),
        ),
      ],
    );
  }
}

// Barra fija abajo de la sala de espera, para que siempre se vean: el boton
// de "Listo" y, para el anfitrion, el de iniciar (los demas ven que se espera
// al anfitrion). Lo demas de la sala hace scroll por encima.
class BarraDeLaSala extends StatelessWidget {
  final ServicioDeSala sala;
  final EstadoSala estado;

  const BarraDeLaSala({required this.sala, required this.estado});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hayJugadores = estado.jugadores.length >= 2;
    // Para iniciar hacen falta 2 jugadores o mas y que todos esten listos.
    final puedeIniciar = hayJugadores && estado.todosListos;
    final estoyListo = estado.yo?.listo ?? false;

    return DecoratedBox(
      key: const ValueKey('barra-sala'),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerLow,
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cada jugador (tambien el anfitrion) marca que esta listo.
                SizedBox(
                  height: 52,
                  child: estoyListo
                      ? OutlinedButton.icon(
                          key: const ValueKey('boton-listo-sala'),
                          onPressed: () => sala.marcarListo(false),
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          label: const Text('Listo · toca para cancelar'),
                        )
                      : FilledButton.tonalIcon(
                          key: const ValueKey('boton-listo-sala'),
                          onPressed: () => sala.marcarListo(true),
                          icon: const Icon(Icons.check),
                          label: const Text('Estoy listo'),
                        ),
                ),
                const SizedBox(height: 12),
                if (estado.soyAnfitrion)
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      key: const ValueKey('boton-iniciar'),
                      onPressed: puedeIniciar ? sala.iniciar : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        puedeIniciar
                            ? 'Iniciar partida'
                            : !hayJugadores
                            ? 'Esperando jugadores…'
                            : 'Esperando que todos estén listos…',
                      ),
                    ),
                  )
                else
                  Text(
                    'Esperando a que el anfitrión inicie la partida…',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
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
