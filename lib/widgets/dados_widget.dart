import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../turno_bloc.dart';

// Muestra los dos dados del turno y el boton para pasar. Cada dado se puede
// arrastrar a una casilla; el otro dado funciona como ancla.
class DadosWidget extends StatelessWidget {
  final TurnoBloc bloc;

  const DadosWidget({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TurnoBloc, TurnoEstado>(
      bloc: bloc,
      builder: (context, estado) {
        return Row(
          children: [
            _dadoArrastrable(estado, 0),
            const SizedBox(width: 10),
            _dadoArrastrable(estado, 1),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => bloc.add(const TurnoPasado()),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: const Text('Pasar'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dadoArrastrable(TurnoEstado estado, int indice) {
    final valor = estado.valorDado(indice);
    final dado = DadoWidget(valor: valor, tirada: estado.turno);

    return Draggable<int>(
      data: indice,
      // No se puede arrastrar un dado que aun no se ha tirado.
      maxSimultaneousDrags: valor == null ? 0 : 1,
      onDragStarted: () => bloc.add(DadoArrastrado(indice)),
      onDragEnd: (_) => bloc.add(const DadoArrastrado(null)),
      feedback: Material(
        color: Colors.transparent,
        child: DadoWidget(valor: valor, tirada: estado.turno, tamano: 60),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: dado),
      child: dado,
    );
  }
}

// Un dado que muestra su numero. Cada tirada nueva gira y rebota un poco.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: valor == null ? Colors.grey.shade700 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(tamano * 0.2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: valor == null
          ? Icon(
              Icons.question_mark_rounded,
              color: Colors.grey.shade400,
              size: tamano * 0.45,
            )
          : Text(
              '$valor',
              style: TextStyle(
                color: const Color(0xFF222222),
                fontSize: tamano * 0.55,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}
