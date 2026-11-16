import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/widgets/celebracion_widget.dart';
import 'package:proyecto_bloques/widgets/tablero_widget.dart';
import 'ayudantes.dart';
import 'consola.dart';

void main() {
  testWidgets(
    'al completar una region brillan sus casillas y salen los puntos',
    (tester) async {
      final tablero = mapaClasico.crearTablero();
      final region = tablero.regiones.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              tablero: tablero,
              destello: Destello(id: 1, regionId: region.id, puntos: 5),
            ),
          ),
        ),
      );

      expect(
        find.byType(DestelloCelda),
        findsNWidgets(region.coordenadas.length),
      );
      expect(find.text('+5'), findsOneWidget);
      await tester.pumpAndSettle();
      mostrar(
        'La region ${region.id} brilla en sus ${region.coordenadas.length} '
        'casillas y aparece +5.',
      );
    },
  );

  testWidgets('sin puntos no sale el +0', (tester) async {
    final tablero = mapaClasico.crearTablero();
    final region = tablero.regiones.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableroWidget(
            tablero: tablero,
            destello: Destello(id: 1, regionId: region.id, puntos: 0),
          ),
        ),
      ),
    );

    expect(find.byType(DestelloCelda), findsWidgets);
    expect(find.byType(PuntosFlotantes), findsNothing);
    await tester.pumpAndSettle();
    mostrar('Region sin puntos: brilla pero no muestra +0.');
  });

  testWidgets('el confeti cae y termina solo', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Confeti())));
    expect(find.byKey(const ValueKey('confeti')), findsOneWidget);
    await tester.pumpAndSettle();
    mostrar('El confeti se dibuja y su animacion termina.');
  });
}
