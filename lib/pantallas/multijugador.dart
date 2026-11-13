import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constantes.dart';
import '../lector_mapas.dart';
import '../mapa.dart';
import '../multijugador/servicio_sala.dart';
import '../sonidos.dart';
import 'partida_en_linea.dart';
import 'seleccion_mapa.dart';

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
  // Musica de fondo mientras se elige o se espera en la sala.
  final Sonidos _sonidos = Sonidos();

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
    widget.sala.cuenta.addListener(_alCambiarLaSesion);
    widget.sala.addListener(_actualizarMusica);
    widget.sala.conectar();
    _actualizarMusica();
  }

  // La musica de las salas suena antes de la partida (al crear o unirse a una
  // sala y en la sala de espera) y se detiene cuando empieza la partida.
  void _actualizarMusica() {
    if (_enLaPartida) {
      _sonidos.pararMusica();
    } else {
      _sonidos.tocarMusica(Sonidos.musicaDeSalas);
    }
  }

  // Si se cerro la sesion (se abrio la cuenta en otro dispositivo), se quita
  // esta pantalla; debajo ya esta el inicio de sesion.
  void _alCambiarLaSesion() {
    if (mounted && !widget.sala.cuenta.conSesion) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  @override
  void dispose() {
    _avisos.cancel();
    widget.sala.cuenta.removeListener(_alCambiarLaSesion);
    // Primero se deja de escuchar, para que desconectar no vuelva a poner la
    // musica.
    widget.sala.removeListener(_actualizarMusica);
    _sonidos.pararMusica();
    _sonidos.dispose();
    // Salir de la pantalla es salir de la sala a proposito: en el lobby se
    // sale, y en la partida se rinde (ya lo confirmo al presionar atras). Asi
    // los demas no esperan los 15 segundos de reconexion, y al volver a entrar
    // no regresa a la partida. Esos 15 segundos son solo para cuando se cae
    // la red.
    if (_enLaPartida) {
      widget.sala.rendirse();
    } else if (widget.sala.estado?.fase == 'lobby') {
      widget.sala.salir();
    }
    widget.sala.desconectar();
    widget.sala.dispose();
    super.dispose();
  }

  // Ya empezo la partida (fase distinta de sin sala y de lobby).
  bool get _enLaPartida => widget.sala.estado?.enLaPartida ?? false;

  bool get _enElLobby => widget.sala.estado?.fase == 'lobby';

  // Salir ahora seria rendirse: la partida sigue y yo sigo jugando. (Si ya
  // llegue a la meta o la partida termino, salir no cambia nada.)
  bool get _saliresRendirse {
    final estado = widget.sala.estado;
    return _enLaPartida &&
        estado?.fase != 'terminada' &&
        (estado?.yo?.jugando ?? false);
  }

  // Atras durante la partida: salir es rendirse, asi que primero pregunta. En
  // el lobby no hace nada: se sale con el boton de salir o borrar la sala.
  Future<void> _alPresionarAtras(bool yaSalio, Object? _) async {
    if (yaSalio || _enElLobby || !await _confirmarRendirse(context)) {
      return;
    }
    if (mounted) {
      // Al cerrarse la pantalla, dispose manda "rendirse".
      Navigator.of(context).pop();
    }
  }

  Future<void> _rendirseSinSalir() async {
    if (await _confirmarRendirse(context)) {
      widget.sala.rendirse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sala,
      builder: (context, _) => PopScope(
        canPop: !_saliresRendirse && !_enElLobby,
        onPopInvokedWithResult: _alPresionarAtras,
        child: _pantalla(context),
      ),
    );
  }

  Widget _pantalla(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('pantalla-multijugador'),
      backgroundColor: colores.surfaceContainerLow,
      appBar: AppBar(
        // En la sala de espera no hay flecha de atras: se sale con el boton
        // de abajo.
        automaticallyImplyLeading: !_enElLobby,
        title: Text(_enLaPartida ? 'Partida' : 'Multijugador'),
        centerTitle: true,
        backgroundColor: colores.surfaceContainerLow,
        actions: [
          if (_saliresRendirse)
            IconButton(
              key: const ValueKey('boton-rendirse'),
              tooltip: 'Rendirse',
              color: colores.error,
              onPressed: _rendirseSinSalir,
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
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
            contenido = PartidaEnLinea(sala: sala, estado: estado);
          }

          return SafeArea(
            child: Column(
              children: [
                if (sala.conexion == EstadoConexion.reconectando)
                  const _BarraReconectando(),
                Expanded(
                  // La partida ocupa toda la pantalla; lo demas va centrado y
                  // con scroll.
                  child: estado != null && estado.enLaPartida
                      ? Center(child: contenido)
                      : Center(
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
    final hayJugadores = estado.jugadores.length >= 2;
    // Para iniciar hacen falta 2 jugadores o mas y que todos esten listos.
    final puedeIniciar = hayJugadores && estado.todosListos;
    final estoyListo = estado.yo?.listo ?? false;

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
        _MapaDeLaSala(
          mapa: estado.mapa ?? 'clasico',
          // Solo el anfitrion lo cambia; los demas solo lo ven.
          onElegir: estado.soyAnfitrion ? sala.elegirMapa : null,
        ),
        const SizedBox(height: 20),
        Text('Tiempo por ronda', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        _TiempoPorRonda(
          segundos: estado.segundosPorRonda,
          // Solo el anfitrion lo cambia; los demas solo lo ven.
          onElegir: estado.soyAnfitrion ? sala.elegirTiempo : null,
        ),
        const SizedBox(height: 28),
        // Cada jugador (tambien el anfitrion) marca que esta listo.
        SizedBox(
          height: 52,
          child: estoyListo
              ? OutlinedButton.icon(
                  key: const ValueKey('boton-listo-sala'),
                  onPressed: () => sala.marcarListo(false),
                  icon: const Icon(Icons.check_circle, color: Colors.green),
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
        const SizedBox(height: 12),
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

// Mapa de la sala con su vista previa, como en la eleccion de mapa offline.
// El anfitrion lo toca para cambiarlo (se abre la misma pantalla de elegir
// mapa); los demas solo lo ven.
class _MapaDeLaSala extends StatefulWidget {
  final String mapa;
  final ValueChanged<String>? onElegir;

  const _MapaDeLaSala({required this.mapa, this.onElegir});

  @override
  State<_MapaDeLaSala> createState() => _MapaDeLaSalaState();
}

class _MapaDeLaSalaState extends State<_MapaDeLaSala> {
  late Future<Mapa> _carga = _cargar();

  Future<Mapa> _cargar() => cargarMapa('$carpetaMapas${widget.mapa}.txt');

  @override
  void didUpdateWidget(_MapaDeLaSala anterior) {
    super.didUpdateWidget(anterior);
    // El anfitrion cambio el mapa.
    if (anterior.mapa != widget.mapa) {
      _carga = _cargar();
    }
  }

  void _cambiar(ValueChanged<String> onElegir) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (contextoRuta) => SeleccionMapa(
          alElegir: (archivo) {
            Navigator.of(contextoRuta).pop();
            if (archivo != widget.mapa) {
              onElegir(archivo);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onElegir = widget.onElegir;

    return FutureBuilder<Mapa>(
      future: _carga,
      builder: (context, carga) {
        final mapa = carga.data;
        if (mapa == null) {
          return SizedBox(
            height: 136,
            child: Center(
              child: carga.hasError
                  ? Text('No se pudo leer el mapa "${widget.mapa}".')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return TarjetaMapa(
          key: const ValueKey('mapa-de-la-sala'),
          mapa: mapa,
          onElegir: onElegir == null ? null : () => _cambiar(onElegir),
          detalle: onElegir == null ? null : 'Toca para cambiar el mapa',
        );
      },
    );
  }
}

// Tiempo por ronda de la sala. El anfitrion elige entre "Sin limite" y
// varios tiempos; los demas solo ven el elegido.
class _TiempoPorRonda extends StatelessWidget {
  // Los mismos que acepta el servidor; null = sin limite.
  static const List<int?> _opciones = [null, 20, 30, 40, 60, 90];

  final int? segundos;
  final ValueChanged<int?>? onElegir;

  const _TiempoPorRonda({required this.segundos, this.onElegir});

  static String _texto(int? segundos) =>
      segundos == null ? 'Sin límite' : '$segundos s';

  @override
  Widget build(BuildContext context) {
    final onElegir = this.onElegir;
    if (onElegir == null) {
      return InputDecorator(
        decoration: const InputDecoration(border: OutlineInputBorder()),
        child: Text(
          segundos == null
              ? 'Sin límite: la ronda espera a que todos jueguen'
              : '${_texto(segundos)} por ronda',
          key: const ValueKey('tiempo-de-la-sala'),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opcion in _opciones)
          ChoiceChip(
            key: ValueKey('tiempo-${opcion ?? 'sin-limite'}'),
            label: Text(_texto(opcion)),
            selected: opcion == segundos,
            onSelected: (_) {
              if (opcion != segundos) {
                onElegir(opcion);
              }
            },
          ),
      ],
    );
  }
}

// Pide confirmacion antes de rendirse: no se puede volver a la partida.
Future<bool> _confirmarRendirse(BuildContext context) async {
  final seguro = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('¿Rendirte?'),
      content: const Text(
        'Saldrás de la partida y no podrás volver. Los demás seguirán '
        'jugando.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('confirmar-rendirse'),
          onPressed: () => Navigator.of(contexto).pop(true),
          child: const Text('Rendirme'),
        ),
      ],
    ),
  );
  return seguro ?? false;
}
