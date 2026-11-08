import 'dart:math';

import 'package:servidor/src/partida.dart';
import 'package:test/test.dart';

// Jugada que completa la region Z1, cuyos premios son 7, 5 y 3.
Jugada completaZ1(int x) =>
    Jugada(x: x, y: 0, numero: 1, region: 'Z1', premios: const [7, 5, 3]);

// Pone valores iniciales a todos y empieza la primera ronda.
Partida empezada(List<String> nombres) {
  final partida = Partida(nombres);
  for (final participante in partida.participantes) {
    partida.ponerValores(participante, [1, 2, 3, 4, 5, 6]);
  }
  partida.empezarRonda(Random(1));
  return partida;
}

void main() {
  test('la meta depende de cuantos jugadores empiezan', () {
    expect(
      [
        for (var jugadores = 2; jugadores <= 6; jugadores++)
          metaPara(jugadores),
      ],
      [26, 24, 22, 20, 20],
    );
  });

  test('valores iniciales: 1 a 6 sin repetir; a quien falte, al azar', () {
    final partida = Partida(['Ana', 'Luis']);
    final ana = partida.de('Ana')!;
    final luis = partida.de('Luis')!;

    final repetidos = partida.ponerValores(ana, [1, 1, 2, 3, 4, 5]);
    final buenos = partida.ponerValores(ana, [6, 5, 4, 3, 2, 1]);
    final otraVez = partida.ponerValores(ana, [1, 2, 3, 4, 5, 6]);
    final listosAntes = partida.todosTienenValores;
    partida.valoresAlAzar(Random(1));

    expect((repetidos, buenos, otraVez), (false, true, false));
    expect(listosAntes, isFalse);
    expect(ana.iniciales, [6, 5, 4, 3, 2, 1]);
    expect(luis.iniciales!.toSet(), {1, 2, 3, 4, 5, 6});
    expect(partida.todosTienenValores, isTrue);
  });

  test('una jugada por ronda; quien no juega, pasa', () {
    final partida = empezada(['Ana', 'Luis']);
    final ana = partida.de('Ana')!;
    final luis = partida.de('Luis')!;

    final primera = partida.jugar(ana, const Jugada(x: 0, y: 1, numero: 3));
    final segunda = partida.jugar(ana, const Jugada(x: 2, y: 2, numero: 4));
    partida.resolverRonda();

    expect((primera, segunda), (true, false));
    expect(ana.casillas, [
      [0, 1, 3],
    ]);
    expect(luis.casillas, isEmpty);
    expect(partida.fase, 'entreRondas');
  });

  test(
    'empate en un reclamo: ambos ganan el premio y la region avanza uno',
    () {
      final partida = empezada(['Ana', 'Luis', 'Eva', 'Leo']);
      final [ana, luis, eva, leo] = partida.participantes;

      // Ana y Luis completan Z1 en la misma ronda: los dos ganan 7.
      partida.jugar(ana, completaZ1(0));
      partida.jugar(luis, completaZ1(1));
      partida.resolverRonda();
      // Eva la completa despues: gana 5. Leo, despues: 3.
      partida.empezarRonda(Random(1));
      partida.jugar(eva, completaZ1(2));
      partida.resolverRonda();
      partida.empezarRonda(Random(1));
      partida.jugar(leo, completaZ1(3));
      partida.resolverRonda();

      expect([for (final p in partida.participantes) p.puntos], [7, 7, 5, 3]);
      expect(leo.ultimoReclamo, (region: 'Z1', puntos: 3));
      // El reclamo de la ronda anterior ya no se muestra.
      expect(ana.ultimoReclamo, isNull);
    },
  );

  test('despues del tercer reclamo la region ya no da puntos', () {
    final nombres = ['A', 'B', 'C', 'D'];
    final partida = empezada(nombres);
    for (final participante in partida.participantes) {
      partida.jugar(participante, completaZ1(0));
      partida.resolverRonda();
      partida.empezarRonda(Random(1));
    }

    expect([for (final p in partida.participantes) p.puntos], [7, 5, 3, 0]);
  });

  test('meta: gana el de mas puntos de los que llegan; los demas siguen', () {
    final partida = empezada(['Ana', 'Luis', 'Eva', 'Leo']);
    final [ana, luis, eva, leo] = partida.participantes;
    // Meta con 4 jugadores: 22.
    ana.puntos = 18;
    luis.puntos = 20;

    // Ana llega a 25 y Luis a 27 en la misma ronda: gana Luis.
    partida.jugar(
      ana,
      const Jugada(x: 0, y: 0, numero: 1, region: 'R1', premios: [7]),
    );
    partida.jugar(
      luis,
      const Jugada(x: 0, y: 0, numero: 1, region: 'V1', premios: [7]),
    );
    partida.resolverRonda();
    // Eva y Leo siguen jugando.
    final faseTrasGanar = partida.fase;
    // Eva llega despues: ya no gana, y como Leo queda solo, termina.
    partida.empezarRonda(Random(1));
    eva.puntos = 30;
    partida.resolverRonda();

    expect(partida.ganadores, ['Luis']);
    expect(faseTrasGanar, 'entreRondas');
    expect(ana.situacion, 'llegoALaMeta');
    expect(leo.situacion, 'jugando');
    expect(partida.fase, 'terminada');
  });

  test('si queda un solo jugador jugando, la partida termina', () {
    final partida = empezada(['Ana', 'Luis']);
    final [ana, _] = partida.participantes;
    ana.puntos = 26;

    partida.resolverRonda();

    // Ana llego a la meta y Luis quedo solo: no sigue jugando solo.
    expect(partida.ganadores, ['Ana']);
    expect(partida.fase, 'terminada');
  });

  test('empate exacto al llegar a la meta: ganan los dos', () {
    final partida = empezada(['Ana', 'Luis']);
    final [ana, luis] = partida.participantes;
    ana.puntos = 26;
    luis.puntos = 26;

    partida.resolverRonda();

    expect(partida.ganadores, ['Ana', 'Luis']);
  });

  test('si todos los demas se rinden, el que queda gana', () {
    final partida = empezada(['Ana', 'Luis', 'Eva']);
    final [ana, luis, eva] = partida.participantes;

    partida.rendir(luis);
    final faseConDos = partida.fase;
    partida.rendir(eva);

    expect(faseConDos, 'ronda');
    expect(partida.ganadores, ['Ana']);
    expect(partida.fase, 'terminada');
    expect(ana.situacion, 'jugando');
    expect(luis.situacion, 'rendido');
  });
}
