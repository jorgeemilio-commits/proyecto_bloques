// La conexion, el jugador y la sala, los errores y las constantes de las salas.
part of 'salas.dart';

// Una conexion de un jugador: por donde se le mandan mensajes.
abstract interface class Conexion {
  void enviar(Map<String, Object?> mensaje);
  void cerrar();
}

// Error que se le manda al jugador, con un mensaje listo para mostrar.
class _ErrorDeSala implements Exception {
  final String codigo;
  final String mensaje;

  const _ErrorDeSala(this.codigo, this.mensaje);
}

const _sesionInvalida = _ErrorDeSala(
  'sesionInvalida',
  'Tu sesión no es válida. Vuelve a iniciar sesión.',
);
const _sesionReemplazada = _ErrorDeSala(
  'sesionReemplazada',
  'Tu cuenta se abrió en otro dispositivo.',
);
const _mensajeInvalido = _ErrorDeSala('mensajeInvalido', 'Mensaje no válido.');

// Letras y numeros del codigo de invitacion: sin 0, O, 1, I ni L, que se
// confunden al dictarlos.
const _letrasDelCodigo = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int largoDelCodigo = 6;
const int maximoDeJugadores = 6;
const int minimoDeJugadores = 2;
// Tiempos por ronda que puede elegir el anfitrion, en segundos. Sin elegir
// ninguno (null), las rondas no tienen limite.
const List<int> tiemposPorRonda = [20, 30, 40, 60, 90];

// Un jugador que se identifico con "hola": su conexion actual, la sala en la
// que esta y, si se desconecto estando en una sala, el tiempo que le queda
// para volver. Su lugar en la sala dura mas que su conexion.
class Jugador {
  final String nombre;
  // null si esta desconectado.
  Conexion? conexion;
  Sala? sala;
  Timer? esperaReconexion;

  Jugador(this.nombre);

  bool get conectado => conexion != null;

  void enviar(Map<String, Object?> mensaje) => conexion?.enviar(mensaje);
}

class Sala {
  final String codigo;
  // Jugadores en el orden en que entraron; el primero es el anfitrion. En la
  // partida, quien se rinde sale de esta lista (pero sigue en la partida).
  final List<Jugador> jugadores = [];
  String mapa = 'clasico';
  // Segundos por ronda que eligio el anfitrion, o null si no hay limite.
  int? segundosPorRonda;
  // null mientras se esta en el lobby.
  Partida? partida;
  // Tiempo de la fase actual de la partida (valores iniciales, ronda o entre
  // rondas) y cuando se acaba.
  Timer? temporizador;
  DateTime? limite;
  // Si la partida ya se guardo en el historial (se guarda una sola vez).
  bool guardada = false;
  // Cuanto cambio el Elo de cada jugador al terminar (por nombre); vacio
  // mientras la partida sigue.
  Map<String, int> cambiosDeElo = const {};
  // Jugadores del lobby que marcaron "Listo". La partida solo se puede
  // iniciar cuando todos lo estan.
  final Set<Jugador> listos = {};

  bool get todosListos => jugadores.every(listos.contains);

  Sala(this.codigo);

  Jugador get anfitrion => jugadores.first;
  bool get enLobby => partida == null;
  String get fase => partida?.fase ?? 'lobby';
}
