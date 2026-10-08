import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'reclamos.dart';
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

  // Puntos acumulados por el jugador.
  final int puntos;

  // Region que se completo con la jugada anterior, o null si no se completo
  // ninguna. Sirve para avisarle al jugador durante el turno siguiente.
  final ReclamoDeRegion? ultimoReclamo;

  const TurnoEstado({
    this.primero,
    this.segundo,
    this.turno = 0,
    this.dadoArrastrado,
    this.puntos = 0,
    this.ultimoReclamo,
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
        puntos: puntos,
        ultimoReclamo: ultimoReclamo,
      );
}

class TurnoBloc extends Bloc<TurnoEvento, TurnoEstado> {
  final Tablero tablero;
  final RegistroDeReclamos reclamos;
  final Random _azar;

  // Se puede pasar un Random propio para que las pruebas sean predecibles, y
  // un registro de reclamos para compartirlo con otros jugadores.
  TurnoBloc(this.tablero, {Random? azar, RegistroDeReclamos? reclamos})
      : _azar = azar ?? Random(),
        reclamos = reclamos ?? RegistroDeReclamos(),
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

  void _iniciarTurno(
    Emitter<TurnoEstado> emit, {
    int puntosGanados = 0,
    ReclamoDeRegion? reclamo,
  }) {
    emit(TurnoEstado(
      primero: _caraAleatoria(),
      segundo: _caraAleatoria(),
      turno: state.turno + 1,
      puntos: state.puntos + puntosGanados,
      ultimoReclamo: reclamo,
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

    // Si con este numero se lleno la region, el jugador la reclama.
    final region = tablero.obtenerRegion(evento.destino.coordenada);
    if (region != null && tablero.regionCompleta(region)) {
      final reclamo = ReclamoDeRegion(region, reclamos.reclamar(region));
      _iniciarTurno(emit, puntosGanados: reclamo.puntos, reclamo: reclamo);
      return;
    }

    _iniciarTurno(emit);
  }

  int _caraAleatoria() => _azar.nextInt(6) + 1;
}
