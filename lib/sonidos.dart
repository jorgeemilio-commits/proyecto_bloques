import 'dart:async';

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

  // Al terminar una partida en linea: si gano o si quedo en ultimo lugar.
  // Suenan mas fuerte que los efectos del juego.
  void ganar() => _tocar('Happy Wheels victory green screen.mp3', volumen: 0.3);

  void quedarUltimo() => _tocar(
    'The Price is Right Losing Horn - Sound Effect (HD).mp3',
    volumen: 0.3,
  );

  // Cuando un rival completa una region. El archivo tiene unos 2.8 segundos
  // de silencio al principio y el "ohh" dura hasta los 4 segundos, asi que
  // se toca solo ese pedazo. Tiene su propio reproductor y nunca suena dos
  // veces al mismo tiempo: si ya esta sonando, no se vuelve a tocar.
  static const String _archivoDecepcion =
      'Crowd Ohh Disappointed Sound Effect.mp3';
  static const Duration _inicioDecepcion = Duration(milliseconds: 2750);
  static const Duration _duracionDecepcion = Duration(milliseconds: 1400);

  AudioPlayer? _decepcion;
  Timer? _finDecepcion;

  Future<void> decepcion() async {
    if (!activos || _finDecepcion != null) {
      return;
    }
    // Se marca como sonando antes de esperar nada, para que dos llamadas
    // seguidas no lo toquen dos veces.
    _finDecepcion = Timer(_duracionDecepcion, () {
      _finDecepcion = null;
      _decepcion?.stop();
    });
    try {
      final reproductor = _decepcion ??= AudioPlayer();
      await reproductor.stop();
      await reproductor.setVolume(0.5);
      await reproductor.setSource(AssetSource('sonidos/$_archivoDecepcion'));
      await reproductor.seek(_inicioDecepcion);
      await reproductor.resume();
    } catch (_) {
      // Un sonido que falla no debe detener el juego.
    }
  }

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

  Future<void> _tocar(String archivo, {double volumen = 0.06}) async {
    if (!activos) {
      return;
    }

    try {
      final reproductor = _reproductores.putIfAbsent(archivo, AudioPlayer.new);
      // Si el sonido ya estaba sonando, empieza de nuevo.
      await reproductor.stop();
      await reproductor.play(AssetSource('sonidos/$archivo'), volume: volumen);
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
    _finDecepcion?.cancel();
    _finDecepcion = null;
    _decepcion?.dispose();
    _decepcion = null;
  }
}
