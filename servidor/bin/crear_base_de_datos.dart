import 'dart:io';

import 'package:servidor/src/preparar_base_de_datos.dart';

// Prepara la base de datos del servidor.
//
// Uso (desde cualquier carpeta):
//   dart run servidor/bin/crear_base_de_datos.dart [ruta]
//
// Por defecto usa servidor/datos/cuentas.db. Si la base de datos ya existe
// (por ejemplo, la real con las cuentas de verdad) no la modifica. Si no
// existe, crea una base de datos de prueba con usuarios de ejemplo.
void main(List<String> argumentos) {
  // Carpeta servidor/, a partir de donde esta este script (servidor/bin/).
  final carpetaServidor = File.fromUri(Platform.script).parent.parent.path;
  final ruta = argumentos.isNotEmpty
      ? argumentos.first
      : '$carpetaServidor${Platform.pathSeparator}datos'
            '${Platform.pathSeparator}cuentas.db';

  if (!prepararBaseDeDatos(ruta)) {
    print('La base de datos ya existe en $ruta; no se modifico.');
    return;
  }

  print('Se creo una base de datos de prueba en $ruta');
  print('Usuarios de prueba:');
  for (final usuario in usuariosDePrueba) {
    print('  ${usuario.nombre} / ${usuario.contrasena}');
  }
}
