import 'package:flutter/material.dart';

import '../constantes.dart';
import '../cuenta/servicio_cuenta.dart';
import '../lector_mapas.dart';

// Pantalla de la cuenta del jugador: su nombre, su historial de partidas en
// linea, cerrar sesion y borrar la cuenta (pide la contraseña para
// confirmar).
class PantallaCuenta extends StatefulWidget {
  final ServicioDeCuenta servicio;
  // Se llama cuando el jugador ya no tiene sesion (la cerro o borro su
  // cuenta), para volver a iniciar sesion.
  final VoidCallback onSalir;

  const PantallaCuenta({
    super.key,
    required this.servicio,
    required this.onSalir,
  });

  @override
  State<PantallaCuenta> createState() => _PantallaCuentaState();
}

class _PantallaCuentaState extends State<PantallaCuenta> {
  // El historial se pide una vez al abrir la pantalla.
  late final Future<HistorialDeCuenta> _historial = widget.servicio.historial();

  void _cerrarSesion() {
    widget.servicio.cerrarSesion();
    widget.onSalir();
  }

  Future<void> _borrarCuenta() async {
    final borrada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoBorrarCuenta(servicio: widget.servicio),
    );
    if (borrada ?? false) {
      widget.onSalir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      key: const ValueKey('pantalla-cuenta'),
      backgroundColor: tema.colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        centerTitle: true,
        backgroundColor: tema.colorScheme.surfaceContainerLow,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 36,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.servicio.usuario ?? '',
                    key: const ValueKey('nombre-usuario'),
                    textAlign: TextAlign.center,
                    style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<HistorialDeCuenta>(
                      future: _historial,
                      builder: (context, carga) {
                        final historial = carga.data;
                        if (historial != null) {
                          return _Historial(historial: historial);
                        }
                        return Center(
                          child: carga.hasError
                              ? Text(
                                  'No se pudo cargar tu historial.',
                                  style: TextStyle(
                                    color: tema.colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : const CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      key: const ValueKey('boton-cerrar-sesion'),
                      onPressed: _cerrarSesion,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: TextButton.icon(
                      key: const ValueKey('boton-borrar-cuenta'),
                      style: TextButton.styleFrom(
                        foregroundColor: tema.colorScheme.error,
                      ),
                      onPressed: _borrarCuenta,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Borrar cuenta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Las estadisticas del jugador y la lista de sus ultimas partidas.
class _Historial extends StatelessWidget {
  final HistorialDeCuenta historial;

  const _Historial({required this.historial});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final porcentaje = historial.jugadas == 0
        ? 0
        : (historial.ganadas * 100 / historial.jugadas).round();

    return Column(
      key: const ValueKey('historial'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  itemBuilder: (context, indice) =>
                      _PartidaDelHistorial(partida: historial.partidas[indice]),
                ),
        ),
      ],
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

  const _PartidaDelHistorial({required this.partida});

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
                Expanded(child: Text(jugador.usuario)),
                Text(
                  '${jugador.puntos} pts',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Confirma el borrado de la cuenta pidiendo la contraseña. Devuelve true si
// la cuenta se borro.
class _DialogoBorrarCuenta extends StatefulWidget {
  final ServicioDeCuenta servicio;

  const _DialogoBorrarCuenta({required this.servicio});

  @override
  State<_DialogoBorrarCuenta> createState() => _DialogoBorrarCuentaState();
}

class _DialogoBorrarCuentaState extends State<_DialogoBorrarCuenta> {
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _borrar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await widget.servicio.borrarCuenta(_contrasena.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ErrorDeCuenta catch (error) {
      if (mounted) {
        setState(() {
          _error = error.mensaje;
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return AlertDialog(
      key: const ValueKey('dialogo-borrar-cuenta'),
      title: const Text('¿Borrar tu cuenta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esto no se puede deshacer. Escribe tu contraseña para confirmar.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('campo-contrasena-borrar'),
            controller: _contrasena,
            enabled: !_cargando,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _borrar(),
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('mensaje-error'),
              style: TextStyle(color: colores.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cargando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('confirmar-borrar-cuenta'),
          style: FilledButton.styleFrom(
            backgroundColor: colores.error,
            foregroundColor: colores.onError,
          ),
          onPressed: _cargando ? null : _borrar,
          child: const Text('Borrar cuenta'),
        ),
      ],
    );
  }
}
