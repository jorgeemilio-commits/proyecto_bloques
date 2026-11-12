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

  // Musica de las salas en linea (antes de la partida). Suena en bucle hasta
  // pararMusica.
  static const String musicaDeSalas =
      '14. Welcome to the Green Room (DELTARUNE Chapter 3+4 Soundtrack) - '
      'Toby Fox.mp3';

  AudioPlayer? _musica;
  String? _cancion;

  // Toca [archivo] en bucle; si ya estaba sonando, no la reinicia.
  Future<void> tocarMusica(String archivo) async {
    if (!activos || _cancion == archivo) {
      return;
    }
    _cancion = archivo;
    try {
      final musica = _musica ??= AudioPlayer();
      await musica.stop();
      await musica.setReleaseMode(ReleaseMode.loop);
      await musica.play(AssetSource('sonidos/$archivo'), volume: 0.15);
    } catch (_) {
      // Si la musica falla, el juego sigue sin ella.
    }
  }

  Future<void> pararMusica() async {
    _cancion = null;
    try {
      await _musica?.stop();
    } catch (_) {
      // Nada que hacer: solo era la musica.
    }
  }

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
    _musica?.dispose();
    _musica = null;
    _cancion = null;
  }
}
