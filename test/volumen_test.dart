import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/sonidos.dart';
import 'package:proyecto_bloques/widgets/volumen_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consola.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Sonidos.volumenMusica.value = 1;
    Sonidos.volumenEfectos.value = 1;
  });

  Future<void> abrirVentana(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BotonVolumen())),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('boton-volumen')));
    await tester.pumpAndSettle();
  }

  testWidgets('el boton abre la ventana con las dos barras', (tester) async {
    await abrirVentana(tester);

    expect(find.byKey(const ValueKey('ventana-volumen')), findsOneWidget);
    expect(find.byKey(const ValueKey('barra-musica')), findsOneWidget);
    expect(find.byKey(const ValueKey('barra-efectos')), findsOneWidget);
    expect(find.text('100%'), findsNWidgets(2));
    mostrar('Ventana de volumen con barras de musica y efectos al 100%.');
  });

  testWidgets('silenciar la musica la pone en 0 y se guarda', (tester) async {
    await abrirVentana(tester);

    await tester.tap(find.byKey(const ValueKey('silenciar-musica')));
    await tester.pump();

    expect(Sonidos.volumenMusica.value, 0);
    expect(Sonidos.volumenEfectos.value, 1);
    expect(find.text('0%'), findsOneWidget);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getDouble('volumenMusica'), 0);

    // Al volver a tocarlo regresa al volumen que tenia.
    await tester.tap(find.byKey(const ValueKey('silenciar-musica')));
    await tester.pump();
    expect(Sonidos.volumenMusica.value, 1);
    mostrar('Silenciar pone la musica en 0, se guarda y se puede regresar.');
  });

  testWidgets('con todo en silencio el boton muestra la bocina tachada', (
    tester,
  ) async {
    Sonidos.volumenMusica.value = 0;
    Sonidos.volumenEfectos.value = 0;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BotonVolumen())),
    );

    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    mostrar('Todo en silencio: el boton muestra la bocina tachada.');
  });

  test('cargarVolumen lee lo guardado', () async {
    SharedPreferences.setMockInitialValues({
      'volumenMusica': 0.25,
      'volumenEfectos': 0.5,
    });
    await Sonidos.cargarVolumen();

    expect(Sonidos.volumenMusica.value, 0.25);
    expect(Sonidos.volumenEfectos.value, 0.5);
    mostrar('Al abrir la app se recupera el volumen guardado.');
  });
}
