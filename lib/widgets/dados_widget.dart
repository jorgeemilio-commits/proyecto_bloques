import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dados_bloc.dart';

// Muestra los dos dados y el boton para tirarlos.
class DadosWidget extends StatelessWidget {
  final DadosBloc bloc;

  const DadosWidget({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DadosBloc, DadosEstado>(
      bloc: bloc,
      builder: (context, estado) {
        return Row(
          children: [
            DadoWidget(valor: estado.primero, tirada: estado.tiradas),
            const SizedBox(width: 10),
            DadoWidget(valor: estado.segundo, tirada: estado.tiradas),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => bloc.add(const DadosTirados()),
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Tirar dados'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Un dado con su cara de puntos. Cada tirada nueva gira y rebota un poco.
class DadoWidget extends StatelessWidget {
  // Numero de la cara (1 a 6); null muestra el dado sin tirar.
  final int? valor;
  // Numero de tirada; cambia en cada tirada para repetir la animacion.
  final int tirada;
  final double tamano;

  const DadoWidget({
    super.key,
    required this.valor,
    this.tirada = 0,
    this.tamano = 52,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animacion) {
        final curva = CurvedAnimation(
          parent: animacion,
          curve: Curves.easeOutBack,
        );
        return RotationTransition(
          turns: Tween(begin: 0.5, end: 1.0).animate(curva),
          child: ScaleTransition(scale: curva, child: child),
        );
      },
      child: _CaraDado(
        key: ValueKey(tirada),
        valor: valor,
        tamano: tamano,
      ),
    );
  }
}

class _CaraDado extends StatelessWidget {
  final int? valor;
  final double tamano;

  const _CaraDado({super.key, required this.valor, required this.tamano});

  // Posiciones de los puntos en una cuadricula de 3x3 (0 arriba a la
  // izquierda, 8 abajo a la derecha) para cada cara.
  static const Map<int, Set<int>> _puntosPorCara = {
    1: {4},
    2: {0, 8},
    3: {0, 4, 8},
    4: {0, 2, 6, 8},
    5: {0, 2, 4, 6, 8},
    6: {0, 2, 3, 5, 6, 8},
  };

  @override
  Widget build(BuildContext context) {
    final puntos = _puntosPorCara[valor] ?? const <int>{};
    final tamanoPunto = tamano * 0.18;

    return Container(
      width: tamano,
      height: tamano,
      padding: EdgeInsets.all(tamano * 0.14),
      decoration: BoxDecoration(
        color: valor == null ? Colors.grey.shade700 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(tamano * 0.2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: valor == null
          ? Center(
              child: Icon(
                Icons.question_mark_rounded,
                color: Colors.grey.shade400,
                size: tamano * 0.45,
              ),
            )
          : GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (var posicion = 0; posicion < 9; posicion++)
                  Center(
                    child: puntos.contains(posicion)
                        ? Container(
                            width: tamanoPunto,
                            height: tamanoPunto,
                            decoration: const BoxDecoration(
                              color: Color(0xFF222222),
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
