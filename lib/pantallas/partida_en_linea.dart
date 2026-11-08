import 'dart:async';

import 'package:flutter/material.dart';

import '../constantes.dart';
import '../lector_mapas.dart';
import '../mapa.dart';
import '../multijugador/servicio_sala.dart';
import '../region.dart';
import '../sonidos.dart';
import '../tablero.dart';
import '../valores_iniciales_bloc.dart';
import '../widgets/dados_widget.dart';
import '../widgets/menu_regiones_widget.dart';
import '../widgets/panel_lateral_widget.dart';
import '../widgets/tablero_widget.dart';

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

  EstadoSala get _estado => widget.estado;

  @override
  void didUpdateWidget(PartidaEnLinea anterior) {
    super.didUpdateWidget(anterior);
    final antes = anterior.estado;
    // Suena al tirar los dados de una ronda nueva y al ganar una region.
    if (_estado.fase == 'ronda' && _estado.ronda != antes.ronda) {
      _sonidos.tirarDados();
    }
    if (antes.fase == 'ronda' &&
        _estado.fase != 'ronda' &&
        _estado.yo?.ultimoReclamo != null) {
      _sonidos.puntuarRegion();
    }
  }

  @override
  void dispose() {
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
    final colores = Theme.of(context).colorScheme;
    final yo = _estado.yo;
    final eligiendoValores =
        _estado.fase == 'valoresIniciales' && yo?.iniciales == null;
    final tablero = eligiendoValores
        ? _tableroParaValores(mapa)
        : _tableroDelServidor(mapa, yo);
    int vecesReclamada(Region region) => _estado.reclamos[region.id] ?? 0;

    // Mientras se arrastra un dado se resaltan las casillas donde cabe.
    final dados = _estado.dados;
    final puedoJugar = _puedoJugar(yo);
    final destinos = puedoJugar && dados != null && _dadoArrastrado != null
        ? tablero.destinosValidos(
            numero: dados[_dadoArrastrado!],
            ancla: dados[1 - _dadoArrastrado!],
          )
        : const <Celda>{};

    return ConstrainedBox(
      key: const ValueKey('partida-en-linea'),
      constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
      child: ClipRect(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  _Encabezado(estado: _estado, mapa: mapa),
                  const SizedBox(height: 10),
                  _Rivales(estado: _estado, mapa: mapa),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
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
                            onNumeroCambiado: _valoresBloc?.notificarCambio,
                            destinosValidos: destinos,
                            vecesReclamada: vecesReclamada,
                            onDadoSoltado: (celda, indice) =>
                                _colocar(tablero, celda, indice),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _controles(context, yo, eligiendoValores),
                  const SizedBox(height: 12),
                ],
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
    final tablero = _tableroDe(mapa, yo);
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

    if (_estado.fase == 'terminada') {
      return _Resultados(estado: _estado);
    }
    if (yo == null || !yo.jugando) {
      // Ya llegue a la meta: puedo seguir viendo o salir.
      return Column(
        children: [
          Text(
            '¡Llegaste a la meta! Los demás siguen jugando.',
            textAlign: TextAlign.center,
            style: tema.textTheme.titleMedium?.copyWith(
              color: naranjaLogo,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('boton-salir-partida'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Salir de la partida'),
          ),
        ],
      );
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

// Tablero de un jugador como lo manda el servidor: sus valores iniciales y
// los numeros que coloco. No se puede tocar.
Tablero _tableroDe(Mapa mapa, JugadorEnSala? jugador) {
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

// Arriba: la fase, el tiempo que queda, mis puntos y la meta, y el aviso de
// la region que complete en la ronda anterior.
class _Encabezado extends StatelessWidget {
  final EstadoSala estado;
  final Mapa mapa;

  const _Encabezado({required this.estado, required this.mapa});

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
      aviso = 'Arrastra un dado junto al número del otro dado, o pasa.';
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

// Tira con el tablero en miniatura de cada rival, sus puntos y su
// situacion. Al tocar uno se ve en grande.
class _Rivales extends StatelessWidget {
  final EstadoSala estado;
  final Mapa mapa;

  const _Rivales({required this.estado, required this.mapa});

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
                    tablero: _tableroDe(mapa, jugador),
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
              tablero: _tableroDe(mapa, jugador),
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

// Al terminar: los ganadores y la tabla de puntos.
class _Resultados extends StatelessWidget {
  final EstadoSala estado;

  const _Resultados({required this.estado});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gane = estado.ganadores.contains(estado.usuario);
    final tabla = [...estado.jugadores]
      ..sort((a, b) => b.puntos.compareTo(a.puntos));

    return Column(
      key: const ValueKey('resultados'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          gane
              ? '¡Ganaste!'
              : estado.ganadores.isEmpty
              ? 'Nadie ganó'
              : 'Ganó ${estado.ganadores.join(' y ')}',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: gane ? naranjaLogo : null,
          ),
        ),
        const SizedBox(height: 8),
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
            ],
          ),
        const SizedBox(height: 10),
        FilledButton(
          key: const ValueKey('boton-volver-menu'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Volver al menú'),
        ),
      ],
    );
  }
}
