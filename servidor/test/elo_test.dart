import 'package:servidor/src/base_de_datos.dart';
import 'package:servidor/src/elo.dart';
import 'package:test/test.dart';

FinalDeJugador jugador(
  String nombre,
  int puntos, {
  int elo = 1000,
  bool gano = false,
  bool seRindio = false,
}) =>
    (nombre: nombre, elo: elo, puntos: puntos, gano: gano, seRindio: seRindio);

void main() {
  test('dos jugadores parejos: el ganador sube 32 y el otro baja 32', () {
    final cambios = cambiosDeElo([
      jugador('Ana', 26, gano: true),
      jugador('Luis', 12),
    ]);

    expect(cambios, {'Ana': 32, 'Luis': -32});
  });

  test('ganarle a alguien mas fuerte da mas que a alguien mas debil', () {
    // Ana (1000) le gana a Luis (1200): era poco probable.
    final sorpresa = cambiosDeElo([
      jugador('Ana', 26, gano: true),
      jugador('Luis', 12, elo: 1200),
    ]);
    // Luis (1200) le gana a Ana (1000): era lo esperado.
    final esperado = cambiosDeElo([
      jugador('Ana', 12),
      jugador('Luis', 26, elo: 1200, gano: true),
    ]);

    expect(sorpresa, {'Ana': 49, 'Luis': -49});
    expect(esperado, {'Ana': -15, 'Luis': 15});
  });

  test('con 4: ganador, luego por puntos, y el que se rindio al final', () {
    final cambios = cambiosDeElo([
      // Eva se rindio con mas puntos que Leo, pero queda ultima.
      jugador('Eva', 18, seRindio: true),
      jugador('Leo', 5),
      jugador('Ana', 23, gano: true),
      jugador('Luis', 14),
    ]);

    // Todos con 1000: duelos de 0.5 esperado contra 1, 0.5 o 0.
    expect(cambios, {'Ana': 32, 'Luis': 11, 'Leo': -11, 'Eva': -32});
  });

  test('empates: entre ganadores y con los mismos puntos cuentan medio', () {
    final cambios = cambiosDeElo([
      jugador('Ana', 26, gano: true),
      jugador('Luis', 26, gano: true),
      jugador('Eva', 9),
      jugador('Leo', 9),
      jugador('Mia', 3),
    ]);

    expect(cambios, {'Ana': 24, 'Luis': 24, 'Eva': -8, 'Leo': -8, 'Mia': -32});
  });

  test('solo cuenta si al terminar al menos dos no se rindieron', () {
    // 2 jugadores: Luis se rinde y Ana gana sola -> no cuenta.
    final porRendicion = cambiosDeElo([
      jugador('Ana', 12, gano: true),
      jugador('Luis', 15, seRindio: true),
    ]);
    // 4 jugadores: dos se rinden pero dos siguen -> cuenta.
    final dosSiguen = cambiosDeElo([
      jugador('Ana', 22, gano: true),
      jugador('Luis', 14),
      jugador('Eva', 9, seRindio: true),
      jugador('Leo', 4, seRindio: true),
    ]);
    // 3 jugadores: los otros dos se rinden -> no cuenta.
    final quedaUno = cambiosDeElo([
      jugador('Ana', 10, gano: true),
      jugador('Luis', 14, seRindio: true),
      jugador('Eva', 9, seRindio: true),
    ]);

    expect(porRendicion, {'Ana': 0, 'Luis': 0});
    expect(dosSiguen, {'Ana': 32, 'Luis': 11, 'Eva': -11, 'Leo': -32});
    expect(quedaUno, {'Ana': 0, 'Luis': 0, 'Eva': 0});
  });

  test('el Elo empieza en 1000, se suma al guardar y no baja de 0', () {
    final baseDeDatos = BaseDeDatos.enMemoria();
    final ana = baseDeDatos.crearUsuario('Ana', 'hash', DateTime.now())!;
    final inicial = ana.elo;

    void guardar(int cambio) => baseDeDatos.guardarPartida(
      mapa: 'clasico',
      meta: 26,
      rondas: 5,
      terminada: DateTime.now(),
      resultados: [
        (
          usuarioId: ana.id,
          puntos: 10,
          situacion: 'jugando',
          gano: false,
          cambioElo: cambio,
        ),
      ],
    );

    guardar(20);
    final trasGanar = baseDeDatos.usuarioPorId(ana.id)!.elo;
    guardar(-5000);
    final trasPerderMucho = baseDeDatos.usuarioPorId(ana.id)!.elo;
    final historial = baseDeDatos.historial(ana.id);
    baseDeDatos.cerrar();

    expect((inicial, trasGanar, trasPerderMucho), (1000, 1020, 0));
    expect(historial.partidas.first.jugadores.single.cambioElo, -5000);
  });
}
