import 'dart:io';

import 'package:servidor/src/base_de_datos.dart';
import 'package:servidor/src/preparar_base_de_datos.dart';
import 'package:servidor/src/rutas.dart';
import 'package:servidor/src/seguridad.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

// Servidor de cuentas de Proyecto Bloques.
//
// Uso (desde cualquier carpeta):
//   dart run servidor/bin/servidor.dart [--puerto 8080] [--datos carpeta]
//
// - Usa la base de datos y la clave secreta de servidor/datos/ (o de la
//   carpeta indicada). Si no existen, las crea; la base de datos nueva es la
//   de prueba, con usuarios de ejemplo.
// - Escucha en toda la red para que otros dispositivos puedan conectarse.
Future<void> main(List<String> argumentos) async {
  final carpetaServidor = File.fromUri(Platform.script).parent.parent.path;
  final separador = Platform.pathSeparator;
  final puerto = int.parse(_opcion(argumentos, '--puerto') ?? '8080');
  final carpetaDatos =
      _opcion(argumentos, '--datos') ?? '$carpetaServidor${separador}datos';
  Directory(carpetaDatos).createSync(recursive: true);

  // Base de datos: si no existe, se crea la de prueba.
  final rutaBaseDeDatos = '$carpetaDatos${separador}cuentas.db';
  if (prepararBaseDeDatos(rutaBaseDeDatos)) {
    print('Se creo una base de datos de prueba con estos usuarios:');
    for (final usuario in usuariosDePrueba) {
      print('  ${usuario.nombre} / ${usuario.contrasena}');
    }
  }
  final baseDeDatos = BaseDeDatos.abrir(rutaBaseDeDatos);

  // Clave secreta para firmar los JWT: se crea una vez y se reutiliza, asi
  // los tokens siguen valiendo aunque se reinicie el servidor.
  final archivoSecreto = File('$carpetaDatos${separador}secreto_jwt.txt');
  if (!archivoSecreto.existsSync()) {
    archivoSecreto.writeAsStringSync(crearSecreto());
  }
  final tokens = Tokens(archivoSecreto.readAsStringSync().trim());

  final manejador = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(crearManejador(baseDeDatos: baseDeDatos, tokens: tokens));

  final HttpServer servidor;
  try {
    servidor = await shelf_io.serve(manejador, InternetAddress.anyIPv4, puerto);
  } on SocketException catch (error) {
    stderr.writeln(
      'No se pudo abrir el puerto $puerto (¿ya hay otro servidor?): '
      '${error.message}',
    );
    baseDeDatos.cerrar();
    exitCode = 1;
    return;
  }

  print('Servidor de cuentas escuchando en el puerto $puerto.');
  print('Datos en: $carpetaDatos');
  print('Direcciones para conectarse:');
  print('  En esta computadora: http://localhost:$puerto');
  print('  Desde el emulador de Android: http://10.0.2.2:$puerto');
  for (final interfaz in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
  )) {
    for (final direccion in interfaz.addresses) {
      print(
        '  Desde otro dispositivo (${interfaz.name}): '
        'http://${direccion.address}:$puerto',
      );
    }
  }
  print('Presione Ctrl+C para detenerlo.');

  // Ctrl+C: cierra el servidor y la base de datos antes de salir.
  ProcessSignal.sigint.watch().first.then((_) async {
    print('Deteniendo el servidor...');
    await servidor.close(force: true);
    baseDeDatos.cerrar();
    exit(0);
  });
}

// Valor de una opcion como "--puerto 8080", o null si no se paso.
String? _opcion(List<String> argumentos, String nombre) {
  final indice = argumentos.indexOf(nombre);
  return indice >= 0 && indice + 1 < argumentos.length
      ? argumentos[indice + 1]
      : null;
}
