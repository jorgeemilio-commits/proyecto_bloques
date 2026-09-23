import 'package:flutter/foundation.dart';

import 'region.dart';
import 'tablero.dart';

class ValoresInicialesEstado {
  final List<int?> valores;
  final String? mensajeError;

  const ValoresInicialesEstado({
    required this.valores,
    this.mensajeError,
  });

  bool get estanCompletos => valores.every((valor) => valor != null);

  bool get noHayRepetidos {
    final valoresDefinidos = valores.whereType<int>().toSet();
    return valoresDefinidos.length == valores.whereType<int>().length;
  }

  bool get puedeAvanzar => estanCompletos && noHayRepetidos;
}

class ValoresInicialesBloc extends ChangeNotifier {
  final Tablero tablero;
  final List<int?> _valores;
  String? _mensajeError;

  ValoresInicialesBloc(this.tablero)
      : _valores = List<int?>.filled(
          tablero.coordenadasIniciales.length,
          null,
        );

  ValoresInicialesEstado get estado => ValoresInicialesEstado(
        valores: List.unmodifiable(_valores),
        mensajeError: _mensajeError,
      );

  void actualizarValor(Coordenada coordenada, int? valor) {
    final indice = _indiceDeCoordenada(coordenada);
    if (indice == -1) {
      throw ArgumentError('La coordenada no es una celda inicial.');
    }

    _valores[indice] = valor;
    _mensajeError = null;
    notifyListeners();
  }

  bool avanzar() {
    if (estado.puedeAvanzar) {
      _mensajeError = null;
      return true;
    }

    _mensajeError = estado.estanCompletos
        ? 'Los valores iniciales no pueden repetirse.'
        : 'Debes completar las seis celdas iniciales.';
    notifyListeners();
    return false;
  }

  void reiniciar() {
    for (var indice = 0; indice < _valores.length; indice++) {
      _valores[indice] = null;
    }
    _mensajeError = null;
    notifyListeners();
  }

  int _indiceDeCoordenada(Coordenada coordenada) {
    return tablero.coordenadasIniciales.indexWhere(
      (coordenadaInicial) =>
          coordenadaInicial.x == coordenada.x &&
          coordenadaInicial.y == coordenada.y,
    );
  }
}
