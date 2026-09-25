import 'package:flutter_bloc/flutter_bloc.dart';

import 'tablero.dart';

sealed class NumeroCeldaEvento {
  const NumeroCeldaEvento();
}

final class NumeroCeldaSeleccionado extends NumeroCeldaEvento {
  final int numero;

  const NumeroCeldaSeleccionado(this.numero);
}

final class NumeroCeldaBorrado extends NumeroCeldaEvento {
  const NumeroCeldaBorrado();
}

class NumeroCeldaEstado {
  final int? numero;

  const NumeroCeldaEstado({this.numero});
}

class NumeroCeldaBloc extends Bloc<NumeroCeldaEvento, NumeroCeldaEstado> {
  final Celda celda;

  NumeroCeldaBloc(this.celda)
      : super(NumeroCeldaEstado(numero: celda.numero)) {
    on<NumeroCeldaSeleccionado>(_seleccionarNumero);
    on<NumeroCeldaBorrado>(_borrarNumero);
  }

  void _seleccionarNumero(
    NumeroCeldaSeleccionado evento,
    Emitter<NumeroCeldaEstado> emit,
  ) {
    if (evento.numero < 1 || evento.numero > 9) {
      return;
    }

    celda.numero = evento.numero;
    emit(NumeroCeldaEstado(numero: celda.numero));
  }

  void _borrarNumero(
    NumeroCeldaBorrado evento,
    Emitter<NumeroCeldaEstado> emit,
  ) {
    celda.numero = null;
    emit(const NumeroCeldaEstado());
  }
}
