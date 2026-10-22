import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/pantallas/partida.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'ayudantes.dart';
import 'consola.dart';

Tablero crearTableroVacio() => mapaClasico.crearTablero();

// Numeros de la rueda que esta abierta: cada numero del tablero aparece una
// vez, asi que los que aparecen una vez mas son botones de la rueda.
List<int> numerosEnLaRueda(Map<int, int> antesDeAbrir) => [
  for (var numero = 1; numero <= 6; numero++)
    if (find.text('$numero').evaluate().length > (antesDeAbrir[numero] ?? 0))
      numero,
];

Map<int, int> contarNumerosEnPantalla() => {
  for (var numero = 1; numero <= 6; numero++)
    numero: find.text('$numero').evaluate().length,
};

void main() {
  group('Numeros iniciales aleatorios', () {
    test('llena las seis casillas con 1 a 6 sin repetir', () {
      final bloc = ValoresInicialesBloc(crearTableroVacio());

      bloc.llenarAleatorio(Random(3));

      expect(bloc.estado.estanCompletos, isTrue);
      expect(bloc.estado.valores.toSet(), {1, 2, 3, 4, 5, 6});
      expect(bloc.estado.puedeAvanzar, isTrue);
      mostrar('Valores aleatorios: ${bloc.estado.valores}.');
    });

    test('no cambia nada despues de confirmar', () {
      final tablero = crearTableroVacio();
      for (var indice = 0; indice < 6; indice++) {
        tablero.celdasIniciales[indice].numero = indice + 1;
      }
      final bloc = ValoresInicialesBloc(tablero)..avanzar();

      bloc.llenarAleatorio(Random(9));

      expect(bloc.estado.valores, [1, 2, 3, 4, 5, 6]);
      mostrar('Tras confirmar, siguen ${bloc.estado.valores}.');
    });

    testWidgets('el boton aleatorio llena las casillas y habilita Listo', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: VistaPreviaTablero(mapa: mapaClasico)),
      );

      await tester.tap(find.byTooltip('Números aleatorios'));
      await tester.pumpAndSettle();

      final valores = [
        for (final celda in tester.widgetList<CeldaWidget>(
          find.byWidgetPredicate(
            (widget) => widget is CeldaWidget && widget.esInicial,
          ),
        ))
          celda.celda.numero,
      ];
      final listo = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Listo'),
      );

      expect(valores.toSet(), {1, 2, 3, 4, 5, 6});
      expect(listo.onPressed, isNotNull);
      mostrar('Boton aleatorio: casillas $valores y Listo habilitado.');
    });
  });

  group('Rueda de numeros', () {
    testWidgets('no ofrece los numeros de otras casillas iniciales', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: VistaPreviaTablero(mapa: mapaClasico)),
      );
      final celdasIniciales = find.byWidgetPredicate(
        (widget) => widget is CeldaWidget && widget.esInicial,
      );

      // La primera casilla empieza con 4; se pone un 2 en la segunda.
      await tester.tap(celdasIniciales.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2').last);
      await tester.pumpAndSettle();

      final antes = contarNumerosEnPantalla();
      await tester.tap(celdasIniciales.at(2));
      await tester.pumpAndSettle();
      final ofrecidos = numerosEnLaRueda(antes);

      expect(ofrecidos, [1, 3, 5, 6]);
      mostrar('Con 4 y 2 puestos, la rueda de la tercera ofrece $ofrecidos.');
    });

    testWidgets('al borrar un numero vuelve a ofrecerse', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: VistaPreviaTablero(mapa: mapaClasico)),
      );
      final celdasIniciales = find.byWidgetPredicate(
        (widget) => widget is CeldaWidget && widget.esInicial,
      );

      // Se borra el 4 de la primera casilla.
      await tester.tap(celdasIniciales.first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Borrar'));
      await tester.pumpAndSettle();

      final antes = contarNumerosEnPantalla();
      await tester.tap(celdasIniciales.at(1));
      await tester.pumpAndSettle();
      final ofrecidos = numerosEnLaRueda(antes);

      expect(ofrecidos, [1, 2, 3, 4, 5, 6]);
      mostrar('Tras borrar el 4, la rueda ofrece $ofrecidos.');
    });
  });

  group('Reglas de las regiones en la fase inicial', () {
    // En Bases, (4,0) es de la naranja de arriba (4-6), (1,6) de la de abajo
    // (1-3) y (2,2) de la lila, que acepta cualquier numero si esta sola.
    Celda inicialEn(Tablero tablero, int x, int y) => tablero.celdasIniciales
        .firstWhere((c) => c.coordenada.x == x && c.coordenada.y == y);

    test('una casilla inicial solo acepta lo que permite su region', () {
      final tablero = mapaBases.crearTablero();

      final naranjaAlta = tablero.numerosPermitidosEnInicial(
        inicialEn(tablero, 4, 0),
      );
      final naranjaBaja = tablero.numerosPermitidosEnInicial(
        inicialEn(tablero, 1, 6),
      );
      final lila = tablero.numerosPermitidosEnInicial(inicialEn(tablero, 2, 2));

      expect(naranjaBaja, {1, 2, 3});
      expect(naranjaAlta, {4, 5, 6});
      expect(lila, {1, 2, 3, 4, 5, 6});
      mostrar('Naranja 1-3: $naranjaBaja; naranja 4-6: $naranjaAlta.');
    });

    test('el boton aleatorio respeta las reglas de las regiones', () {
      final repartos = <List<int?>>[];
      for (var semilla = 0; semilla < 30; semilla++) {
        final tablero = mapaBases.crearTablero();
        final bloc = ValoresInicialesBloc(tablero)
          ..llenarAleatorio(Random(semilla));

        expect(bloc.estado.valores.toSet(), {1, 2, 3, 4, 5, 6});
        expect(inicialEn(tablero, 4, 0).numero, inInclusiveRange(4, 6));
        expect(inicialEn(tablero, 1, 6).numero, inInclusiveRange(1, 3));
        expect(bloc.estado.puedeAvanzar, isTrue);
        repartos.add(bloc.estado.valores);
      }
      mostrar('30 repartos validos; por ejemplo ${repartos.first}.');
    });

    test('un numero fuera de la regla de su region bloquea Listo', () {
      final tablero = mapaBases.crearTablero();
      // Numeros del 1 al 6 sin repetir, pero el 2 cae en la naranja de
      // arriba, que es de 4 a 6.
      const valores = {
        (4, 0): 2,
        (2, 2): 4,
        (5, 2): 6,
        (0, 3): 1,
        (4, 5): 5,
        (1, 6): 3,
      };
      for (final MapEntry(key: (x, y), value: numero) in valores.entries) {
        inicialEn(tablero, x, y).numero = numero;
      }
      final bloc = ValoresInicialesBloc(tablero);

      expect(bloc.estado.cumplenRegiones, isFalse);
      expect(bloc.estado.puedeAvanzar, isFalse);
      expect(bloc.avanzar(), isFalse);
      expect(
        bloc.estado.mensajeError,
        'Hay un numero que no cumple la regla de su region.',
      );
      mostrar(
        'Un 2 en la naranja de arriba (4-6) -> "${bloc.estado.mensajeError}"',
      );
    });

    testWidgets('la rueda solo ofrece numeros que permite la region', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: VistaPreviaTablero(mapa: mapaBases)),
      );

      Future<List<int>> numerosDeLaRueda(int x, int y) async {
        await tester.tap(find.byKey(ValueKey('celda-$x-$y')));
        await tester.pumpAndSettle();
        final ofrecidos = [
          for (var numero = 1; numero <= 6; numero++)
            if (find
                .byKey(ValueKey('rueda-numero-$numero'))
                .evaluate()
                .isNotEmpty)
              numero,
        ];
        // Cierra la rueda tocando fuera de ella.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        return ofrecidos;
      }

      // El 4 de entrada cae en la (4,0), la naranja de arriba (4-6).
      final naranjaAlta = await numerosDeLaRueda(4, 0);
      final naranjaBaja = await numerosDeLaRueda(1, 6);

      expect(naranjaAlta, [4, 5, 6]);
      expect(naranjaBaja, [1, 2, 3]);
      mostrar(
        'Rueda en la naranja 4-6: $naranjaAlta (con el 4 de entrada); en la '
        '1-3: $naranjaBaja.',
      );
    });
  });
}
