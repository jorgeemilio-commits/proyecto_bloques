import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'ayudantes.dart';
import 'consola.dart';

void main() {
  group('Reglas de colocacion', () {
    test('solo se coloca junto a una casilla con el numero del ancla', () {
      final tablero = crearTableroConDiagonal();
      final destino = celdaEn(tablero, 1, 0);

      final conAncla1 = tablero.puedeColocar(destino, numero: 5, ancla: 1);
      final conAncla6 = tablero.puedeColocar(destino, numero: 5, ancla: 6);

      expect(conAncla1, isTrue);
      expect(conAncla6, isFalse);
      mostrar('(1,0) con ancla 1 -> $conAncla1; con ancla 6 -> $conAncla6.');
    });

    test('no se puede colocar en una casilla ocupada', () {
      final tablero = crearTableroConDiagonal();
      final ocupada = celdaEn(tablero, 1, 1);

      expect(tablero.puedeColocar(ocupada, numero: 3, ancla: 1), isFalse);
      mostrar('(1,1) ya tiene ${ocupada.numero}: no se puede colocar.');
    });

    test('respeta la regla del color de la region', () {
      final tablero = crearTableroConDiagonal();
      // (2,1) y (2,0) son de la region azul: todos los numeros iguales.
      final primeraAzul = celdaEn(tablero, 2, 1);
      final segundaAzul = celdaEn(tablero, 2, 0);

      expect(tablero.puedeColocar(primeraAzul, numero: 4, ancla: 2), isTrue);
      primeraAzul.numero = 4;

      final distinto = tablero.puedeColocar(segundaAzul, numero: 5, ancla: 4);
      final igual = tablero.puedeColocar(segundaAzul, numero: 4, ancla: 4);
      expect(distinto, isFalse);
      expect(igual, isTrue);
      mostrar('Azul con un 4: poner 5 -> $distinto, poner 4 -> $igual.');
    });

    test('los destinos resaltados excluyen las casillas que rompen la regla', () {
      final tablero = crearTableroConDiagonal();

      // Junto al 3 de (2,2) hay 4 casillas vacias, pero (1,2) es roja y su
      // region ya tiene un 3.
      final destinos = tablero.destinosValidos(numero: 3, ancla: 3);

      expect(destinos, {
        celdaEn(tablero, 2, 1),
        celdaEn(tablero, 3, 2),
        celdaEn(tablero, 2, 3),
      });
      expect(destinos, isNot(contains(celdaEn(tablero, 1, 2))));
      mostrar(
        'Destinos para 3 con ancla 3: '
        '${destinos.map((c) => '(${c.coordenada.x},${c.coordenada.y})').join(' ')}; '
        '(1,2) roja queda fuera.',
      );
    });
  });

  group('TurnoBloc', () {
    test('cada tirada da dos valores del 1 al 6', () async {
      final bloc = TurnoBloc(crearTableroConDiagonal(), azar: Random(7));

      for (var tirada = 1; tirada <= 50; tirada++) {
        // La primera tirada empieza la partida; las demas pasan el turno
        // (Pasar se ignora si todavia no hay dados).
        bloc.add(tirada == 1 ? const TurnoIniciado() : const TurnoPasado());
        await bloc.stream.first;

        expect(bloc.state.primero, inInclusiveRange(1, 6));
        expect(bloc.state.segundo, inInclusiveRange(1, 6));
        expect(bloc.state.turno, tirada);
      }

      mostrar(
        '${bloc.state.turno} tiradas, todas entre 1 y 6; ultima: '
        '(${bloc.state.primero}, ${bloc.state.segundo}).',
      );
      await bloc.close();
    });

    test(
      'colocar un dado valido pone el numero y empieza otro turno',
      () async {
        final tablero = crearTableroConDiagonal();
        final bloc = TurnoBloc(tablero, azar: AzarFijo([1, 5, 3, 3]));
        final destino = celdaEn(tablero, 1, 0);

        bloc.add(const TurnoIniciado());
        await bloc.stream.first;
        // Se arrastra el 5 (dado 1); el 1 (dado 0) es el ancla en (0,0).
        bloc.add(DadoColocado(1, destino));
        await bloc.stream.first;

        expect(destino.numero, 5);
        expect(bloc.state.turno, 2);
        expect(bloc.state.primero, 3);
        expect(bloc.state.segundo, 3);
        mostrar(
          'Se coloco ${destino.numero} en (1,0); turno ${bloc.state.turno} '
          'con dados (${bloc.state.primero}, ${bloc.state.segundo}).',
        );

        await bloc.close();
      },
    );

    test('colocar en una casilla invalida no cambia nada', () async {
      final tablero = crearTableroConDiagonal();
      final bloc = TurnoBloc(tablero, azar: AzarFijo([1, 5]));
      // (6,6) no tiene ninguna casilla con 1 al lado.
      final destino = celdaEn(tablero, 6, 6);

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(1, destino));
      await bloc.stream.first;

      expect(destino.numero, isNull);
      expect(bloc.state.turno, 1);
      mostrar(
        'Soltar en (6,6) fue rechazado; sigue el turno ${bloc.state.turno}.',
      );

      await bloc.close();
    });

    test('pasar empieza otro turno sin colocar nada', () async {
      final tablero = crearTableroConDiagonal();
      final bloc = TurnoBloc(tablero, azar: AzarFijo([1, 5, 2, 6]));
      final antes = tablero.celdas.expand((fila) => fila).map((c) => c.numero);
      final numerosAntes = antes.toList();

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(const TurnoPasado());
      await bloc.stream.first;

      expect(bloc.state.turno, 2);
      expect(
        tablero.celdas.expand((fila) => fila).map((c) => c.numero),
        numerosAntes,
      );
      mostrar(
        'Paso el turno 1; turno ${bloc.state.turno} con dados '
        '(${bloc.state.primero}, ${bloc.state.segundo}) y tablero igual.',
      );

      await bloc.close();
    });
  });

  group('Espera antes de tirar los dados', () {
    const espera = Duration(milliseconds: 50);

    test('al colocar, los dados se apagan y se tiran despues', () async {
      final tablero = crearTableroConDiagonal();
      final bloc = TurnoBloc(
        tablero,
        azar: AzarFijo([1, 5, 3, 3]),
        espera: espera,
      );
      final destino = celdaEn(tablero, 1, 0);

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(1, destino));
      final esperando = await bloc.stream.first;
      final cronometro = Stopwatch()..start();
      final nuevaTirada = await bloc.stream.first;
      cronometro.stop();

      // Durante la espera: el numero ya esta puesto, sigue el turno 1 y no
      // hay dados.
      expect(destino.numero, 5);
      expect(esperando.turno, 1);
      expect(esperando.dadosTirados, isFalse);
      // Despues de la espera: turno 2 con dados nuevos.
      expect(nuevaTirada.turno, 2);
      expect((nuevaTirada.primero, nuevaTirada.segundo), (3, 3));
      expect(cronometro.elapsed, greaterThanOrEqualTo(espera * 0.8));
      mostrar(
        'Esperando: turno ${esperando.turno} sin dados; '
        '${cronometro.elapsedMilliseconds} ms despues: turno '
        '${nuevaTirada.turno} con (${nuevaTirada.primero}, '
        '${nuevaTirada.segundo}).',
      );

      await bloc.close();
    });

    test('pasar otra vez durante la espera no tira dos veces', () async {
      final bloc = TurnoBloc(
        crearTableroConDiagonal(),
        azar: AzarFijo([1, 5]),
        espera: espera,
      );

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(const TurnoPasado());
      await bloc.stream.first;
      // Segundo Pasar mientras los dados estan apagados: se ignora.
      bloc.add(const TurnoPasado());
      await Future<void>.delayed(espera * 3);

      expect(bloc.state.turno, 2);
      mostrar('Dos veces Pasar seguidas: turno ${bloc.state.turno}.');

      await bloc.close();
    });

    test('los puntos se suman antes de tirar los dados', () async {
      final tablero = crearTableroConDiagonal();
      // AzulUno: falta (2,0), que tiene al lado el 4 de (2,1).
      for (final (x, y) in const [(2, 1), (3, 1), (3, 2)]) {
        celdaEn(tablero, x, y).numero = 4;
      }
      final bloc = TurnoBloc(tablero, azar: AzarFijo([4, 4]), espera: espera);

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(0, celdaEn(tablero, 2, 0)));
      final esperando = await bloc.stream.first;
      final nuevaTirada = await bloc.stream.first;

      expect(esperando.dadosTirados, isFalse);
      expect(esperando.puntos, 7);
      expect(esperando.ultimoReclamo?.puntos, 7);
      expect(nuevaTirada.puntos, 7);
      // La tirada conserva el mismo reclamo (el sonido no se repite).
      expect(
        identical(nuevaTirada.ultimoReclamo, esperando.ultimoReclamo),
        isTrue,
      );
      mostrar(
        'Esperando: ${esperando.puntos} pts sin dados; tras la tirada: '
        '${nuevaTirada.puntos} pts en el turno ${nuevaTirada.turno}.',
      );

      await bloc.close();
    });
  });

  group('Arrastrar un dado a una celda', () {
    Future<int?> soltarDadoSobreCelda(
      WidgetTester tester, {
      required bool esDestinoValido,
    }) async {
      int? dadoRecibido;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Draggable<int>(
                  data: 1,
                  feedback: SizedBox(width: 20, height: 20),
                  child: Text('dado'),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CeldaWidget(
                    celda: Celda(coordenada: const Coordenada(0, 0)),
                    region: null,
                    esDestinoValido: esDestinoValido,
                    onDadoSoltado: (indice) => dadoRecibido = indice,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final gesto = await tester.startGesture(
        tester.getCenter(find.text('dado')),
      );
      await tester.pump();
      await gesto.moveTo(tester.getCenter(find.byType(CeldaWidget)));
      await tester.pump();
      await gesto.up();
      await tester.pump();

      return dadoRecibido;
    }

    testWidgets('una celda no valida rechaza el dado', (tester) async {
      final recibido = await soltarDadoSobreCelda(
        tester,
        esDestinoValido: false,
      );

      expect(recibido, isNull);
      mostrar('Celda no valida no recibio nada ($recibido).');
    });
  });
}
