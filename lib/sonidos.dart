import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Efectos de sonido y musica del juego (archivos en assets/sonidos/). Cada
// efecto tiene su propio reproductor para que puedan sonar al mismo tiempo.
//
// Cuidado en Windows: el plugin de audio deja esperando a la interfaz en cada
// orden (play, stop, volumen, dispose) y carga los archivos en otro hilo. Si
// se cruzan dos ordenes sobre el mismo reproductor (sobre todo un dispose
// mientras se carga un archivo) la app se congela y Windows la cierra. Para
// evitarlo:
// - Los reproductores son de toda la app (static): se crean la primera vez
//   que se usan y nunca se desechan, aunque se cierre la pantalla.
// - Cada archivo se carga una sola vez; para repetirlo se regresa al inicio y
//   se reanuda, sin volver a cargarlo (ReleaseMode.stop).
// - Las ordenes de cada reproductor van en fila, una despues de otra.
class Sonidos {
  // En las pruebas no hay audio: test/flutter_test_config.dart lo apaga.
  static bool activos = true;

  // Volumen elegido por el jugador (0 a 1) para la musica y los efectos. Se
  // multiplica por el volumen propio de cada sonido, asi que 1 es como sonaba
  // antes. Se guardan en el dispositivo para la proxima vez. La musica que ya
  // esta sonando cambia de volumen al mover la barra.
  static final ValueNotifier<double> volumenMusica = ValueNotifier<double>(1)
    ..addListener(_ajustarMusica);
  static final ValueNotifier<double> volumenEfectos = ValueNotifier(1);

  static const String _claveMusica = 'volumenMusica';
  static const String _claveEfectos = 'volumenEfectos';

  // Lee el volumen guardado; se llama al abrir la app.
  static Future<void> cargarVolumen() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      volumenMusica.value = preferencias.getDouble(_claveMusica) ?? 1;
      volumenEfectos.value = preferencias.getDouble(_claveEfectos) ?? 1;
    } catch (_) {
      // Sin preferencias guardadas se queda el volumen completo.
    }
  }

  // Guarda el volumen actual (al soltar una barra de volumen).
  static Future<void> guardarVolumen() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setDouble(_claveMusica, volumenMusica.value);
      await preferencias.setDouble(_claveEfectos, volumenEfectos.value);
    } catch (_) {
      // Si no se puede guardar, solo dura mientras la app este abierta.
    }
  }

  // --- Reproductores compartidos ---------------------------------------

  // Un reproductor por archivo de efecto, ya con su archivo cargado.
  static final Map<String, AudioPlayer> _efectos = {};

  // Ultima orden pendiente de cada reproductor; la siguiente espera a que
  // termine esta.
  static final Map<String, Future<void>> _filas = {};

  // Pone [orden] en la fila de [clave]. Si falla, la fila sigue.
  static Future<void> _enFila(String clave, Future<void> Function() orden) {
    final anterior = _filas[clave] ?? Future<void>.value();
    final siguiente = anterior.then((_) => orden()).catchError((_) {
      // Un sonido que falla no debe detener el juego.
    });
    _filas[clave] = siguiente;
    return siguiente;
  }

  // Reproductor del efecto [archivo], creandolo y cargandolo la primera vez.
  // Solo se llama dentro de su fila.
  static Future<AudioPlayer> _reproductorDe(String archivo) async {
    final existente = _efectos[archivo];
    if (existente != null) {
      return existente;
    }
    final reproductor = AudioPlayer();
    // Al terminar o al parar se queda con el archivo cargado.
    await reproductor.setReleaseMode(ReleaseMode.stop);
    await reproductor.setSource(AssetSource('sonidos/$archivo'));
    _efectos[archivo] = reproductor;
    return reproductor;
  }

  // --- Efectos ---------------------------------------------------------

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

  // Toca el efecto desde el principio (si ya estaba sonando, empieza de
  // nuevo).
  Future<void> _tocar(String archivo, {double volumen = 0.06}) {
    if (!activos) {
      return Future<void>.value();
    }
    return _enFila(archivo, () async {
      final reproductor = await _reproductorDe(archivo);
      await reproductor.setVolume(volumen * volumenEfectos.value);
      await reproductor.seek(Duration.zero);
      await reproductor.resume();
    });
  }

  // Cuando un rival completa una region. El archivo tiene unos 2.8 segundos
  // de silencio al principio y el "ohh" dura hasta los 4 segundos, asi que
  // se toca solo ese pedazo. Nunca suena dos veces al mismo tiempo: si ya
  // esta sonando, no se vuelve a tocar.
  static const String _archivoDecepcion =
      'Crowd Ohh Disappointed Sound Effect.mp3';
  static const Duration _inicioDecepcion = Duration(milliseconds: 2750);
  static const Duration _duracionDecepcion = Duration(milliseconds: 1400);

  static Timer? _finDecepcion;

  Future<void> decepcion() {
    if (!activos || _finDecepcion != null) {
      return Future<void>.value();
    }
    // Se marca como sonando antes de esperar nada, para que dos llamadas
    // seguidas no lo toquen dos veces.
    _finDecepcion = Timer(_duracionDecepcion, () {
      _finDecepcion = null;
      _enFila(_archivoDecepcion, () async {
        await _efectos[_archivoDecepcion]?.pause();
      });
    });
    return _enFila(_archivoDecepcion, () async {
      final reproductor = await _reproductorDe(_archivoDecepcion);
      await reproductor.setVolume(0.5 * volumenEfectos.value);
      await reproductor.seek(_inicioDecepcion);
      await reproductor.resume();
    });
  }

  // --- Musica ----------------------------------------------------------

  // Musica de las salas en linea (antes de la partida). Suena en bucle hasta
  // pararMusica.
  static const String musicaDeSalas =
      '14. Welcome to the Green Room (DELTARUNE Chapter 3+4 Soundtrack) - '
      'Toby Fox.mp3';

  // Volumen propio de la musica, antes del volumen del jugador.
  static const double _volumenBaseMusica = 0.15;
  static const String _filaMusica = '__musica__';

  static AudioPlayer? _musica;
  // Archivo cargado en el reproductor de la musica.
  static String? _archivoMusica;
  // Cancion que deberia estar sonando (null = ninguna).
  static String? _cancion;
  // Hay un cambio de volumen esperando en la fila (para no encolar uno por
  // cada movimiento de la barra).
  static bool _ajustePendiente = false;

  static void _ajustarMusica() {
    if (_musica == null || _ajustePendiente) {
      return;
    }
    _ajustePendiente = true;
    _enFila(_filaMusica, () async {
      _ajustePendiente = false;
      await _musica?.setVolume(_volumenBaseMusica * volumenMusica.value);
    });
  }

  // Toca [archivo] en bucle; si ya estaba sonando, no la reinicia.
  Future<void> tocarMusica(String archivo) {
    if (!activos || _cancion == archivo) {
      return Future<void>.value();
    }
    _cancion = archivo;
    return _enFila(_filaMusica, () async {
      // Si mientras esperaba en la fila se pidio parar, ya no se toca.
      if (_cancion != archivo) {
        return;
      }
      final musica = _musica ??= AudioPlayer();
      if (_archivoMusica != archivo) {
        await musica.setReleaseMode(ReleaseMode.loop);
        await musica.setSource(AssetSource('sonidos/$archivo'));
        _archivoMusica = archivo;
      }
      await musica.setVolume(_volumenBaseMusica * volumenMusica.value);
      await musica.seek(Duration.zero);
      await musica.resume();
    });
  }

  Future<void> pararMusica() {
    _cancion = null;
    if (_musica == null) {
      return Future<void>.value();
    }
    return _enFila(_filaMusica, () async {
      // Si mientras esperaba se pidio otra cancion, no se para.
      if (_cancion != null) {
        return;
      }
      await _musica?.pause();
    });
  }

  // Los reproductores son de toda la app y no se desechan (ver arriba), asi
  // que al cerrar una pantalla no hay nada que liberar.
  void dispose() {}
}
