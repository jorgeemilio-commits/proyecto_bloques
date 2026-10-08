import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/main.dart' show VistaPreviaTablero;
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/dados_widget.dart';

void main() {
  group('DadosBloc', () {
    test('inicia sin tirar', () {
      final bloc = DadosBloc();

      expect(bloc.state.fueronTirados, isFalse);
      expect(bloc.state.primero, isNull);
      expect(bloc.state.segundo, isNull);
      expect(bloc.state.tiradas, 0);

      bloc.close();
    });

    test('cada tirada da dos valores del 1 al 6', () async {
      final bloc = DadosBloc(azar: Random(7));

      for (var tirada = 1; tirada <= 50; tirada++) {
        bloc.add(const DadosTirados());
        await bloc.stream.first;

        expect(bloc.state.fueronTirados, isTrue);
        expect(bloc.state.primero, inInclusiveRange(1, 6));
        expect(bloc.state.segundo, inInclusiveRange(1, 6));
        expect(bloc.state.tiradas, tirada);
      }

      await bloc.close();
    });
  });

  testWidgets('los dados solo aparecen despues de iniciar la partida',
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

    expect(find.byType(DadosWidget), findsOneWidget);
    var dados = tester.widgetList<DadoWidget>(find.byType(DadoWidget));
    expect(dados.every((dado) => dado.valor == null), isTrue);

    await tester.tap(find.text('Tirar dados'));
    await tester.pumpAndSettle();

    dados = tester.widgetList<DadoWidget>(find.byType(DadoWidget));
    expect(dados, hasLength(2));
    expect(dados.every((dado) => dado.valor != null), isTrue);
  });
}
