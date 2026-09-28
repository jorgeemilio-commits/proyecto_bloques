import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'region.dart';
import 'tablero.dart';
import 'valores_iniciales_bloc.dart';
import 'widgets/tablero_widget.dart';

void main() {
  runApp(const ProyectoBloquesApp());
}

class ProyectoBloquesApp extends StatelessWidget {
  const ProyectoBloquesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto Bloques',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
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
  }

  @override
  void dispose() {
    _valoresInicialesBloc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tablero de Proyecto Bloques')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final alturaDisponible = math.max(
                0.0,
                constraints.maxHeight - 88,
              );
              final tamanoTablero = math
                  .min(560.0, math.min(constraints.maxWidth, alturaDisponible))
                  .toDouble();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: tamanoTablero,
                    child: TableroWidget(
                      tablero: _tablero,
                      onNumeroCambiado: _valoresInicialesBloc.notificarCambio,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _valoresInicialesBloc,
                    builder: (context, _) {
                      final estado = _valoresInicialesBloc.estado;
                      final mensaje = !estado.estanCompletos
                          ? 'Completa las seis casillas iniciales con números distintos del 1 al 6.'
                          : !estado.noHayRepetidos
                              ? 'Las casillas iniciales deben tener números distintos.'
                              : 'Casillas iniciales completas. Puedes continuar.';

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              mensaje,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: estado.puedeAvanzar
                                ? () {
                                    if (_valoresInicialesBloc.avanzar()) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Valores iniciales correctos.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('Listo'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
