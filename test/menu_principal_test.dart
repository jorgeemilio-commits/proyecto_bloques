import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/main.dart';
import 'consola.dart';

void main() {
  testWidgets('menu -> Jugar -> elegir mapa -> partida, y regresar', (
    tester,
  ) async {
    await tester.pumpWidget(const ProyectoBloquesApp());

    // La app empieza en el menu principal.
    expect(find.byKey(const ValueKey('menu-principal')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('boton-jugar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seleccion-mapa')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapa-clasico')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mapa-clasico')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pantalla-principal')), findsOneWidget);
    expect(find.text('Valores iniciales'), findsOneWidget);

    // La flecha de atras regresa a la seleccion de mapa.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seleccion-mapa')), findsOneWidget);
    expect(find.byKey(const ValueKey('pantalla-principal')), findsNothing);

    mostrar('Menu -> Jugar -> Clasico -> partida, y atras a elegir mapa.');
  });
}
