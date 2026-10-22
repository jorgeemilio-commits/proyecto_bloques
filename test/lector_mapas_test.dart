import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'consola.dart';

String comoTexto(Coordenada c) => '(${c.x},${c.y})';

void main() {
  // Necesario para leer archivos de assets con rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el archivo del mapa clasico tiene el tablero del juego', () async {
    final leido = await cargarMapa(rutaMapaClasico);
    final casillasPorRegion = {
      for (final region in leido.regiones) region.id: region.coordenadas.length,
    };

    expect(leido.nombre, 'Clásico');
    expect((leido.filas, leido.columnas), (7, 7));
    expect(leido.coordenadasIniciales.map(comoTexto), [
      '(2,0)',
      '(5,1)',
      '(1,3)',
      '(4,3)',
      '(2,5)',
      '(4,6)',
    ]);
    // Regiones en el orden del panel, cuantas casillas tiene cada una y
    // cuales llevan rayas.
    expect(casillasPorRegion.keys, [
      'Z1',
      'Z2',
      'R1',
      'R2',
      'V1',
      'V2',
      'L1',
      'L2',
      'A1',
    ]);
    expect(casillasPorRegion, {
      'Z1': 4,
      'Z2': 4,
      'R1': 6,
      'R2': 6,
      'V1': 6,
      'V2': 6,
      'L1': 6,
      'L2': 6,
      'A1': 5,
    });
    expect(leido.regiones.where((r) => r.conRayas).map((r) => r.id), [
      'Z2',
      'R2',
      'V2',
      'L2',
    ]);
    // Las 9 regiones cubren las 49 casillas.
    expect(casillasPorRegion.values.reduce((a, b) => a + b), 49);
    mostrar(
      '"${leido.nombre}" ${leido.columnas}x${leido.filas}: regiones '
      '${leido.regiones.map((r) => r.id).join(' ')}; iniciales '
      '${leido.coordenadasIniciales.map(comoTexto).join(' ')}.',
    );
  });

  test('el numero separa regiones del mismo color y el 2 lleva rayas', () {
    final mapa = leerMapa('''
# Prueba
Z1I Z1 Z2I Z2
v1I v1 v2I v2
R1I R1 R3I R3
''');

    final porId = {for (final r in mapa.regiones) r.id: r};
    expect(porId.keys, ['Z1', 'Z2', 'R1', 'R3', 'V1', 'V2']);
    expect(porId['Z2']!.conRayas, isTrue);
    expect(porId['Z1']!.conRayas, isFalse);
    expect(porId['R3']!.conRayas, isFalse);
    expect(porId['V1']!.tipo, TipoRegion.verde);
    expect((mapa.filas, mapa.columnas), (3, 4));
    mostrar(
      'Regiones: ${porId.keys.join(' ')}; con rayas: '
      '${mapa.regiones.where((r) => r.conRayas).map((r) => r.id).join(' ')}.',
    );
  });

  test('los errores del texto dicen que esta mal', () {
    const casos = {
      'sin nombre': ('A1 A1', 'primera linea'),
      'nombre vacio': ('#\nA1', 'falta el nombre'),
      'sin filas': ('# Vacio', 'no tiene filas'),
      'letra desconocida': ('# X\nA1 Q1', '"Q1" no es valida'),
      'filas de distinto largo': ('# X\nA1 A1\nA1', 'tiene 1 casillas'),
      'faltan iniciales': ('# X\nA1I A1I A1', '2 casillas iniciales'),
      'dos iniciales en una azul': (
        '# X\nZ1I Z1I R1I\nR1I R1I R1I',
        'region azul Z1',
      ),
    };

    for (final MapEntry(key: caso, value: (texto, mensaje)) in casos.entries) {
      expect(
        () => leerMapa(texto),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mensaje',
            contains(mensaje),
          ),
        ),
        reason: caso,
      );
    }
    mostrar('${casos.length} errores detectados: ${casos.keys.join(', ')}.');
  });
}
