import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constantes.dart';
import '../mapa.dart';
import '../reclamos.dart';
import '../sonidos.dart';
import '../tablero.dart';
import '../tipo.dart';
import '../turno_bloc.dart';
import '../valores_iniciales_bloc.dart';
import '../widgets/celda_widget.dart';
import '../widgets/dados_widget.dart';
import '../widgets/menu_regiones_widget.dart';
import '../widgets/panel_lateral_widget.dart';
import '../widgets/tablero_widget.dart';

// Pantalla de la partida: encabezado, tablero, leyenda, dados y panel de
// regiones. Recibe el mapa elegido en la seleccion de mapa.
class VistaPreviaTablero extends StatefulWidget {
  // Mapa con el que se juega la partida.
  final Mapa mapa;

  const VistaPreviaTablero({super.key, required this.mapa});

  @override
  State<VistaPreviaTablero> createState() => _VistaPreviaTableroState();
}

class _VistaPreviaTableroState extends State<VistaPreviaTablero> {
  late final Tablero _tablero;
  late final ValoresInicialesBloc _valoresInicialesBloc;
  late final TurnoBloc _turnoBloc;
  final Sonidos _sonidos = Sonidos();

  @override
  void initState() {
    super.initState();
    _tablero = widget.mapa.crearTablero();
    // Pone un 4 de entrada en la primera casilla inicial cuya region lo
    // acepte (en una naranja de 1 a 3, por ejemplo, no cabe).
    for (final celda in _tablero.celdasIniciales) {
      if (_tablero.numerosPermitidosEnInicial(celda).contains(4)) {
        celda.numero = 4;
        break;
      }
    }
    _valoresInicialesBloc = ValoresInicialesBloc(_tablero);
    _turnoBloc = TurnoBloc(_tablero);
  }

  @override
  void dispose() {
    _valoresInicialesBloc.dispose();
    _turnoBloc.close();
    _sonidos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('pantalla-principal'),
      backgroundColor: colores.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Bloques'),
        centerTitle: true,
        backgroundColor: colores.surfaceContainerLow,
      ),
      // Suena al tirar los dados (cada turno nuevo) y al completar una region
      // (un reclamo nuevo; la tirada siguiente conserva el mismo reclamo).
      body: MultiBlocListener(
        listeners: [
          BlocListener<TurnoBloc, TurnoEstado>(
            bloc: _turnoBloc,
            listenWhen: (anterior, actual) => anterior.turno != actual.turno,
            listener: (context, _) => _sonidos.tirarDados(),
          ),
          BlocListener<TurnoBloc, TurnoEstado>(
            bloc: _turnoBloc,
            listenWhen: (anterior, actual) =>
                actual.ultimoReclamo != null &&
                !identical(anterior.ultimoReclamo, actual.ultimoReclamo),
            listener: (context, _) => _sonidos.puntuarRegion(),
          ),
        ],
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
              // El panel de regiones se desliza encima del juego; ClipRect
              // evita que se asome fuera del ancho del telefono.
              child: ClipRect(
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _valoresInicialesBloc,
                      builder: (context, _) => BlocBuilder<TurnoBloc, TurnoEstado>(
                        bloc: _turnoBloc,
                        builder: (context, turno) {
                          final estado = _valoresInicialesBloc.estado;
                          // Mientras se arrastra un dado se resaltan sus destinos.
                          final destinos = turno.dadoArrastrado == null
                              ? const <Celda>{}
                              : _turnoBloc.destinosPara(turno.dadoArrastrado!);

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Column(
                              children: [
                                _EncabezadoFase(estado: estado, turno: turno),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Center(
                                    child: Card(
                                      key: const ValueKey('tarjeta-tablero'),
                                      elevation: 0,
                                      color: colores.surface,
                                      margin: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: TableroWidget(
                                          key: const ValueKey('tablero'),
                                          tablero: _tablero,
                                          onNumeroCambiado:
                                              _valoresInicialesBloc
                                                  .notificarCambio,
                                          destinosValidos: destinos,
                                          // Las regiones reclamadas se ven mas
                                          // apagadas.
                                          vecesReclamada: _turnoBloc
                                              .reclamos
                                              .vecesReclamada,
                                          // Solo las casillas validas aceptan el
                                          // dado, asi que aqui siempre se coloca.
                                          onDadoSoltado: (celda, indiceDado) {
                                            _sonidos.colocar();
                                            _turnoBloc.add(
                                              DadoColocado(indiceDado, celda),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _LeyendaRegiones(),
                                const SizedBox(height: 16),
                                // Al confirmar los valores iniciales inicia la partida
                                // y el boton Listo se cambia por los dados.
                                estado.confirmado
                                    ? DadosWidget(
                                        key: const ValueKey('dados'),
                                        bloc: _turnoBloc,
                                      )
                                    : _botonListo(estado),
                                // Espacio extra abajo para que los controles no queden
                                // pegados al borde de la pantalla.
                                const SizedBox(height: 24),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    // Codigo de colores con los puntos de cada region; se
                    // actualiza con cada cambio del turno (reclamos).
                    Positioned.fill(
                      child: PanelLateral(
                        key: const ValueKey('panel-lateral'),
                        child: BlocBuilder<TurnoBloc, TurnoEstado>(
                          bloc: _turnoBloc,
                          builder: (context, _) => MenuRegionesWidget(
                            regiones: _tablero.regiones,
                            vecesReclamada: _turnoBloc.reclamos.vecesReclamada,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _botonListo(ValoresInicialesEstado estado) {
    return Row(
      children: [
        Expanded(child: _botonConfirmar(estado)),
        const SizedBox(width: 12),
        // Llena las casillas iniciales al azar para empezar rapido.
        SizedBox.square(
          dimension: 52,
          child: IconButton.filledTonal(
            key: const ValueKey('boton-aleatorio'),
            tooltip: 'Números aleatorios',
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _valoresInicialesBloc.llenarAleatorio(),
            icon: const Icon(Icons.shuffle_rounded),
          ),
        ),
      ],
    );
  }

  Widget _botonConfirmar(ValoresInicialesEstado estado) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        key: const ValueKey('boton-listo'),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        // Al confirmar los valores iniciales empieza el primer turno y los
        // dados se tiran solos.
        onPressed: estado.puedeAvanzar
            ? () {
                if (_valoresInicialesBloc.avanzar()) {
                  _turnoBloc.add(const TurnoIniciado());
                }
              }
            : null,
        child: const Text('Listo'),
      ),
    );
  }
}

// Muestra la fase actual y el mensaje que le indica al jugador que hacer:
// antes de la partida, cuantas casillas iniciales van llenas; despues, el
// turno, los puntos y si se acaba de completar una region.
class _EncabezadoFase extends StatelessWidget {
  final ValoresInicialesEstado estado;
  final TurnoEstado turno;

  const _EncabezadoFase({required this.estado, required this.turno});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final llenas = estado.valores.whereType<int>().length;
    final total = estado.valores.length;
    final hayError =
        estado.estanCompletos &&
        (!estado.noHayRepetidos || !estado.cumplenRegiones);
    final reclamo = estado.confirmado ? turno.ultimoReclamo : null;

    final mensaje = reclamo != null
        ? _mensajeDeReclamo(reclamo)
        : estado.confirmado
        ? 'Arrastra un dado a una casilla vacía junto al número del otro dado.'
        : !estado.estanCompletos
        ? 'Completa las seis casillas iniciales con números distintos del 1 al 6.'
        : !estado.noHayRepetidos
        ? 'Las casillas iniciales deben tener números distintos.'
        : !estado.cumplenRegiones
        ? 'Hay un número que no cumple la regla de su región.'
        : 'Casillas iniciales completas. Puedes continuar.';

    return Column(
      key: const ValueKey('encabezado'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                key: const ValueKey('titulo-fase'),
                estado.confirmado
                    ? 'Turno ${turno.turno}'
                    : 'Valores iniciales',
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              key: const ValueKey('marcador'),
              estado.confirmado ? '${turno.puntos} pts' : '$llenas/$total',
              style: tema.textTheme.titleMedium?.copyWith(
                color: tema.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!estado.confirmado) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const ValueKey('barra-progreso'),
              value: total == 0 ? 0 : llenas / total,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          key: const ValueKey('mensaje'),
          mensaje,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: hayError
                ? tema.colorScheme.error
                : reclamo != null
                ? Colors.amber.shade300
                : tema.colorScheme.onSurfaceVariant,
            fontWeight: reclamo != null ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }

  String _mensajeDeReclamo(ReclamoDeRegion reclamo) {
    final nombre = reclamo.region.tipo.nombre;
    return reclamo.puntos > 0
        ? '¡Completaste una región $nombre! +${reclamo.puntos} puntos.'
        : 'Completaste una región $nombre, pero ya no da puntos.';
  }
}

// Leyenda compacta con el color y la regla de cada tipo de region.
class _LeyendaRegiones extends StatelessWidget {
  const _LeyendaRegiones();

  static const List<(TipoRegion, String)> _entradas = [
    (TipoRegion.azul, 'Iguales'),
    (TipoRegion.rojo, 'Distintos'),
    (TipoRegion.amarillo, 'Distintos'),
    (TipoRegion.lila, 'Máx. 2 valores'),
    (TipoRegion.verde, 'Libre'),
    (TipoRegion.blanco, 'Iguales'),
    (TipoRegion.naranjaBaja, '1–3 · rayada 4–6'),
  ];

  @override
  Widget build(BuildContext context) {
    final estiloTexto = Theme.of(context).textTheme.labelMedium;

    return Wrap(
      key: const ValueKey('leyenda'),
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (tipo, regla) in _entradas)
          Row(
            key: ValueKey('leyenda-${tipo.nombre}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colorDeRegion(tipo),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(regla, style: estiloTexto),
            ],
          ),
      ],
    );
  }
}
