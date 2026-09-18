import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';

void main() {
  group('Validación de reglas por tipo de región', () {
    test('Rojo no permite duplicados ni repetidos', () {
      expect(TipoRegion.rojo.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.rojo.esPosibleAgregar([1, 2, 3], 4), isTrue);
      expect(TipoRegion.rojo.esPosibleAgregar([1, 2, 3, 4], 4), isFalse);
      expect(TipoRegion.rojo.esPosibleAgregar([1, 2, 4, 4], 5), isFalse);
    });

    test('Azul exige que todos los valores sean iguales', () {
      expect(TipoRegion.azul.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.azul.esPosibleAgregar([2, 2], 2), isTrue);
      expect(TipoRegion.azul.esPosibleAgregar([2, 2], 4), isFalse);
      expect(TipoRegion.azul.esPosibleAgregar([4, 4, 4, 4], 4), isTrue);
    });

    test('Verde siempre acepta cualquier valor', () {
      expect(TipoRegion.verde.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.verde.esPosibleAgregar([1, 2, 3], 4), isTrue);
      expect(TipoRegion.verde.esPosibleAgregar([4, 4, 4, 4], 5), isTrue);
      expect(TipoRegion.verde.esPosibleAgregar([1, 1, 1, 1], 1), isTrue);
    });

    test('Lila permite hasta dos números diferentes', () {
      expect(TipoRegion.lila.esPosibleAgregar([], 5), isTrue);
      expect(TipoRegion.lila.esPosibleAgregar([5, 5], 5), isTrue);
      expect(TipoRegion.lila.esPosibleAgregar([1, 1, 2], 2), isTrue);
      expect(TipoRegion.lila.esPosibleAgregar([1, 2], 3), isFalse);
      expect(TipoRegion.lila.esPosibleAgregar([1, 2, 3], 1), isFalse);
    });
  });

  group('Tipos y colores de región', () {
    test('Cada región concreta tiene el tipo correcto', () {
      expect(const RegionAzulUno().tipo, TipoRegion.azul);
      expect(const RegionRojaUno().tipo, TipoRegion.rojo);
      expect(const RegionVerdeUno().tipo, TipoRegion.verde);
      expect(const RegionLilaUno().tipo, TipoRegion.lila);
      expect(const RegionAmarilla().tipo, TipoRegion.amarillo);
    });

    test('Los colores de los tipos coinciden con los esperados', () {
      expect(TipoRegion.amarillo.color, const Color(0xFFFFFF00));
      expect(TipoRegion.azul.color, const Color(0xFF0000FF));
      expect(TipoRegion.rojo.color, const Color(0xFFFF0000));
      expect(TipoRegion.verde.color, const Color(0xFF00FF00));
      expect(TipoRegion.lila.color, const Color(0xFF800080));
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
    });

    test('Tablero construye celdas con sus regiones y coordenadas', () {
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
      expect(tablero.celdas[2][2].region, isA<RegionAzulUno>());
      expect(tablero.celdas[1][2].region, isA<RegionRojaUno>());
      expect(tablero.celdas[3][3].region, isA<RegionAmarilla>());
      expect(tablero.celdas[2][2].coordenada, const Coordenada(2, 2));
    });
  });
}