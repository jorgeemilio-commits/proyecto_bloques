import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

sealed class DadosEvento {
  const DadosEvento();
}

final class DadosTirados extends DadosEvento {
  const DadosTirados();
}

class DadosEstado {
  // Valores de los dos dados; son null mientras no se ha tirado.
  final int? primero;
  final int? segundo;

  // Cuantas veces se han tirado los dados. Sirve para animar cada tirada,
  // aunque salgan los mismos numeros que la anterior.
  final int tiradas;

  const DadosEstado({this.primero, this.segundo, this.tiradas = 0});

  bool get fueronTirados => primero != null && segundo != null;
}

class DadosBloc extends Bloc<DadosEvento, DadosEstado> {
  final Random _azar;

  // Se puede pasar un Random con semilla para que las pruebas sean predecibles.
  DadosBloc({Random? azar})
      : _azar = azar ?? Random(),
        super(const DadosEstado()) {
    on<DadosTirados>(_tirar);
  }

  void _tirar(DadosTirados evento, Emitter<DadosEstado> emit) {
    emit(DadosEstado(
      primero: _caraAleatoria(),
      segundo: _caraAleatoria(),
      tiradas: state.tiradas + 1,
    ));
  }

  int _caraAleatoria() => _azar.nextInt(6) + 1;
}
