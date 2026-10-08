import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/main.dart' show VistaPreviaTablero;
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/dados_widget.dart';
import 'consola.dart';

// Random que devuelve las caras indicadas en orden, para saber que saldra.
class AzarFijo implements Random {
  final List<int> caras;
  int _siguiente = 0;

  AzarFijo(this.caras);

  @override
  int nextInt(int max) => caras[_siguiente++ % caras.length] - 1;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

// Tablero real con las casillas iniciales (diagonal) llenas del 1 al 6.
Tablero crearTableroConIniciales() {
  final tablero = Tablero.desdeRegiones(
    filas: 7,
    columnas: 7,
    regiones: regionesMapa,
  );
  for (var indice = 0; indice < tablero.celdasIniciales.length; indice++) {
    tablero.celdasIniciales[indice].numero = indice + 1;
  }
  return tablero;
}

Celda celdaEn(Tablero tablero, int x, int y) =>
    tablero.obtenerCelda(Coordenada(x, y));

void main() {
  group('Reglas de colocacion', () {
    test('las vecinas son arriba, abajo, izquierda y derecha', () {
      final tablero = crearTableroConIniciales();

      expect(tablero.vecinas(celdaEn(tablero, 0, 0)), hasLength(2));
      expect(tablero.vecinas(celdaEn(tablero, 3, 3)), hasLength(4));
      mostrar('Vecinas de (0,0): 2; de (3,3): 4.');
    });

    test('solo se coloca junto a una casilla con el numero del ancla', () {
      final tablero = crearTableroConIniciales();
      final destino = celdaEn(tablero, 1, 0);

      final conAncla1 = tablero.puedeColocar(destino, numero: 5, ancla: 1);
      final conAncla6 = tablero.puedeColocar(destino, numero: 5, ancla: 6);

      expect(conAncla1, isTrue);
      expect(conAncla6, isFalse);
      mostrar('(1,0) con ancla 1 -> $conAncla1; con ancla 6 -> $conAncla6.');
    });

    test('no se puede colocar en una casilla ocupada', () {
      final tablero = crearTableroConIniciales();
      final ocupada = celdaEn(tablero, 1, 1);

      expect(tablero.puedeColocar(ocupada, numero: 3, ancla: 1), isFalse);
      mostrar('(1,1) ya tiene ${ocupada.numero}: no se puede colocar.');
    });

    test('respeta la regla del color de la region', () {
      final tablero = crearTableroConIniciales();
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

    test('destinosValidos lista todas las casillas posibles', () {
      final tablero = crearTableroConIniciales();

      final destinos = tablero.destinosValidos(numero: 5, ancla: 1);

      expect(destinos, {celdaEn(tablero, 1, 0), celdaEn(tablero, 0, 1)});
      mostrar(
        'Destinos para 5 con ancla 1: '
        '${destinos.map((c) => '(${c.coordenada.x},${c.coordenada.y})').join(' ')}.',
      );
    });
  });

  group('TurnoBloc', () {
    test('inicia sin dados en el turno 0', () {
      final bloc = TurnoBloc(crearTableroConIniciales());

      expect(bloc.state.dadosTirados, isFalse);
      expect(bloc.state.turno, 0);
      mostrar(
        'Antes de empezar: (${bloc.state.primero}, ${bloc.state.segundo}), '
        'turno ${bloc.state.turno}.',
      );

      bloc.close();
    });

    test('al iniciar el turno los dados se tiran solos', () async {
      final bloc = TurnoBloc(
        crearTableroConIniciales(),
        azar: AzarFijo([1, 5]),
      );

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;

      expect(bloc.state.turno, 1);
      expect(bloc.state.primero, 1);
      expect(bloc.state.segundo, 5);
      mostrar(
        'Turno ${bloc.state.turno}: dados (${bloc.state.primero}, '
        '${bloc.state.segundo}).',
      );

      await bloc.close();
    });

    test('cada tirada da dos valores del 1 al 6', () async {
      final bloc = TurnoBloc(crearTableroConIniciales(), azar: Random(7));

      for (var tirada = 1; tirada <= 50; tirada++) {
        bloc.add(const TurnoPasado());
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

    test('colocar un dado valido pone el numero y empieza otro turno',
        () async {
      final tablero = crearTableroConIniciales();
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
    });

    test('colocar en una casilla invalida no cambia nada', () async {
      final tablero = crearTableroConIniciales();
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
      final tablero = crearTableroConIniciales();
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

    testWidgets('una celda valida recibe el dado', (tester) async {
      final recibido = await soltarDadoSobreCelda(
        tester,
        esDestinoValido: true,
      );

      expect(recibido, 1);
      mostrar('Celda valida recibio el dado $recibido.');
    });

    testWidgets('una celda no valida rechaza el dado', (tester) async {
      final recibido = await soltarDadoSobreCelda(
        tester,
        esDestinoValido: false,
      );

      expect(recibido, isNull);
      mostrar('Celda no valida no recibio nada ($recibido).');
    });
  });

  testWidgets('al presionar Listo empieza el turno 1 con los dados tirados',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));

    expect(find.byType(DadosWidget), findsNothing);

    final celdasIniciales = find.byWidgetPredicate(
      (widget) => widget is CeldaWidget && widget.esInicial,
    );
    const numeros = [1, 2, 3, 5, 6];

    for (var indice = 0; indice < numeros.length; indice++) {
      await tester.tap(celdasIniciales.at(indice + 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${numeros[indice]}').last);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Listo'));
    await tester.pumpAndSettle();

    final dados = tester.widgetList<DadoWidget>(find.byType(DadoWidget));
    expect(find.text('Turno 1'), findsOneWidget);
    expect(dados, hasLength(2));
    expect(dados.every((dado) => dado.valor != null), isTrue);
    mostrar(
      'Turno 1 empezo solo con dados ${dados.map((dado) => dado.valor).join(' y ')}.',
    );
  });
}
