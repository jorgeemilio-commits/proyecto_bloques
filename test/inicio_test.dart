import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/main.dart' show VistaPreviaTablero;
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'consola.dart';

Tablero crearTableroVacio() =>
    Tablero.desdeRegiones(filas: 7, columnas: 7, regiones: regionesMapa);

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

    test('reemplaza los numeros que ya estaban puestos', () {
      final tablero = crearTableroVacio();
      for (final celda in tablero.celdasIniciales) {
        celda.numero = 1;
      }
      final bloc = ValoresInicialesBloc(tablero);

      bloc.llenarAleatorio(Random(5));

      expect(bloc.estado.noHayRepetidos, isTrue);
      mostrar('De [1, 1, 1, 1, 1, 1] a ${bloc.estado.valores}.');
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
      await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));

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
      await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));
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
      await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));
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
}
