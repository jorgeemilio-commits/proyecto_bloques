import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/tablero_widget.dart';
import 'consola.dart';

void main() {
  testWidgets('muestra todas las celdas y marca las iniciales', (tester) async {
    final tablero = Tablero.desdeRegiones(
      filas: 7,
      columnas: 7,
      regiones: regionesMapa,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TableroWidget(tablero: tablero)),
      ),
    );

    expect(find.byType(CeldaWidget), findsNWidgets(49));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CeldaWidget && widget.esInicial,
      ),
      findsNWidgets(6),
    );
    mostrar('49 celdas dibujadas y 6 marcadas como iniciales.');
  });

  testWidgets('notifica la celda pulsada', (tester) async {
    final tablero = Tablero.desdeRegiones(
      filas: 7,
      columnas: 7,
      regiones: const [],
    );
    Celda? celdaPulsada;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableroWidget(
            tablero: tablero,
            onCeldaTap: (celda) => celdaPulsada = celda,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CeldaWidget).first);

    expect(celdaPulsada, same(tablero.celdas[0][0]));
    mostrar(
      'Celda pulsada: (${celdaPulsada!.coordenada.x}, ${celdaPulsada!.coordenada.y}).',
    );
  });

  group('Regiones con rayas', () {
    test('de cada par del mismo color solo la segunda lleva rayas', () {
      final conRayas = {
        for (final region in regionesMapa)
          region.runtimeType.toString(): region.conRayas,
      };

      expect(conRayas, {
        'RegionAzulUno': false,
        'RegionAzulDos': true,
        'RegionRojaUno': false,
        'RegionRojaDos': true,
        'RegionVerdeUno': false,
        'RegionVerdeDos': true,
        'RegionLilaUno': false,
        'RegionLilaDos': true,
        'RegionAmarilla': false,
      });
      mostrar(
        'Con rayas: '
        '${conRayas.entries.where((e) => e.value).map((e) => e.key).join(', ')}.',
      );
    });

    testWidgets('solo las casillas de las regiones rayadas tienen rayas', (
      tester,
    ) async {
      final tablero = Tablero.desdeRegiones(
        filas: 7,
        columnas: 7,
        regiones: regionesMapa,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TableroWidget(tablero: tablero)),
        ),
      );

      bool tieneRayas(int x, int y) => find
          .descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is CeldaWidget &&
                  widget.celda.coordenada.x == x &&
                  widget.celda.coordenada.y == y,
            ),
            matching: find.byKey(const ValueKey('rayas')),
          )
          .evaluate()
          .isNotEmpty;

      // AzulDos (4) + RojaDos (6) + VerdeDos (6) + LilaDos (6) = 22 casillas.
      expect(find.byKey(const ValueKey('rayas')), findsNWidgets(22));
      expect(tieneRayas(6, 4), isTrue); // AzulDos
      expect(tieneRayas(2, 0), isFalse); // AzulUno
      expect(tieneRayas(3, 3), isFalse); // Amarilla
      mostrar('22 casillas con rayas; AzulDos si, AzulUno y Amarilla no.');
    });
  });
}
