import 'dart:math';

import 'package:flutter/foundation.dart';

import 'tablero.dart';

class ValoresInicialesEstado {
  final List<int?> valores;
  final String? mensajeError;
  final bool confirmado;
  // Indica si cada numero inicial cumple la regla de su region (por ejemplo,
  // un 2 no cabe en una region naranja de 4 a 6).
  final bool cumplenRegiones;

  const ValoresInicialesEstado({
    required this.valores,
    this.mensajeError,
    this.confirmado = false,
    this.cumplenRegiones = true,
  });

  // Indica si todas las celdas iniciales ya tienen un numero.
  bool get estanCompletos => valores.every((valor) => valor != null);

  // Indica si los numeros iniciales son todos diferentes.
  bool get noHayRepetidos {
    final valoresDefinidos = valores.whereType<int>().toSet();
    return valoresDefinidos.length == valores.whereType<int>().length;
  }

  bool get puedeAvanzar =>
      !confirmado && estanCompletos && noHayRepetidos && cumplenRegiones;
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
  // aleatorio, sin repetidos y respetando la regla de cada region. Se puede
  // pasar un Random para las pruebas.
  void llenarAleatorio([Random? azar]) {
    if (_confirmado) {
      return;
    }

    final celdas = tablero.celdasIniciales;
    final aleatorio = azar ?? Random();
    for (final celda in celdas) {
      celda.numero = null;
    }

    // Prueba numeros al azar casilla por casilla; si una casilla se queda sin
    // opciones, regresa y cambia el numero de la anterior.
    bool asignarDesde(int indice, Set<int> usados) {
      if (indice == celdas.length) {
        return true;
      }
      final celda = celdas[indice];
      final opciones = tablero
          .numerosPermitidosEnInicial(celda)
          .difference(usados)
          .toList()
        ..shuffle(aleatorio);
      for (final numero in opciones) {
        celda.numero = numero;
        if (asignarDesde(indice + 1, {...usados, numero})) {
          return true;
        }
      }
      celda.numero = null;
      return false;
    }

    asignarDesde(0, {});
    notificarCambio();
  }

  // Crea una fotografia de los numeros actuales de las celdas iniciales.
  ValoresInicialesEstado get estado => ValoresInicialesEstado(
        valores: List.unmodifiable(
          tablero.celdasIniciales.map((celda) => celda.numero),
        ),
        mensajeError: _mensajeError,
        confirmado: _confirmado,
        cumplenRegiones: tablero.celdasIniciales.every(
          (celda) =>
              celda.numero == null ||
              tablero.numerosPermitidosEnInicial(celda).contains(celda.numero),
        ),
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

    _mensajeError = !estadoActual.estanCompletos
        ? 'Debes completar las seis celdas iniciales.'
        : !estadoActual.noHayRepetidos
            ? 'Los valores iniciales no pueden repetirse.'
            : 'Hay un numero que no cumple la regla de su region.';
    notifyListeners();
    return false;
  }
}
