import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/tablero_widget.dart';

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
  });
}