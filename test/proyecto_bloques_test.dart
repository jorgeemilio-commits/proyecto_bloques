import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:test/test.dart';

void main() {
  group('Pruebas para Insertar Rojo / Amarillo', () {
    
    test('Debe regresar true si la lista está vacía', () {
      expect(reglaRojoAmarillo([], 5), isTrue);
    });

    test('Debe regresar true si el número no está en la lista', () {
      expect(reglaRojoAmarillo([1, 2, 3], 4), isTrue);
    });

    test('Debe regresar false si el número a insertar ya existe en la lista', () {
      expect(reglaRojoAmarillo([1, 2, 3, 4], 4), isFalse);
    });

    test('Debe regresar false si el la lista existente ya tiene duplicados', () {
      expect(reglaRojoAmarillo([1, 2, 4, 4], 5), isFalse);
    });

  });

  group('Pruebas para Insertar Azul', () {
    
    test('Debe regresar true si la lista está vacía', () {
      expect(reglaAzul([], 5), isTrue);
    });

    test('Debe regresar false si el número no es duplicado', () {
      expect(reglaAzul([2, 2], 4), isFalse);
    });

    test('Debe regresar true si el número a insertar ya existe en la lista', () {
      expect(reglaAzul([4, 4, 4, 4], 4), isTrue);
    });
  });

  group('Pruebas para Insertar Verde', () {
    
    test('Debe regresar true siempre', () {
      expect(reglaVerde([], 5), isTrue);
      expect(reglaVerde([1, 2, 3], 4), isTrue);
      expect(reglaVerde([1, 2, 3, 4], 4), isTrue);
      expect(reglaVerde([4, 4, 4, 4], 5), isTrue);
      expect(reglaVerde([1, 1, 1, 1], 1), isTrue);
    });

  });

  group('Pruebas para Insertar Purpura / Lila', () {
    test('Debe regresar true si la lista esta vacia', () {
      expect(reglaPurpuraLila([], 5), isTrue);
    });

    test('Debe regresar true si solo hay un numero diferente', () {
      expect(reglaPurpuraLila([5, 5], 5), isTrue);
    });

    test('Debe regresar true si la lista tiene como maximo dos numeros diferentes', () {
      expect(reglaPurpuraLila([1, 1, 2], 2), isTrue);
      expect(reglaPurpuraLila([1, 1], 2), isTrue);
    });

    test('Debe regresar false si el nuevo numero crea un tercer numero diferente', () {
      expect(reglaPurpuraLila([1, 2], 3), isFalse);
    });

    test('Debe regresar false si la lista ya tiene mas de dos numeros diferentes', () {
      expect(reglaPurpuraLila([1, 2, 3], 1), isFalse);
    });
  });

  group('Pruebas para tipos de regiones', () {
    test('Cada region contiene su color y su regla', () {
      expect(Region.amarillo1.color, ColorRegion.amarillo);
      expect(Region.amarillo1.regla, reglaRojoAmarillo);
      expect(Region.rojo2.color, ColorRegion.rojo);
      expect(Region.rojo2.regla, reglaRojoAmarillo);
      expect(Region.azul3.color, ColorRegion.azul);
      expect(Region.azul3.regla, reglaAzul);
      expect(Region.verde1.color, ColorRegion.verde);
      expect(Region.verde1.regla, reglaVerde);
      expect(Region.lila2.color, ColorRegion.lila);
      expect(Region.lila2.regla, reglaPurpuraLila);
    });

    test('La regla asociada a una region se puede aplicar', () {
      expect(Region.amarillo1.regla([1, 2], 3), isTrue);
      expect(Region.azul1.regla([4, 4], 4), isTrue);
      expect(Region.verde1.regla([1, 1], 2), isTrue);
      expect(Region.lila1.regla([1, 2], 3), isFalse);
    });
  });

  group('Pruebas para extraer numeros de una region', () {
    final tablero = [
      [
        const Celda(region: Region.azul1, numero: 5),
        const Celda(region: Region.azul1, numero: 8),
        const Celda(region: Region.azul1, numero: 3),
        const Celda(region: Region.azul1, numero: 8),

        const Celda(region: Region.azul2, numero: 3),
        const Celda(region: Region.azul2, numero: 1),
        const Celda(region: Region.azul2, numero: 3),

        const Celda(region: Region.lila1, numero: 9),
        const Celda(region: Region.lila1, numero: 9),
        const Celda(region: Region.lila1, numero: 9),

        const Celda(region: Region.amarillo1, numero: 4),
      ],
    ];

    test('Debe regresar todos los numeros de la region solicitada', () {
      final numerosAzul1 = obtenerNumerosRegion(tablero, Region.azul1);
      final numerosAzul2 = obtenerNumerosRegion(tablero, Region.azul2);
      final numerosLila1 = obtenerNumerosRegion(tablero, Region.lila1);
      final numerosAmarillo1 = obtenerNumerosRegion(tablero, Region.amarillo1);

      print('Numeros de Region.azul1: $numerosAzul1');
      print('Numeros de Region.azul2: $numerosAzul2');
      print('Numeros de Region.lila1: $numerosLila1');
      print('Numeros de Region.amarillo1: $numerosAmarillo1');

      expect(numerosAzul1, [5, 8, 3, 8]);
      expect(numerosAzul2, [3, 1, 3]);
      expect(numerosLila1, [9, 9, 9]);
      expect(numerosAmarillo1, [4]);
    });

    test('Debe regresar una lista vacia si la region no tiene numeros', () {
      final resultado = obtenerNumerosRegion(tablero, Region.verde1);

      print('Numeros de Region.verde1: $resultado');

      expect(resultado, isEmpty);
    });

    test('Debe ignorar celdas vacias de la region solicitada', () {
      final tableroConCeldaVacia = [
        [
          const Celda(region: Region.lila1, numero: 4),
          const Celda(region: Region.lila1),
        ],
      ];

      final resultado = obtenerNumerosRegion(tableroConCeldaVacia, Region.lila1);

      print('Numeros de Region.lila1 con celda vacia: $resultado');

      expect(resultado, [4]);
    });
  });

}