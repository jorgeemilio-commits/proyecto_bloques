import 'package:flutter/foundation.dart';

import 'tablero.dart';

class ValoresInicialesEstado {
  final List<int?> valores;
  final String? mensajeError;

  const ValoresInicialesEstado({
    required this.valores,
    this.mensajeError,
  });

  // Indica si todas las celdas iniciales ya tienen un numero.
  bool get estanCompletos => valores.every((valor) => valor != null);

  // Indica si los numeros iniciales son todos diferentes.
  bool get noHayRepetidos {
    final valoresDefinidos = valores.whereType<int>().toSet();
    return valoresDefinidos.length == valores.whereType<int>().length;
  }

  bool get puedeAvanzar => estanCompletos && noHayRepetidos;
}

class ValoresInicialesBloc extends ChangeNotifier {
  final Tablero tablero;
  String? _mensajeError;

  ValoresInicialesBloc(this.tablero);

  // Crea una fotografia de los numeros actuales de las celdas iniciales.
  ValoresInicialesEstado get estado => ValoresInicialesEstado(
        valores: List.unmodifiable(
          tablero.celdasIniciales.map((celda) => celda.numero),
        ),
        mensajeError: _mensajeError,
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
      return true;
    }

    _mensajeError = estadoActual.estanCompletos
        ? 'Los valores iniciales no pueden repetirse.'
        : 'Debes completar las seis celdas iniciales.';
    notifyListeners();
    return false;
  }
}
