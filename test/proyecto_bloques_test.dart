import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/main.dart' show VistaPreviaTablero;
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/menu_casilla_widget.dart';
import 'consola.dart';

Tablero crearTableroDePrueba() {
  return Tablero.desdeRegiones(filas: 7, columnas: 7, regiones: const []);
}

void main() {
  testWidgets('muestra las reglas y desactiva Listo al iniciar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));

    expect(
      find.text(
        'Completa las seis casillas iniciales con números distintos del 1 al 6.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Listo'))
          .onPressed,
      isNull,
    );
    mostrar('Al iniciar, Listo esta desactivado y se muestra la instruccion.');
  });

  testWidgets(
    'habilita Listo con valores distintos y la rueda oculta los ya usados',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));

      final celdasIniciales = find.byWidgetPredicate(
        (widget) => widget is CeldaWidget && widget.esInicial,
      );
      const numerosUnicos = [1, 2, 3, 5, 6];

      for (var indice = 0; indice < numerosUnicos.length; indice++) {
        await tester.tap(celdasIniciales.at(indice + 1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${numerosUnicos[indice]}').last);
        await tester.pumpAndSettle();
      }

      final botonListo = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Listo'),
      );
      expect(botonListo.onPressed, isNotNull);

      // La ultima casilla tiene el 6: su rueda solo ofrece el 6, porque los
      // demas numeros ya estan en otras casillas iniciales.
      await tester.tap(celdasIniciales.last);
      await tester.pumpAndSettle();

      final ofrecidos = [
        for (var numero = 1; numero <= 6; numero++)
          // Cada numero aparece una vez en el tablero; si aparece dos veces,
          // la otra es su boton en la rueda.
          if (find.text('$numero').evaluate().length == 2) numero,
      ];
      expect(ofrecidos, [6]);
      mostrar(
        'Con 4,1,2,3,5,6 Listo se habilita; la rueda de la ultima casilla '
        'solo ofrece $ofrecidos.',
      );
    },
  );

  testWidgets('Listo bloquea las casillas iniciales', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));

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

    // Al iniciar la partida el boton Listo se cambia por los dados.
    expect(find.text('Listo'), findsNothing);
    expect(find.text('Pasar'), findsOneWidget);
    expect(find.text('Turno 1'), findsOneWidget);

    final menuDeCasillaInicial = find.descendant(
      of: celdasIniciales.first,
      matching: find.byType(MenuCasillaWidget),
    );
    expect(
      tester.widget<MenuCasillaWidget>(menuDeCasillaInicial).esInsertable,
      isFalse,
    );

    await tester.tap(celdasIniciales.first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Borrar'), findsNothing);
    mostrar('Tras Listo: casillas iniciales bloqueadas y empieza el Turno 1.');
  });

  group('Validación de reglas por tipo de región', () {
    test('Rojo no permite duplicados ni repetidos', () {
      expect(TipoRegion.rojo.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.rojo.esPosibleAgregar([1, 2, 3], 4), isTrue);
      expect(TipoRegion.rojo.esPosibleAgregar([1, 2, 3, 4], 4), isFalse);
      expect(TipoRegion.rojo.esPosibleAgregar([1, 2, 4, 4], 5), isFalse);
      mostrar(
        'Rojo: [1,2,3]+4 -> ${TipoRegion.rojo.esPosibleAgregar([1, 2, 3], 4)}, [1,2,3,4]+4 -> ${TipoRegion.rojo.esPosibleAgregar([1, 2, 3, 4], 4)}.',
      );
    });

    test('Azul exige que todos los valores sean iguales', () {
      expect(TipoRegion.azul.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.azul.esPosibleAgregar([2, 2], 2), isTrue);
      expect(TipoRegion.azul.esPosibleAgregar([2, 2], 4), isFalse);
      expect(TipoRegion.azul.esPosibleAgregar([4, 4, 4, 4], 4), isTrue);
      mostrar(
        'Azul: [2,2]+2 -> ${TipoRegion.azul.esPosibleAgregar([2, 2], 2)}, [2,2]+4 -> ${TipoRegion.azul.esPosibleAgregar([2, 2], 4)}.',
      );
    });

    test('Verde siempre acepta cualquier valor', () {
      expect(TipoRegion.verde.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.verde.esPosibleAgregar([1, 2, 3], 4), isTrue);
      expect(TipoRegion.verde.esPosibleAgregar([4, 4, 4, 4], 5), isTrue);
      expect(TipoRegion.verde.esPosibleAgregar([1, 1, 1, 1], 1), isTrue);
      mostrar(
        'Verde: [4,4,4,4]+5 -> ${TipoRegion.verde.esPosibleAgregar([4, 4, 4, 4], 5)}.',
      );
    });

    test('Lila permite hasta dos números diferentes', () {
      expect(TipoRegion.lila.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.lila.esPosibleAgregar([5, 5], 5), isTrue);
      expect(TipoRegion.lila.esPosibleAgregar([1, 1, 2], 2), isTrue);
      expect(TipoRegion.lila.esPosibleAgregar([1, 2], 3), isFalse);
      expect(TipoRegion.lila.esPosibleAgregar([1, 2, 3], 1), isFalse);
      mostrar(
        'Lila: [1,1,2]+2 -> ${TipoRegion.lila.esPosibleAgregar([1, 1, 2], 2)}, [1,2]+3 -> ${TipoRegion.lila.esPosibleAgregar([1, 2], 3)}.',
      );
    });
  });

  group('Tipos y colores de región', () {
    test('Cada región concreta tiene el tipo correcto', () {
      expect(const RegionAzulUno().tipo, TipoRegion.azul);
      expect(const RegionRojaUno().tipo, TipoRegion.rojo);
      expect(const RegionVerdeUno().tipo, TipoRegion.verde);
      expect(const RegionLilaUno().tipo, TipoRegion.lila);
      expect(const RegionAmarilla().tipo, TipoRegion.amarillo);
      mostrar(
        'Tipos: azul, rojo, verde, lila y amarillo asignados a sus regiones.',
      );
    });

    test('Los colores de los tipos coinciden con los esperados', () {
      expect(TipoRegion.amarillo.color, const Color(0xFFFFFF00));
      expect(TipoRegion.azul.color, const Color(0xFF0000FF));
      expect(TipoRegion.rojo.color, const Color(0xFFFF0000));
      expect(TipoRegion.verde.color, const Color(0xFF00FF00));
      expect(TipoRegion.lila.color, const Color(0xFF800080));
      mostrar('Colores base verificados para los 5 tipos de region.');
    });
  });

  group('Coordenadas y tablero', () {
    test('Las regiones tienen coordenadas válidas', () {
      final regionAzul = const RegionAzulUno();
      final regionRoja = const RegionRojaUno();
      final regionAmarilla = const RegionAmarilla();

      expect(regionAzul.coordenadas, contains(const Coordenada(2, 0)));
      expect(regionRoja.coordenadas, contains(const Coordenada(1, 2)));
      expect(regionAmarilla.coordenadas, contains(const Coordenada(3, 3)));
      mostrar('(2,0) en azul, (1,2) en roja y (3,3) en amarilla.');
    });

    test('Tablero construye celdas y conserva las regiones por separado', () {
      final tablero = Tablero.desdeRegiones(
        filas: 7,
        columnas: 7,
        regiones: [
          const RegionAzulUno(),
          const RegionRojaUno(),
          const RegionAmarilla(),
        ],
      );

      expect(tablero.filas, 7);
      expect(tablero.columnas, 7);
      expect(tablero.celdas.length, 7);
      expect(tablero.celdas.every((fila) => fila.length == 7), isTrue);
      expect(tablero.celdasIniciales, hasLength(6));
      expect(
        tablero.celdasIniciales.every((celda) => celda.esInsertable),
        isTrue,
      );
      expect(
        tablero.celdas
            .expand((fila) => fila)
            .where((celda) => !tablero.celdasIniciales.contains(celda))
            .every((celda) => !celda.esInsertable),
        isTrue,
      );
      expect(tablero.regiones, hasLength(3));
      expect(
        tablero.obtenerRegion(const Coordenada(2, 0)),
        isA<RegionAzulUno>(),
      );
      expect(
        tablero.obtenerRegion(const Coordenada(1, 2)),
        isA<RegionRojaUno>(),
      );
      expect(
        tablero.obtenerRegion(const Coordenada(3, 3)),
        isA<RegionAmarilla>(),
      );
      expect(tablero.celdas[0][2].numero, isNull);
      expect(tablero.celdas[0][2].coordenada.x, 2);
      expect(tablero.celdas[0][2].coordenada.y, 0);
      expect(tablero.celdas[2][1].coordenada.x, 1);
      expect(tablero.celdas[2][1].coordenada.y, 2);
      expect(tablero.celdas[3][3].coordenada.x, 3);
      expect(tablero.celdas[3][3].coordenada.y, 3);
      mostrar(
        'Tablero ${tablero.filas}x${tablero.columnas}, ${tablero.celdasIniciales.length} iniciales, ${tablero.regiones.length} regiones.',
      );
    });
  });

  group('Valores iniciales', () {
    test('No permite avanzar con un tablero vacio', () {
      final tablero = crearTableroDePrueba();
      final bloc = ValoresInicialesBloc(tablero);

      expect(bloc.estado.valores, everyElement(isNull));
      expect(bloc.estado.estanCompletos, isFalse);
      expect(bloc.estado.puedeAvanzar, isFalse);
      expect(bloc.avanzar(), isFalse);
      expect(
        bloc.estado.mensajeError,
        'Debes completar las seis celdas iniciales.',
      );
      mostrar(
        'Valores ${bloc.estado.valores} -> "${bloc.estado.mensajeError}"',
      );
    });

    test('Permite avanzar con un tablero lleno y sin repetidos', () {
      final tablero = crearTableroDePrueba();

      for (var indice = 0; indice < tablero.celdasIniciales.length; indice++) {
        tablero.celdasIniciales[indice].numero = indice + 1;
      }

      final bloc = ValoresInicialesBloc(tablero);

      expect(bloc.estado.valores, [1, 2, 3, 4, 5, 6]);
      expect(bloc.estado.estanCompletos, isTrue);
      expect(bloc.estado.noHayRepetidos, isTrue);
      expect(bloc.estado.puedeAvanzar, isTrue);
      expect(bloc.avanzar(), isTrue);
      expect(bloc.estado.confirmado, isTrue);
      expect(bloc.estado.puedeAvanzar, isFalse);
      mostrar(
        'Valores ${bloc.estado.valores} -> confirmado: ${bloc.estado.confirmado}.',
      );
    });

    test('No permite avanzar con valores iniciales repetidos', () {
      final tablero = crearTableroDePrueba();

      for (final celda in tablero.celdasIniciales) {
        celda.numero = 1;
      }

      final bloc = ValoresInicialesBloc(tablero);

      expect(bloc.estado.estanCompletos, isTrue);
      expect(bloc.estado.noHayRepetidos, isFalse);
      expect(bloc.estado.puedeAvanzar, isFalse);
      expect(bloc.avanzar(), isFalse);
      expect(
        bloc.estado.mensajeError,
        'Los valores iniciales no pueden repetirse.',
      );
      mostrar(
        'Valores ${bloc.estado.valores} -> "${bloc.estado.mensajeError}"',
      );
    });
  });
}
