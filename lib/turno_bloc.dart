import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'tablero.dart';

sealed class TurnoEvento {
  const TurnoEvento();
}

// Inicia un turno nuevo: los dados se tiran automaticamente.
final class TurnoIniciado extends TurnoEvento {
  const TurnoIniciado();
}

// El jugador empezo (indice 0 o 1) o termino (null) de arrastrar un dado.
final class DadoArrastrado extends TurnoEvento {
  final int? indice;

  const DadoArrastrado(this.indice);
}

// El jugador solto el dado [indice] sobre [destino]. El otro dado es el ancla.
final class DadoColocado extends TurnoEvento {
  final int indice;
  final Celda destino;

  const DadoColocado(this.indice, this.destino);
}

// El jugador decide no colocar nada en este turno.
final class TurnoPasado extends TurnoEvento {
  const TurnoPasado();
}

class TurnoEstado {
  // Valores de los dos dados; son null antes del primer turno.
  final int? primero;
  final int? segundo;

  // Numero del turno actual (0 = la partida no ha empezado). Tambien sirve
  // para animar cada tirada, aunque salgan los mismos numeros.
  final int turno;

  // Dado que se esta arrastrando (0 o 1), o null si ninguno.
  final int? dadoArrastrado;

  const TurnoEstado({
    this.primero,
    this.segundo,
    this.turno = 0,
    this.dadoArrastrado,
  });

  bool get dadosTirados => primero != null && segundo != null;

  int? valorDado(int indice) => indice == 0 ? primero : segundo;

  // El ancla es el dado que no se esta usando como numero.
  int? anclaPara(int indice) => valorDado(1 - indice);

  TurnoEstado conDadoArrastrado(int? indice) => TurnoEstado(
        primero: primero,
        segundo: segundo,
        turno: turno,
        dadoArrastrado: indice,
      );
}

class TurnoBloc extends Bloc<TurnoEvento, TurnoEstado> {
  final Tablero tablero;
  final Random _azar;

  // Se puede pasar un Random propio para que las pruebas sean predecibles.
  TurnoBloc(this.tablero, {Random? azar})
      : _azar = azar ?? Random(),
        super(const TurnoEstado()) {
    on<TurnoIniciado>((_, emit) => _iniciarTurno(emit));
    on<DadoArrastrado>(
      (evento, emit) => emit(state.conDadoArrastrado(evento.indice)),
    );
    on<DadoColocado>(_colocar);
    on<TurnoPasado>((_, emit) => _iniciarTurno(emit));
  }

  // Casillas donde se puede soltar el dado [indice] con la tirada actual.
  Set<Celda> destinosPara(int indice) {
    final numero = state.valorDado(indice);
    final ancla = state.anclaPara(indice);
    if (numero == null || ancla == null) {
      return const {};
    }

    return tablero.destinosValidos(numero: numero, ancla: ancla);
  }

  void _iniciarTurno(Emitter<TurnoEstado> emit) {
    emit(TurnoEstado(
      primero: _caraAleatoria(),
      segundo: _caraAleatoria(),
      turno: state.turno + 1,
    ));
  }

  void _colocar(DadoColocado evento, Emitter<TurnoEstado> emit) {
    final numero = state.valorDado(evento.indice);
    final ancla = state.anclaPara(evento.indice);

    if (numero == null ||
        ancla == null ||
        !tablero.puedeColocar(evento.destino, numero: numero, ancla: ancla)) {
      emit(state.conDadoArrastrado(null));
      return;
    }

    evento.destino.numero = numero;
    _iniciarTurno(emit);
  }

  int _caraAleatoria() => _azar.nextInt(6) + 1;
}
