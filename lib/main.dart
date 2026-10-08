import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'region.dart';
import 'tablero.dart';
import 'tipo.dart';
import 'turno_bloc.dart';
import 'valores_iniciales_bloc.dart';
import 'widgets/celda_widget.dart';
import 'widgets/dados_widget.dart';
import 'widgets/tablero_widget.dart';

// Ancho maximo del contenido para que la app se vea como en un telefono
// aun cuando la ventana sea mas ancha (por ejemplo, en escritorio).
const double anchoMaximoTelefono = 430;

void main() {
  runApp(const ProyectoBloquesApp());
}

class ProyectoBloquesApp extends StatelessWidget {
  const ProyectoBloquesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto Bloques',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ).copyWith(
              // Fondo negro grisaceo y tarjetas un poco mas claras.
              surfaceContainerLow: const Color(0xFF2B2B2E),
              surface: const Color(0xFF38383C),
            ),
        useMaterial3: true,
      ),
      home: const VistaPreviaTablero(),
    );
  }
}

class VistaPreviaTablero extends StatefulWidget {
  const VistaPreviaTablero({super.key});

  @override
  State<VistaPreviaTablero> createState() => _VistaPreviaTableroState();
}

class _VistaPreviaTableroState extends State<VistaPreviaTablero> {
  late final Tablero _tablero;
  late final ValoresInicialesBloc _valoresInicialesBloc;
  late final TurnoBloc _turnoBloc;

  @override
  void initState() {
    super.initState();
    _tablero = Tablero.desdeRegiones(
      filas: 7,
      columnas: 7,
      regiones: regionesMapa,
    );
    _tablero.celdasIniciales.first.numero = 4;
    _valoresInicialesBloc = ValoresInicialesBloc(_tablero);
    _turnoBloc = TurnoBloc(_tablero);
  }

  @override
  void dispose() {
    _valoresInicialesBloc.dispose();
    _turnoBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colores.surfaceContainerLow,
      appBar: AppBar(
        title: const Text('Bloques'),
        centerTitle: true,
        backgroundColor: colores.surfaceContainerLow,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: anchoMaximoTelefono),
            child: AnimatedBuilder(
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
                        _EncabezadoFase(estado: estado, turno: turno.turno),
                        const SizedBox(height: 12),
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
                                  tablero: _tablero,
                                  onNumeroCambiado:
                                      _valoresInicialesBloc.notificarCambio,
                                  destinosValidos: destinos,
                                  onDadoSoltado: (celda, indiceDado) =>
                                      _turnoBloc.add(
                                        DadoColocado(indiceDado, celda),
                                      ),
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
                            ? DadosWidget(bloc: _turnoBloc)
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
          ),
        ),
      ),
    );
  }

  Widget _botonListo(ValoresInicialesEstado estado) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
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
// antes de la partida, cuantas casillas iniciales van llenas; despues, el turno.
class _EncabezadoFase extends StatelessWidget {
  final ValoresInicialesEstado estado;
  final int turno;

  const _EncabezadoFase({required this.estado, required this.turno});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final llenas = estado.valores.whereType<int>().length;
    final total = estado.valores.length;
    final hayError = estado.estanCompletos && !estado.noHayRepetidos;

    final mensaje = estado.confirmado
        ? 'Arrastra un dado a una casilla vacía junto al número del otro dado.'
        : !estado.estanCompletos
        ? 'Completa las seis casillas iniciales con números distintos del 1 al 6.'
        : !estado.noHayRepetidos
        ? 'Las casillas iniciales deben tener números distintos.'
        : 'Casillas iniciales completas. Puedes continuar.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                estado.confirmado ? 'Turno $turno' : 'Valores iniciales',
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!estado.confirmado)
              Text(
                '$llenas/$total',
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
              value: total == 0 ? 0 : llenas / total,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          mensaje,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: hayError
                ? tema.colorScheme.error
                : tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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
  ];

  @override
  Widget build(BuildContext context) {
    final estiloTexto = Theme.of(context).textTheme.labelMedium;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (tipo, regla) in _entradas)
          Row(
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
