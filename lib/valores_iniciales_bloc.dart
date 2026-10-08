import 'dart:math';

import 'package:flutter/foundation.dart';

import 'tablero.dart';

class ValoresInicialesEstado {
  final List<int?> valores;
  final String? mensajeError;
  final bool confirmado;

  const ValoresInicialesEstado({
    required this.valores,
    this.mensajeError,
    this.confirmado = false,
  });

  // Indica si todas las celdas iniciales ya tienen un numero.
  bool get estanCompletos => valores.every((valor) => valor != null);

  // Indica si los numeros iniciales son todos diferentes.
  bool get noHayRepetidos {
    final valoresDefinidos = valores.whereType<int>().toSet();
    return valoresDefinidos.length == valores.whereType<int>().length;
  }

  bool get puedeAvanzar =>
      !confirmado && estanCompletos && noHayRepetidos;
}

class ValoresInicialesBloc extends ChangeNotifier {
  final Tablero tablero;
  String? _mensajeError;
  bool _confirmado = false;

  ValoresInicialesBloc(this.tablero);

  void notificarCambio() {
    _mensajeError = null;
    notifyListeners();
  }

  // Llena las casillas iniciales con los numeros del 1 al 6 en orden
  // aleatorio, sin repetidos. Se puede pasar un Random para las pruebas.
  void llenarAleatorio([Random? azar]) {
    if (_confirmado) {
      return;
    }

    final numeros = [
      for (var numero = 1; numero <= tablero.celdasIniciales.length; numero++)
        numero,
    ]..shuffle(azar);

    for (var indice = 0; indice < numeros.length; indice++) {
      tablero.celdasIniciales[indice].numero = numeros[indice];
    }
    notificarCambio();
  }

  // Crea una fotografia de los numeros actuales de las celdas iniciales.
  ValoresInicialesEstado get estado => ValoresInicialesEstado(
        valores: List.unmodifiable(
          tablero.celdasIniciales.map((celda) => celda.numero),
        ),
        mensajeError: _mensajeError,
        confirmado: _confirmado,
      );

  // Lee el estado actual y decide si el juego puede continuar.
  bool avanzar() {
    final estadoActual = estado;

    // Muestra en la terminal lo que el BLoC esta leyendo del tablero.
    debugPrint('Valores iniciales: ${estadoActual.valores}');
    debugPrint('Estan completos: ${estadoActual.estanCompletos}');
    debugPrint('No hay repetidos: ${estadoActual.noHayRepetidos}');
    debugPrint('Puede avanzar: ${estadoActual.puedeAvanzar}');

    if (estadoActual.puedeAvanzar) {
      _mensajeError = null;
      _confirmado = true;
      for (final celda in tablero.celdasIniciales) {
        celda.esInsertable = false;
      }
      notifyListeners();
      return true;
    }

    _mensajeError = estadoActual.estanCompletos
        ? 'Los valores iniciales no pueden repetirse.'
        : 'Debes completar las seis celdas iniciales.';
    notifyListeners();
    return false;
  }
}
