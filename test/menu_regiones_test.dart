import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/main.dart' show VistaPreviaTablero;
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/menu_regiones_widget.dart';
import 'consola.dart';

void main() {
  testWidgets('la pestaña abre y cierra el panel de regiones', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));
    // El juego vive en una columna con ancho de telefono; el panel cerrado
    // queda justo a la derecha de esa columna.
    final bordeDerecho = tester
        .getTopRight(find.byKey(const ValueKey('panel-lateral')))
        .dx;
    double bordeDelPanel() =>
        tester.getTopLeft(find.byKey(const ValueKey('menu-regiones'))).dx;

    final cerrado = bordeDelPanel();
    await tester.tap(find.byKey(const ValueKey('pestana-panel')));
    await tester.pumpAndSettle();
    final abierto = bordeDelPanel();
    await tester.tap(find.byKey(const ValueKey('pestana-panel')));
    await tester.pumpAndSettle();

    expect(cerrado, greaterThanOrEqualTo(bordeDerecho));
    expect(abierto, lessThan(bordeDerecho));
    expect(bordeDelPanel(), cerrado);
    mostrar(
      'Borde del panel: cerrado en x=${cerrado.round()}, abierto en '
      'x=${abierto.round()} (borde de la columna en ${bordeDerecho.round()}).',
    );
  });

  testWidgets('los premios y el color siguen a los reclamos de cada region', (
    tester,
  ) async {
    final registro = RegistroDeReclamos();
    Future<void> dibujar() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuRegionesWidget(
            regiones: regionesMapa,
            vecesReclamada: registro.vecesReclamada,
          ),
        ),
      ),
    );

    // Premio resaltado (el que se gana ahora) y color de la muestra de la
    // fila [indice].
    (String?, Color?) actual(int indice) {
      final fila = find.byKey(ValueKey('menu-region-$indice'));
      final resaltado = find.descendant(
        of: fila,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.color == Colors.amber.shade300,
        ),
      );
      final muestra = tester
          .widgetList<Container>(
            find.descendant(of: fila, matching: find.byType(Container)),
          )
          .first;
      return (
        resaltado.evaluate().isEmpty
            ? null
            : tester
                  .widget<Text>(
                    find.descendant(of: resaltado, matching: find.byType(Text)),
                  )
                  .data,
        (muestra.decoration as BoxDecoration?)?.color,
      );
    }

    // regionesMapa[0] es AzulUno y regionesMapa[1] es AzulDos.
    final vistos = <String?>[];
    for (var reclamo = 0; reclamo <= 3; reclamo++) {
      await dibujar();
      final (premio, color) = actual(0);
      vistos.add(premio);
      expect(color, colorDeRegion(TipoRegion.azul, vecesReclamada: reclamo));
      registro.reclamar(const RegionAzulUno());
    }

    expect(vistos, ['7', '5', '3', null]);
    expect(find.text('Ya no da puntos.'), findsOneWidget);
    // AzulDos tiene sus propios reclamos y sigue en su primer premio.
    expect(actual(1).$1, '7');
    mostrar(
      'Premio resaltado de AzulUno tras cada reclamo: $vistos; '
      'AzulDos sigue en ${actual(1).$1}.',
    );
  });
}
