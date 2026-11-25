import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/configuracion.dart';
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
        home: Scaffold(body: Center(child: BotonConfiguracion())),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('boton-configuracion')));
    await tester.pumpAndSettle();
  }

  testWidgets('el boton abre la ventana con las dos barras', (tester) async {
    await abrirVentana(tester);

    expect(find.byKey(const ValueKey('ventana-configuracion')), findsOneWidget);
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

  testWidgets('el modo de control: tocar el ancla por defecto, y se guarda', (
    tester,
  ) async {
    Configuracion.modoDeControl.value = ModoDeControl.tocarAncla;
    await abrirVentana(tester);
    final porDefecto = Configuracion.modoDeControl.value;

    await tester.tap(find.text('Arrastrar'));
    await tester.pump();
    final preferencias = await SharedPreferences.getInstance();

    expect(porDefecto, ModoDeControl.tocarAncla);
    expect(Configuracion.modoDeControl.value, ModoDeControl.arrastrar);
    expect(preferencias.getString('modoDeControl'), 'arrastrar');
    // Al abrir la app otra vez se lee lo guardado.
    Configuracion.modoDeControl.value = ModoDeControl.tocarAncla;
    await Configuracion.cargar();
    expect(Configuracion.modoDeControl.value, ModoDeControl.arrastrar);
    mostrar('Modo de control: tocar por defecto; elegir arrastrar se guarda.');
  });

  test('sin volumen guardado, la musica y los efectos empiezan en 0', () async {
    Sonidos.volumenMusica.value = 0.7;
    Sonidos.volumenEfectos.value = 0.7;
    await Sonidos.cargarVolumen();

    expect(Sonidos.volumenMusica.value, 0);
    expect(Sonidos.volumenEfectos.value, 0);
    mostrar('La primera vez que se abre la app el sonido esta silenciado.');
  });

  testWidgets('silenciado por defecto, el boton lo activa al 100%', (
    tester,
  ) async {
    Sonidos.volumenMusica.value = 0;
    await abrirVentana(tester);

    await tester.tap(find.byKey(const ValueKey('silenciar-musica')));
    await tester.pump();
    expect(Sonidos.volumenMusica.value, 1);
    mostrar('Con la musica silenciada, tocar el boton la pone al 100%.');
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
