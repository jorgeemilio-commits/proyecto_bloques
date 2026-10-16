import 'package:audioplayers/audioplayers.dart';

// Efectos de sonido del juego (archivos en assets/sonidos/). Cada efecto tiene
// su propio reproductor para que puedan sonar al mismo tiempo.
class Sonidos {
  // En las pruebas no hay audio: test/flutter_test_config.dart lo apaga.
  static bool activos = true;

  final Map<String, AudioPlayer> _reproductores = {};

  // Al tirar los dados (al empezar cada turno).
  void tirarDados() => _tocar('dice_roll_3.wav');

  // Al soltar un dado en una casilla.
  void colocar() => _tocar('pop_3.wav');

  // Al completar y puntuar una region.
  void puntuarRegion() => _tocar('paper_flip.mp3');

  Future<void> _tocar(String archivo) async {
    if (!activos) {
      return;
    }

    try {
      final reproductor = _reproductores.putIfAbsent(archivo, AudioPlayer.new);
      // Si el sonido ya estaba sonando, empieza de nuevo.
      await reproductor.stop();
      await reproductor.play(AssetSource('sonidos/$archivo'), volume: 0.06);
    } catch (_) {
      // Un sonido que falla no debe detener el juego.
    }
  }

  void dispose() {
    for (final reproductor in _reproductores.values) {
      reproductor.dispose();
    }
    _reproductores.clear();
  }
}
