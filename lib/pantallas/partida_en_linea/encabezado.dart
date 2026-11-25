// Encabezado de la partida en linea: la fase, el tiempo y los puntos.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../configuracion.dart';
import '../../mapa.dart';
import '../../multijugador/servicio_sala.dart';

// Arriba: la fase, el tiempo que queda, mis puntos y la meta, y el aviso de
// la region que complete en la ronda anterior.
class EncabezadoDePartida extends StatelessWidget {
  final EstadoSala estado;
  final Mapa mapa;

  const EncabezadoDePartida({required this.estado, required this.mapa});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yo = estado.yo;
    final reclamo = yo?.ultimoReclamo;
    final titulo = switch (estado.fase) {
      'valoresIniciales' => 'Valores iniciales',
      'terminada' => 'Partida terminada',
      _ => 'Ronda ${estado.ronda}',
    };

    String? aviso;
    if (reclamo != null) {
      final region = mapa.regiones
          .where((region) => region.id == reclamo.region)
          .firstOrNull;
      final nombre = region?.tipo.nombre ?? reclamo.region;
      aviso = reclamo.puntos > 0
          ? '¡Completaste una región $nombre! +${reclamo.puntos} puntos.'
          : 'Completaste una región $nombre, pero ya no da puntos.';
    } else if (estado.fase == 'valoresIniciales' && yo?.iniciales == null) {
      aviso = 'Pon tus seis valores iniciales (1 a 6, sin repetir).';
    } else if (estado.fase == 'ronda' && (yo?.jugando ?? false)) {
      aviso = Configuracion.modoDeControl.value == ModoDeControl.tocarAncla
          ? 'Toca el dado ancla y luego la casilla donde va el otro, o pasa.'
          : 'Arrastra un dado junto al número del otro dado, o pasa.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                titulo,
                key: const ValueKey('titulo-fase'),
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (estado.limite != null) ...[
              _CuentaRegresiva(limite: estado.limite!),
              const SizedBox(width: 12),
            ],
            Text(
              '${yo?.puntos ?? 0}/${estado.meta ?? '?'} pts',
              key: const ValueKey('marcador'),
              style: tema.textTheme.titleMedium?.copyWith(
                color: tema.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (aviso != null) ...[
          const SizedBox(height: 4),
          Text(
            aviso,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: reclamo != null
                  ? Colors.amber.shade300
                  : tema.colorScheme.onSurfaceVariant,
              fontWeight: reclamo != null ? FontWeight.w600 : null,
            ),
          ),
        ],
      ],
    );
  }
}

// Segundos que faltan; se pone roja en los ultimos 10.
class _CuentaRegresiva extends StatefulWidget {
  final DateTime limite;

  const _CuentaRegresiva({required this.limite});

  @override
  State<_CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<_CuentaRegresiva> {
  late final Timer _reloj = Timer.periodic(
    const Duration(milliseconds: 250),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _reloj;
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final restante = widget.limite.difference(DateTime.now());
    final segundos = restante.isNegative
        ? 0
        : (restante.inMilliseconds / 1000).ceil();
    final urgente = segundos <= 10;

    return Row(
      key: const ValueKey('cuenta-regresiva'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 18,
          color: urgente ? colores.error : colores.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          '${segundos}s',
          style: TextStyle(
            color: urgente ? colores.error : colores.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
