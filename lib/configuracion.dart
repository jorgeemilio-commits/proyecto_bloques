import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Como se coloca el numero en la partida:
// - tocarAncla: se toca el dado que sera el ancla y luego la casilla donde
//   va el otro dado.
// - arrastrar: se arrastra el dado del numero a la casilla.
enum ModoDeControl { tocarAncla, arrastrar }

// Opciones del jugador que se guardan en el telefono (como el volumen, que
// esta en Sonidos).
class Configuracion {
  static final ValueNotifier<ModoDeControl> modoDeControl = ValueNotifier(
    ModoDeControl.tocarAncla,
  );

  static const String _claveModo = 'modoDeControl';

  // Lee lo guardado; se llama al abrir la app. Sin nada guardado se usa
  // "tocar el ancla".
  static Future<void> cargar() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final guardado = preferencias.getString(_claveModo);
      modoDeControl.value = ModoDeControl.values.firstWhere(
        (modo) => modo.name == guardado,
        orElse: () => ModoDeControl.tocarAncla,
      );
    } catch (_) {
      // Sin preferencias se queda el modo predeterminado.
    }
  }

  static Future<void> elegirModo(ModoDeControl modo) async {
    modoDeControl.value = modo;
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(_claveModo, modo.name);
    } catch (_) {
      // Si no se puede guardar, solo dura mientras la app este abierta.
    }
  }
}
