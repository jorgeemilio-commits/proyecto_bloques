import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constantes.dart';
import '../lector_mapas.dart';
import '../multijugador/servicio_sala.dart';

// Pantalla para jugar en linea. Se conecta al servidor al abrirse y muestra,
// segun el estado: entrar a una sala (crear o unirse con codigo), la sala de
// espera, o la partida. Al cerrarla sale de la sala y se desconecta.
class PantallaMultijugador extends StatefulWidget {
  // La pantalla es duena del servicio: lo cierra al salir.
  final ServicioDeSala sala;

  const PantallaMultijugador({super.key, required this.sala});

  @override
  State<PantallaMultijugador> createState() => _PantallaMultijugadorState();
}

class _PantallaMultijugadorState extends State<PantallaMultijugador> {
  late final StreamSubscription<String> _avisos;

  @override
  void initState() {
    super.initState();
    // Los avisos y errores se muestran abajo un momento.
    _avisos = widget.sala.avisos.listen((texto) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(texto)));
    });
    widget.sala.conectar();
  }

  @override
  void dispose() {
    _avisos.cancel();
    // Salir de la sala a proposito, para que los demas no esperen los 80
    // segundos de reconexion.
    if (widget.sala.estado?.fase == 'lobby') {
      widget.sala.salir();
    }
    widget.sala.desconectar();
    widget.sala.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('pantalla-multijugador'),
      backgroundColor: colores.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Multijugador'),
        centerTitle: true,
        backgroundColor: colores.surfaceContainerLow,
      ),
      body: ListenableBuilder(
        listenable: widget.sala,
        builder: (context, _) {
          final sala = widget.sala;
          final estado = sala.estado;

          final Widget contenido;
          if (estado == null) {
            contenido = sala.conexion == EstadoConexion.desconectado
                ? _SinConexion(onReintentar: sala.conectar)
                : const _Conectando();
          } else if (estado.fase == 'sinSala') {
            contenido = _Entrada(sala: sala);
          } else if (estado.fase == 'lobby') {
            contenido = _SalaDeEspera(sala: sala, estado: estado);
          } else {
            contenido = _PartidaPendiente(estado: estado);
          }

          return SafeArea(
            child: Column(
              children: [
                if (sala.conexion == EstadoConexion.reconectando)
                  const _BarraReconectando(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: anchoMaximoTelefono,
                        ),
                        child: contenido,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Conectando extends StatelessWidget {
  const _Conectando();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Conectando con el servidor…'),
      ],
    );
  }
}

class _SinConexion extends StatelessWidget {
  final VoidCallback onReintentar;

  const _SinConexion({required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      key: const ValueKey('sin-conexion'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off, size: 56, color: tema.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'No hay conexión con el servidor.',
          textAlign: TextAlign.center,
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('boton-reintentar'),
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}

class _BarraReconectando extends StatelessWidget {
  const _BarraReconectando();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('barra-reconectando'),
      width: double.infinity,
      color: colores.errorContainer,
      child: Column(
        children: [
          const LinearProgressIndicator(minHeight: 3),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Se perdió la conexión. Reconectando…',
              textAlign: TextAlign.center,
              style: TextStyle(color: colores.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// Crear una sala nueva o unirse a una con su codigo.
class _Entrada extends StatefulWidget {
  final ServicioDeSala sala;

  const _Entrada({required this.sala});

  @override
  State<_Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<_Entrada> {
  final _codigo = TextEditingController();

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _unirse() {
    final codigo = _codigo.text.trim();
    if (codigo.isNotEmpty) {
      widget.sala.unirse(codigo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      key: const ValueKey('entrada-sala'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Juega con tus amigos',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Crea una sala y comparte el código, o únete con el código de '
          'un amigo.',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('boton-crear-sala'),
            onPressed: widget.sala.crearSala,
            icon: const Icon(Icons.add),
            label: const Text('Crear sala'),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o',
                style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('campo-codigo'),
          controller: _codigo,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: tema.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
          onSubmitted: (_) => _unirse(),
          decoration: const InputDecoration(
            labelText: 'Código de la sala',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            key: const ValueKey('boton-unirse'),
            onPressed: _unirse,
            icon: const Icon(Icons.login),
            label: const Text('Unirse'),
          ),
        ),
      ],
    );
  }
}

// Sala de espera: el codigo, los jugadores, el mapa y el boton para iniciar.
class _SalaDeEspera extends StatelessWidget {
  final ServicioDeSala sala;
  final EstadoSala estado;

  const _SalaDeEspera({required this.sala, required this.estado});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final codigo = estado.codigo ?? '';
    final puedeIniciar = estado.jugadores.length >= 2;

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
                  subtitle: jugador.conectado
                      ? null
                      : const Text('Desconectado, esperando que vuelva…'),
                  trailing: jugador.usuario == estado.anfitrion
                      ? const Chip(label: Text('Anfitrión'))
                      : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Mapa', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        _SelectorDeMapa(
          mapa: estado.mapa ?? 'clasico',
          // Solo el anfitrion lo cambia; los demas solo lo ven.
          onElegir: estado.soyAnfitrion ? sala.elegirMapa : null,
        ),
        const SizedBox(height: 28),
        if (estado.soyAnfitrion)
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('boton-iniciar'),
              onPressed: puedeIniciar ? sala.iniciar : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                puedeIniciar ? 'Iniciar partida' : 'Esperando jugadores…',
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
        const SizedBox(height: 12),
        TextButton.icon(
          key: const ValueKey('boton-salir-sala'),
          onPressed: sala.salir,
          icon: const Icon(Icons.logout),
          label: Text(estado.soyAnfitrion ? 'Cerrar la sala' : 'Salir'),
        ),
      ],
    );
  }
}

// Mapa de la sala. Si hay [onElegir] (el anfitrion), es una lista para
// cambiarlo; si no, solo muestra el nombre.
class _SelectorDeMapa extends StatefulWidget {
  final String mapa;
  final ValueChanged<String>? onElegir;

  const _SelectorDeMapa({required this.mapa, this.onElegir});

  @override
  State<_SelectorDeMapa> createState() => _SelectorDeMapaState();
}

class _SelectorDeMapaState extends State<_SelectorDeMapa> {
  // Nombre de cada mapa por su archivo ('clasico' -> 'Clásico'). Se lee una
  // sola vez.
  late final Future<Map<String, String>> _nombres = _leerNombres();

  static Future<Map<String, String>> _leerNombres() async {
    final nombres = <String, String>{};
    for (final ruta in await rutasDeMapas()) {
      final archivo = ruta
          .substring(ruta.lastIndexOf('/') + 1)
          .replaceAll('.txt', '');
      try {
        nombres[archivo] = (await cargarMapa(ruta)).nombre;
      } on FormatException {
        // Un mapa con errores no se puede elegir.
      }
    }
    return nombres;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _nombres,
      builder: (context, carga) {
        final nombres = carga.data ?? const {};
        final nombre = nombres[widget.mapa] ?? widget.mapa;
        final onElegir = widget.onElegir;

        if (onElegir == null || nombres.isEmpty) {
          return InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: Text(nombre, key: const ValueKey('mapa-de-la-sala')),
          );
        }
        return DropdownButtonFormField<String>(
          key: const ValueKey('selector-mapa'),
          initialValue: nombres.containsKey(widget.mapa) ? widget.mapa : null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            for (final MapEntry(key: archivo, value: nombre) in nombres.entries)
              DropdownMenuItem(value: archivo, child: Text(nombre)),
          ],
          onChanged: (archivo) {
            if (archivo != null && archivo != widget.mapa) {
              onElegir(archivo);
            }
          },
        );
      },
    );
  }
}

// Por ahora, al iniciar solo se muestra esto: la partida en linea se agrega
// en los siguientes pasos.
class _PartidaPendiente extends StatelessWidget {
  final EstadoSala estado;

  const _PartidaPendiente({required this.estado});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      key: const ValueKey('partida-pendiente'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.casino, size: 56, color: tema.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          '¡La partida empezó!',
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${estado.jugadores.length} jugadores · meta: ${estado.meta} puntos',
        ),
        const SizedBox(height: 16),
        Text(
          'La partida en línea todavía no está lista: aquí empezaría.',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
