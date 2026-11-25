import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../configuracion.dart';
import '../juego/constantes.dart';
import '../juego/lector_mapas.dart';
import '../juego/mapa.dart';
import '../juego/region.dart';
import '../juego/tablero.dart';
import '../juego/valores_iniciales_bloc.dart';
import '../multijugador/servicio_sala.dart';
import '../sonidos.dart';
import '../widgets/brillo_ronda_widget.dart';
import '../widgets/celebracion_widget.dart';
import '../widgets/dados_widget.dart';
import '../widgets/leyenda_regiones_widget.dart';
import '../widgets/menu_regiones_widget.dart';
import '../widgets/panel_lateral_widget.dart';
import '../widgets/tablero_widget.dart';
import 'partida_en_linea/aviso_reclamo.dart';
import 'partida_en_linea/encabezado.dart';
import 'partida_en_linea/resultados.dart';
import 'partida_en_linea/rivales.dart';

// La partida en linea. Todo lo que se ve sale del ultimo estado del
// servidor (los dados, los tableros, los puntos y el tiempo); aqui solo se
// eligen los valores iniciales y la jugada de cada ronda, y se mandan.
class PartidaEnLinea extends StatefulWidget {
  final ServicioDeSala sala;
  final EstadoSala estado;

  const PartidaEnLinea({super.key, required this.sala, required this.estado});

  @override
  State<PartidaEnLinea> createState() => _PartidaEnLineaState();
}

class _PartidaEnLineaState extends State<PartidaEnLinea> {
  // El mapa de la sala se lee una sola vez.
  late final Future<Mapa> _mapa = cargarMapa(
    '$carpetaMapas${widget.estado.mapa ?? 'clasico'}.txt',
  );
  final Sonidos _sonidos = Sonidos();

  // Tablero donde se eligen los valores iniciales (mientras no se mandan).
  Tablero? _tableroValores;
  ValoresInicialesBloc? _valoresBloc;

  // Jugada de esta ronda ya mandada, que se muestra en el tablero mientras el
  // servidor termina la ronda.
  ({int ronda, int x, int y, int numero})? _pendiente;
  // Ultima ronda en la que ya jugue (coloque o pase), para no jugar dos veces
  // mientras llega la respuesta del servidor.
  int? _rondaJugada;
  // Dado que se esta arrastrando (0 o 1).
  int? _dadoArrastrado;
  // En el modo "tocar el ancla": el dado que se eligio como ancla (0 o 1).
  int? _ancla;

  // El mapa ya leido, para saber el color de las regiones en los avisos.
  Mapa? _mapaLeido;
  // Avisos de regiones que completaron los rivales, que se ven un momento.
  final List<ReclamoDeRival> _reclamos = [];
  int _siguienteReclamo = 0;
  // Ultima region que complete yo, para que brille en mi tablero.
  Destello? _destello;
  // Se pone en true al ganar para que caiga el confeti.
  bool _confeti = false;

  EstadoSala get _estado => widget.estado;

  @override
  void initState() {
    super.initState();
    Configuracion.modoDeControl.addListener(_alCambiarModo);
  }

  // Si se cambia el modo de control a media partida, se olvida el ancla.
  void _alCambiarModo() => setState(() => _ancla = null);

  bool get _tocandoAncla =>
      Configuracion.modoDeControl.value == ModoDeControl.tocarAncla;

  @override
  void didUpdateWidget(PartidaEnLinea anterior) {
    super.didUpdateWidget(anterior);
    // Cada ronda empieza sin ancla elegida.
    if (widget.estado.ronda != anterior.estado.ronda) {
      _ancla = null;
    }
    final antes = anterior.estado;
    // Suena al tirar los dados de una ronda nueva y al ganar una region.
    if (_estado.fase == 'ronda' && _estado.ronda != antes.ronda) {
      _sonidos.tirarDados();
    }
    // Al terminar la partida: sonido de victoria si gane, o el de perder si
    // quede en ultimo lugar (con los menos puntos, contando a los rendidos).
    final ganeAntes = antes.ganadores.contains(antes.usuario);
    final ganeAhora = _estado.ganadores.contains(_estado.usuario);
    if (!ganeAntes && ganeAhora) {
      _sonidos.ganar();
      _confeti = true;
    }
    if (antes.fase != 'terminada' && _estado.fase == 'terminada') {
      final yo = _estado.yo;
      final menosPuntos = _estado.jugadores
          .map((jugador) => jugador.puntos)
          .fold<int?>(null, (menor, puntos) => min(menor ?? puntos, puntos));
      if (!ganeAhora && yo != null && yo.puntos == menosPuntos) {
        _sonidos.quedarUltimo();
      }
    }
    final terminoLaRonda = antes.fase == 'ronda' && _estado.fase != 'ronda';
    final miReclamo = _estado.yo?.ultimoReclamo;
    if (terminoLaRonda && miReclamo != null) {
      _sonidos.puntuarRegion();
      _destello = Destello(
        id: _siguienteReclamo++,
        regionId: miReclamo.region,
        puntos: miReclamo.puntos,
      );
    }
    // Al terminar la ronda, un aviso por cada rival que completo una region.
    final mapa = _mapaLeido;
    if (terminoLaRonda && mapa != null) {
      var rivalReclamo = false;
      for (final jugador in _estado.jugadores) {
        final reclamo = jugador.ultimoReclamo;
        if (reclamo == null || jugador.usuario == _estado.usuario) {
          continue;
        }
        final region = mapa.regiones
            .where((region) => region.id == reclamo.region)
            .firstOrNull;
        _reclamos.add(
          ReclamoDeRival(
            id: _siguienteReclamo++,
            usuario: jugador.usuario,
            region: region,
            puntos: reclamo.puntos,
          ),
        );
        rivalReclamo = true;
      }
      // Un solo "ohh" aunque varios rivales hayan completado regiones.
      if (rivalReclamo) {
        _sonidos.decepcion();
      }
    }
  }

  @override
  void dispose() {
    Configuracion.modoDeControl.removeListener(_alCambiarModo);
    _valoresBloc?.dispose();
    _sonidos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Mapa>(
      future: _mapa,
      builder: (context, carga) {
        final mapa = carga.data;
        if (mapa == null) {
          return Center(
            child: carga.hasError
                ? Text('No se pudo leer el mapa "${_estado.mapa}".')
                : const CircularProgressIndicator(),
          );
        }
        return _partida(context, mapa);
      },
    );
  }

  Widget _partida(BuildContext context, Mapa mapa) {
    _mapaLeido = mapa;
    final colores = Theme.of(context).colorScheme;
    final yo = _estado.yo;
    final eligiendoValores =
        _estado.fase == 'valoresIniciales' && yo?.iniciales == null;
    final tablero = eligiendoValores
        ? _tableroParaValores(mapa)
        : _tableroDelServidor(mapa, yo);
    int vecesReclamada(Region region) => _estado.reclamos[region.id] ?? 0;

    // Se resaltan las casillas donde cabe el numero: mientras se arrastra
    // un dado, o (tocando) despues de elegir el ancla, donde va el otro.
    final dados = _estado.dados;
    final puedoJugar = _puedoJugar(yo);
    final indiceNumero = _tocandoAncla
        ? (_ancla == null ? null : 1 - _ancla!)
        : _dadoArrastrado;
    final destinos = puedoJugar && dados != null && indiceNumero != null
        ? tablero.destinosValidos(
            numero: dados[indiceNumero],
            ancla: dados[1 - indiceNumero],
          )
        : const <Celda>{};

    return ConstrainedBox(
      key: const ValueKey('partida-en-linea'),
      constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
      child: ClipRect(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Column(
                      children: [
                        EncabezadoDePartida(estado: _estado, mapa: mapa),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Center(
                            child: BrilloDeRonda(
                              ronda: _estado.ronda,
                              child: Card(
                                elevation: 0,
                                color: colores.surface,
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: TableroWidget(
                                    key: const ValueKey('mi-tablero'),
                                    tablero: tablero,
                                    onNumeroCambiado:
                                        _valoresBloc?.notificarCambio,
                                    destinosValidos: destinos,
                                    vecesReclamada: vecesReclamada,
                                    destello: _destello,
                                    onDadoSoltado: (celda, indice) =>
                                        _colocar(tablero, celda, indice),
                                    // Tocando: con el ancla elegida, tocar
                                    // una casilla resaltada pone ahi el otro
                                    // dado.
                                    onCeldaTap:
                                        _tocandoAncla &&
                                            puedoJugar &&
                                            indiceNumero != null
                                        ? (celda) {
                                            if (destinos.contains(celda)) {
                                              _colocar(
                                                tablero,
                                                celda,
                                                indiceNumero,
                                              );
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const LeyendaRegiones(),
                        const SizedBox(height: 10),
                        // Los tableros de los demas, debajo del mio.
                        RivalesDePartida(estado: _estado, mapa: mapa),
                      ],
                    ),
                  ),
                ),
                // Los dados y "Pasar" (o los resultados) en una barra fija
                // abajo, para que siempre se vean.
                _BarraDeJuego(child: _controles(context, yo, eligiendoValores)),
              ],
            ),
            // Avisos de las regiones que completaron los rivales: entran por
            // la izquierda, sobre el tablero, y se regresan solos.
            Positioned(
              top: 200,
              left: 0,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final reclamo in _reclamos)
                      AvisoDeReclamo(
                        key: ValueKey('aviso-reclamo-${reclamo.id}'),
                        reclamo: reclamo,
                        alTerminar: () =>
                            setState(() => _reclamos.remove(reclamo)),
                      ),
                  ],
                ),
              ),
            ),
            // Codigo de colores con los puntos que le quedan a cada region.
            Positioned.fill(
              child: PanelLateral(
                child: MenuRegionesWidget(
                  regiones: mapa.regiones,
                  vecesReclamada: vecesReclamada,
                ),
              ),
            ),
            // Confeti encima de todo al ganar (no bloquea los toques).
            if (_confeti) const Positioned.fill(child: Confeti()),
          ],
        ),
      ),
    );
  }

  bool _puedoJugar(JugadorEnSala? yo) =>
      _estado.fase == 'ronda' &&
      yo != null &&
      yo.jugando &&
      !yo.yaJugo &&
      _rondaJugada != _estado.ronda;

  // Tablero para elegir los valores iniciales: se guarda mientras se eligen.
  Tablero _tableroParaValores(Mapa mapa) {
    if (_tableroValores == null) {
      _tableroValores = mapa.crearTablero();
      _valoresBloc = ValoresInicialesBloc(_tableroValores!)
        ..addListener(() => setState(() {}));
    }
    return _tableroValores!;
  }

  // Mi tablero como lo tiene el servidor (valores iniciales y numeros
  // colocados), mas la jugada de esta ronda si ya la mande.
  Tablero _tableroDelServidor(Mapa mapa, JugadorEnSala? yo) {
    final tablero = tableroDeJugador(mapa, yo);
    final pendiente = _pendiente;
    if (pendiente != null && pendiente.ronda == _estado.ronda) {
      tablero.obtenerCelda(Coordenada(pendiente.x, pendiente.y)).numero ??=
          pendiente.numero;
    }
    return tablero;
  }

  // Suelto el dado [indice] en [celda]: se manda la jugada, con la region si
  // con ese numero se completa.
  void _colocar(Tablero tablero, Celda celda, int indice) {
    final dados = _estado.dados;
    if (!_puedoJugar(_estado.yo) || dados == null) {
      return;
    }
    final numero = dados[indice];
    _sonidos.colocar();
    celda.numero = numero;
    final region = tablero.obtenerRegion(celda.coordenada);
    final completa = region != null && tablero.regionCompleta(region);
    widget.sala.colocar(
      ronda: _estado.ronda,
      x: celda.coordenada.x,
      y: celda.coordenada.y,
      numero: numero,
      region: completa ? region.id : null,
      premios: completa
          ? [
              for (var orden = 1; orden <= 3; orden++)
                region.puntuaciones[orden] ?? 0,
            ]
          : const [],
    );
    setState(() {
      _rondaJugada = _estado.ronda;
      _pendiente = (
        ronda: _estado.ronda,
        x: celda.coordenada.x,
        y: celda.coordenada.y,
        numero: numero,
      );
      _dadoArrastrado = null;
      _ancla = null;
    });
  }

  // Lo de abajo del tablero, segun la fase y mi situacion.
  Widget _controles(
    BuildContext context,
    JugadorEnSala? yo,
    bool eligiendoValores,
  ) {
    final tema = Theme.of(context);
    final textoSuave = tema.textTheme.bodyMedium?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    if (_estado.fase == 'terminada' || yo == null || !yo.jugando) {
      return ResultadosDePartida(estado: _estado);
    }
    if (eligiendoValores) {
      final valores = _valoresBloc?.estado;
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const ValueKey('boton-listo'),
                onPressed: valores != null && valores.puedeAvanzar
                    ? _mandarValores
                    : null,
                child: const Text('Listo'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox.square(
            dimension: 52,
            child: IconButton.filledTonal(
              key: const ValueKey('boton-aleatorio'),
              tooltip: 'Números aleatorios',
              onPressed: () => _valoresBloc?.llenarAleatorio(),
              icon: const Icon(Icons.shuffle_rounded),
            ),
          ),
        ],
      );
    }
    if (_estado.fase == 'valoresIniciales') {
      return Text(
        'Esperando a que los demás pongan sus valores '
        '(${_cuantosJugaron()})…',
        textAlign: TextAlign.center,
        style: textoSuave,
      );
    }

    final puedoJugar = _puedoJugar(yo);
    return Row(
      children: [
        _dado(0, puedoJugar),
        const SizedBox(width: 10),
        _dado(1, puedoJugar),
        const SizedBox(width: 16),
        Expanded(
          child: puedoJugar
              ? SizedBox(
                  height: 52,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('boton-pasar'),
                    onPressed: () {
                      widget.sala.pasar(_estado.ronda);
                      setState(() => _rondaJugada = _estado.ronda);
                    },
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Pasar'),
                  ),
                )
              : Text(
                  _estado.fase == 'ronda'
                      ? 'Esperando a los demás (${_cuantosJugaron()})…'
                      : 'Siguiente ronda…',
                  key: const ValueKey('esperando-ronda'),
                  style: textoSuave,
                ),
        ),
      ],
    );
  }

  // Un dado de la ronda; se puede arrastrar solo si me toca jugar.
  Widget _dado(int indice, bool puedoJugar) {
    final valor = _estado.dados?[indice];
    final dado = DadoWidget(valor: valor, tirada: _estado.ronda);
    if (!puedoJugar || valor == null) {
      return Opacity(opacity: 0.45, child: dado);
    }
    // Tocando: se toca el dado ancla (y otra vez para soltarlo).
    if (_tocandoAncla) {
      return DadoParaTocar(
        key: ValueKey('dado-$indice'),
        dado: dado,
        elegido: _ancla == indice,
        onTap: () => setState(() => _ancla = _ancla == indice ? null : indice),
      );
    }
    return Draggable<int>(
      key: ValueKey('dado-$indice'),
      data: indice,
      onDragStarted: () => setState(() => _dadoArrastrado = indice),
      onDragEnd: (_) => setState(() => _dadoArrastrado = null),
      feedback: Material(
        color: Colors.transparent,
        child: DadoWidget(
          valor: valor,
          tirada: _estado.ronda,
          tamano: 60,
          levantado: true,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: dado),
      child: dado,
    );
  }

  void _mandarValores() {
    final tablero = _tableroValores;
    if (tablero == null) {
      return;
    }
    widget.sala.mandarValores([
      for (final celda in tablero.celdasIniciales) celda.numero!,
    ]);
    for (final celda in tablero.celdasIniciales) {
      celda.esInsertable = false;
    }
    setState(() {});
  }

  // Cuantos de los que siguen jugando ya mandaron lo de esta fase, "2/3".
  String _cuantosJugaron() {
    final jugando = _estado.jugadores.where((jugador) => jugador.jugando);
    final listos = jugando.where((jugador) => jugador.yaJugo).length;
    return '$listos/${jugando.length}';
  }
}

// Barra fija abajo de la partida, con los controles: los dados y "Pasar", o
// los valores iniciales, o los resultados.
class _BarraDeJuego extends StatelessWidget {
  final Widget child;

  const _BarraDeJuego({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('barra-juego'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: child,
      ),
    );
  }
}
