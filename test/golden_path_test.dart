import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/pantallas/partida.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/dados_widget.dart';
import 'ayudantes.dart';
import 'consola.dart';

// Golden path: el recorrido feliz de un jugador de principio a fin
// Si ningun dado tiene destino, pasa el turno.
// Limite de turnos para completar una region; evita que la prueba se cuelgue.

const int maximoDeTurnos = 300;

String textoDe(WidgetTester tester, String llave) =>
    tester.widget<Text>(find.byKey(ValueKey(llave))).data ?? '';

Finder celdaEn(int x, int y) => find.byKey(ValueKey('celda-$x-$y'));

List<CeldaWidget> celdasDibujadas(WidgetTester tester) =>
    tester.widgetList<CeldaWidget>(find.byType(CeldaWidget)).toList();

int? valorDelDado(WidgetTester tester, int indice) => tester
    .widget<DadoWidget>(
      find.descendant(
        of: find.byKey(ValueKey('dado-$indice')),
        matching: find.byType(DadoWidget),
      ),
    )
    .valor;

// Casillas vacias que le faltan a la region de [celda] para completarse.
int vaciasEnSuRegion(WidgetTester tester, CeldaWidget celda) =>
    celdasDibujadas(tester)
        .where(
          (otra) => otra.region == celda.region && otra.celda.numero == null,
        )
        .length;

// Resultado de una jugada: que dado se uso, cuanto valia y donde se puso.
typedef Jugada = ({int dado, int valor, CeldaWidget destino});

// Intenta jugar un turno arrastrando un dado a la mejor casilla resaltada.
// Devuelve la jugada hecha, o null si ningun dado tenia destino.
Future<Jugada?> intentarJugada(WidgetTester tester) async {
  for (final indice in [0, 1]) {
    final valor = valorDelDado(tester, indice)!;
    final dado = find.byKey(ValueKey('dado-$indice'));

    // Levanta el dado: la app resalta las casillas validas.
    final gesto = await tester.startGesture(tester.getCenter(dado));
    await gesto.moveBy(const Offset(0, -20));
    await tester.pump();
    await tester.pump();

    final destinos = celdasDibujadas(
      tester,
    ).where((celda) => celda.esDestinoValido).toList();

    if (destinos.isEmpty) {
      // Sin destino: se suelta el dado donde estaba y se prueba el otro.
      await gesto.moveTo(tester.getCenter(dado));
      await gesto.up();
      await tester.pumpAndSettle();
      continue;
    }

    // Elige la casilla cuya region esta mas cerca de completarse.
    destinos.sort(
      (a, b) => vaciasEnSuRegion(tester, a) - vaciasEnSuRegion(tester, b),
    );
    final destino = destinos.first;
    final coordenada = destino.celda.coordenada;

    await gesto.moveTo(tester.getCenter(celdaEn(coordenada.x, coordenada.y)));
    await tester.pump();
    await gesto.up();
    await tester.pumpAndSettle();

    return (dado: indice, valor: valor, destino: destino);
  }

  return null;
}

void main() {
  testWidgets('golden path: de abrir la app a completar una region', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: VistaPreviaTablero(mapa: mapaClasico)),
    );

    // 1. Al abrir: fase de valores iniciales y Listo desactivado.
    expect(textoDe(tester, 'titulo-fase'), 'Valores iniciales');
    expect(textoDe(tester, 'marcador'), '1/6');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('boton-listo')))
          .onPressed,
      isNull,
    );
    mostrar('1. App abierta: "Valores iniciales", 1/6, Listo desactivado.');

    // 2. Llena las casillas iniciales con la rueda. La (2,0) ya tiene el 4.
    const iniciales = [
      ((5, 1), 1),
      ((1, 3), 2),
      ((4, 3), 3),
      ((2, 5), 5),
      ((4, 6), 6),
    ];
    for (final ((x, y), numero) in iniciales) {
      await tester.tap(celdaEn(x, y));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('rueda-numero-$numero')));
      await tester.pumpAndSettle();
    }
    expect(textoDe(tester, 'marcador'), '6/6');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('boton-listo')))
          .onPressed,
      isNotNull,
    );
    mostrar('2. Casillas iniciales llenas con la rueda: 4, 1, 2, 3, 5, 6.');

    // 3. Presiona Listo: empieza el Turno 1 y los dados se tiran solos.
    await tester.tap(find.byKey(const ValueKey('boton-listo')));
    await tester.pumpAndSettle();

    expect(textoDe(tester, 'titulo-fase'), 'Turno 1');
    expect(textoDe(tester, 'marcador'), '0 pts');
    expect(find.byKey(const ValueKey('boton-listo')), findsNothing);
    expect(find.byKey(const ValueKey('boton-pasar')), findsOneWidget);
    expect(valorDelDado(tester, 0), isNotNull);
    expect(valorDelDado(tester, 1), isNotNull);
    expect(
      celdasDibujadas(
        tester,
      ).where((celda) => celda.esInicial).every((c) => !c.celda.esInsertable),
      isTrue,
    );
    mostrar(
      '3. Listo: Turno 1 con dados (${valorDelDado(tester, 0)}, '
      '${valorDelDado(tester, 1)}) y casillas iniciales bloqueadas.',
    );

    // 4 y 5. Juega turnos arrastrando dados hasta completar una region.
    var turno = 1;
    var jugadas = 0;
    var pases = 0;

    while (textoDe(tester, 'marcador') == '0 pts') {
      expect(
        turno,
        lessThan(maximoDeTurnos),
        reason: 'No se completo ninguna region en $maximoDeTurnos turnos.',
      );

      final jugada = await intentarJugada(tester);
      if (jugada == null) {
        // Ningun dado tenia destino: el jugador pasa.
        await tester.tap(find.byKey(const ValueKey('boton-pasar')));
        await tester.pumpAndSettle();
        pases++;
      } else {
        // El numero del dado quedo en la casilla elegida.
        expect(jugada.destino.celda.numero, jugada.valor);
        jugadas++;
        if (jugadas == 1) {
          final c = jugada.destino.celda.coordenada;
          mostrar(
            '4-5. Primera jugada: dado-${jugada.dado} (${jugada.valor}) '
            'arrastrado a celda-${c.x}-${c.y}.',
          );
        }
      }

      turno++;
      expect(textoDe(tester, 'titulo-fase'), 'Turno $turno');
    }

    // 6. Se completo una region: puntos, aviso y region apagada.
    final marcador = textoDe(tester, 'marcador');
    final mensaje = textoDe(tester, 'mensaje');
    final puntos = int.parse(marcador.split(' ').first);
    final apagadas = celdasDibujadas(
      tester,
    ).where((celda) => celda.vecesReclamada == 1).toList();
    final region = apagadas.first.region!;

    expect(puntos, region.tipo.puntuaciones[1]);
    expect(
      mensaje,
      '¡Completaste una región ${region.tipo.nombre}! +$puntos puntos.',
    );
    expect(apagadas, hasLength(region.coordenadas.length));
    expect(apagadas.every((celda) => celda.celda.numero != null), isTrue);
    mostrar(
      '6. Turno $turno: region ${region.tipo.nombre} completa tras $jugadas '
      'jugadas y $pases pases; marcador "$marcador", mensaje "$mensaje", '
      '${apagadas.length} casillas apagadas.',
    );
  });
}
