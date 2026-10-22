import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'ayudantes.dart';
import 'consola.dart';

Tablero crearTableroDePrueba() {
  return Tablero.desdeRegiones(
    filas: 7,
    columnas: 7,
    regiones: const [],
    coordenadasIniciales: mapaClasico.coordenadasIniciales,
  );
}

void main() {
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

    test('Amarillo no permite duplicados ni repetidos', () {
      expect(TipoRegion.amarillo.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.amarillo.esPosibleAgregar([1, 4], 2), isTrue);
      expect(TipoRegion.amarillo.esPosibleAgregar([1, 4], 1), isFalse);
      mostrar(
        'Amarillo: [1,4]+2 -> ${TipoRegion.amarillo.esPosibleAgregar([1, 4], 2)}, [1,4]+1 -> ${TipoRegion.amarillo.esPosibleAgregar([1, 4], 1)}.',
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

    test('Blanco exige que todos los valores sean iguales', () {
      expect(TipoRegion.blanco.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.blanco.esPosibleAgregar([3, 3], 3), isTrue);
      expect(TipoRegion.blanco.esPosibleAgregar([3, 3], 1), isFalse);
      expect(TipoRegion.blanco.puntuaciones, {1: 3, 2: 2, 3: 1});
      mostrar(
        'Blanco: [3,3]+3 -> ${TipoRegion.blanco.esPosibleAgregar([3, 3], 3)}, [3,3]+1 -> ${TipoRegion.blanco.esPosibleAgregar([3, 3], 1)}; puntos ${TipoRegion.blanco.puntuaciones.values.join(', ')}.',
      );
    });

    test('Naranja solo acepta numeros de su rango', () {
      const baja = TipoRegion.naranjaBaja;
      const alta = TipoRegion.naranjaAlta;
      final bajaAcepta = [
        for (var n = 1; n <= 6; n++)
          if (baja.esPosibleAgregar([], n)) n,
      ];
      final altaAcepta = [
        for (var n = 1; n <= 6; n++)
          if (alta.esPosibleAgregar([], n)) n,
      ];

      expect(bajaAcepta, [1, 2, 3]);
      expect(altaAcepta, [4, 5, 6]);
      expect(baja.esPosibleAgregar([1, 3], 3), isTrue);
      expect(baja.puntuaciones, {1: 6, 2: 4, 3: 3});
      expect(alta.puntuaciones, {1: 6, 2: 4, 3: 3});
      mostrar(
        'Naranja baja acepta $bajaAcepta; alta acepta $altaAcepta; puntos 6, 4, 3.',
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

  test('Tablero construye celdas y conserva las regiones por separado', () {
    final tablero = Tablero.desdeRegiones(
      filas: 7,
      columnas: 7,
      regiones: [region('Z1'), region('R1'), region('A1')],
      coordenadasIniciales: mapaClasico.coordenadasIniciales,
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
    expect(tablero.obtenerRegion(const Coordenada(2, 0))?.id, 'Z1');
    expect(tablero.obtenerRegion(const Coordenada(1, 2))?.id, 'R1');
    expect(tablero.obtenerRegion(const Coordenada(3, 3))?.id, 'A1');
    expect(tablero.celdas[0][2].numero, isNull);
    expect(tablero.celdas[0][2].coordenada.x, 2);
    expect(tablero.celdas[0][2].coordenada.y, 0);
    expect(tablero.celdas[2][1].coordenada.x, 1);
    expect(tablero.celdas[2][1].coordenada.y, 2);
    mostrar(
      'Tablero ${tablero.filas}x${tablero.columnas}, ${tablero.celdasIniciales.length} iniciales, ${tablero.regiones.length} regiones.',
    );
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
