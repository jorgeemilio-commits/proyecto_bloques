import 'dart:async';

import 'package:proyecto_bloques/sonidos.dart';
import 'package:proyecto_bloques/turno_bloc.dart';

// Flutter ejecuta este archivo antes de todas las pruebas de la carpeta test/.
// En las pruebas no hay reproductor de audio, asi que los sonidos se apagan, y
// los dados se tiran sin esperar (las pruebas de la espera la indican aparte).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Sonidos.activos = false;
  TurnoBloc.esperaPorDefecto = Duration.zero;
  await testMain();
}
