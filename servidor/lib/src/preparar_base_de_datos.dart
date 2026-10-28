import 'dart:io';

import 'package:bcrypt/bcrypt.dart';

import 'base_de_datos.dart';

// Usuarios de la base de datos de prueba. Solo se crean cuando todavia no
// existe una base de datos, para poder probar el servidor recien descargado.
// Su base de datos real (con las cuentas de verdad) no esta en git.
const List<({String nombre, String contrasena})> usuariosDePrueba = [
  (nombre: 'prueba', contrasena: 'prueba1234'),
  (nombre: 'jugador2', contrasena: 'jugador1234'),
];

// Prepara la base de datos en [ruta]:
// - Si ya existe, no la toca y devuelve false.
// - Si no existe, la crea con sus tablas y los usuarios de prueba (con sus
//   contraseñas cifradas con bcrypt) y devuelve true.
bool prepararBaseDeDatos(String ruta, {int costoBcrypt = 12}) {
  final archivo = File(ruta);
  if (archivo.existsSync()) {
    return false;
  }

  archivo.parent.createSync(recursive: true);
  final baseDeDatos = BaseDeDatos.abrir(ruta);
  try {
    for (final usuario in usuariosDePrueba) {
      baseDeDatos.crearUsuario(
        usuario.nombre,
        BCrypt.hashpw(
          usuario.contrasena,
          BCrypt.gensalt(logRounds: costoBcrypt),
        ),
        DateTime.now(),
      );
    }
  } finally {
    baseDeDatos.cerrar();
  }
  return true;
}
