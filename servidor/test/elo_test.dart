import 'package:servidor/src/base_de_datos.dart';
import 'package:servidor/src/elo.dart';
import 'package:test/test.dart';

FinalDeJugador jugador(
  String nombre,
  int puntos, {
  bool gano = false,
  bool seRindio = false,
}) => (nombre: nombre, puntos: puntos, gano: gano, seRindio: seRindio);

void main() {
  test('dos jugadores: el ganador sube 20 y el otro baja 15', () {
    final cambios = cambiosDeElo([
      jugador('Ana', 26, gano: true),
      jugador('Luis', 12),
    ]);

    expect(cambios, {'Ana': 20, 'Luis': -15});
  });

  test('con 4: ganador, luego por puntos, y el que se rindio al final', () {
    final cambios = cambiosDeElo([
      // Eva se rindio con mas puntos que Leo, pero queda ultima.
      jugador('Eva', 18, seRindio: true),
      jugador('Leo', 5),
      jugador('Ana', 23, gano: true),
      jugador('Luis', 14),
    ]);

    expect(cambios, {'Ana': 25, 'Luis': 10, 'Leo': -5, 'Eva': -15});
  });

  test('empates: los ganadores y los mismos puntos reciben el mejor lugar', () {
    final cambios = cambiosDeElo([
      jugador('Ana', 26, gano: true),
      jugador('Luis', 26, gano: true),
      jugador('Eva', 9),
      jugador('Leo', 9),
      jugador('Mia', 3),
    ]);

    // Con 5: [25, 10, 0, -10, -15]. Ana y Luis 1.º; Eva y Leo 3.º; Mia 5.º.
    expect(cambios, {'Ana': 25, 'Luis': 25, 'Eva': 0, 'Leo': 0, 'Mia': -15});
  });

  test('solo cuenta si al terminar al menos dos no se rindieron', () {
    // 2 jugadores: Luis se rinde y Ana gana sola -> no cuenta.
    final porRendicion = cambiosDeElo([
      jugador('Ana', 12, gano: true),
      jugador('Luis', 15, seRindio: true),
    ]);
    // 2 jugadores: Ana llega a la meta y Luis seguia jugando -> cuenta.
    final normal = cambiosDeElo([
      jugador('Ana', 26, gano: true),
      jugador('Luis', 15),
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
    expect(normal, {'Ana': 20, 'Luis': -15});
    expect(dosSiguen, {'Ana': 25, 'Luis': 10, 'Eva': -5, 'Leo': -15});
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
