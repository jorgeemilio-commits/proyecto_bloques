import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/numero_celda_bloc.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';

void main() {
  testWidgets('muestra una celda inicial con su numero', (tester) async {
    final celda = Celda(coordenada: const Coordenada(0, 0), numero: 4);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CeldaWidget(
            celda: celda,
            region: null,
            esInicial: true,
          ),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('permite reaccionar al toque', (tester) async {
    var fuePulsada = false;
    final celda = Celda(
      coordenada: const Coordenada(1, 1),
      esInsertable: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CeldaWidget(
            celda: celda,
            region: null,
            onTap: () => fuePulsada = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CeldaWidget));

    expect(fuePulsada, isTrue);
  });

  testWidgets('permite insertar un numero mediante el selector', (tester) async {
    final celda = Celda(
      coordenada: const Coordenada(0, 0),
      esInsertable: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CeldaWidget(
            celda: celda,
            region: null,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CeldaWidget));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(celda.numero, 5);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('no permite editar una celda que no es inicial', (tester) async {
    var fuePulsada = false;
    final celda = Celda(coordenada: const Coordenada(1, 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CeldaWidget(
            celda: celda,
            region: null,
            onTap: () => fuePulsada = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CeldaWidget));
    await tester.pumpAndSettle();

    expect(fuePulsada, isFalse);
    expect(find.text('1'), findsNothing);
    expect(find.byTooltip('Borrar'), findsNothing);
    expect(celda.numero, isNull);
  });

  test('el bloc rechaza insertar y borrar en una celda no insertable', () async {
    final celda = Celda(coordenada: const Coordenada(1, 1), numero: 4);
    final bloc = NumeroCeldaBloc(celda);

    bloc.add(const NumeroCeldaSeleccionado(2));
    bloc.add(const NumeroCeldaBorrado());
    await bloc.close();

    expect(celda.numero, 4);
  });
}