import 'dart:async';

import 'package:flutter/material.dart';

import '../constantes.dart';
import '../multijugador/servicio_sala.dart';
import '../sonidos.dart';
import '../widgets/fondo_animado_widget.dart';
import '../widgets/volumen_widget.dart';
import 'partida_en_linea.dart';
import 'multijugador/entrada_sala.dart';
import 'multijugador/sala_de_espera.dart';

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
      if (_saliresRendirse) {
        widget.sala.rendirse();
      }
      widget.sala.salir();
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

  // Fondo segun la fase: dados al elegir o esperar sala, el del juego en la
  // partida, y el de resultados en cuanto gane.
  String _fondoPara(EstadoSala? estado) {
    if (estado == null || !estado.enLaPartida) {
      return fondoDados;
    }
    if (estado.ganadores.contains(estado.usuario)) {
      return fondoResultados;
    }
    return fondoJuego;
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
          const BotonConfiguracion(),
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
            contenido = EntradaDeSala(sala: sala);
          } else if (estado.fase == 'lobby') {
            contenido = SalaDeEspera(sala: sala, estado: estado);
          } else {
            contenido = PartidaEnLinea(sala: sala, estado: estado);
          }

          return FondoAnimado(
            imagen: _fondoPara(estado),
            child: SafeArea(
              child: Column(
                children: [
                  if (sala.conexion == EstadoConexion.reconectando)
                    const _BarraReconectando(),
                  Expanded(
                    // La partida ocupa toda la pantalla; lo demas va centrado y
                    // con scroll (en la sala, con la barra de botones abajo).
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
                  if (estado != null && estado.fase == 'lobby')
                    BarraDeLaSala(sala: sala, estado: estado),
                ],
              ),
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
