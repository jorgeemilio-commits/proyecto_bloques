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

  test('los mapas de la carpeta se listan con el clasico primero', () async {
    final rutas = await rutasDeMapas();

    expect(rutas.first, rutaMapaClasico);
    expect(rutas, contains('assets/mapas/borde.txt'));
    expect(rutas.every((ruta) => ruta.endsWith('.txt')), isTrue);
    mostrar('Mapas en la carpeta: ${rutas.join(', ')}.');
  });

  test('el archivo del mapa borde se lee con su region blanca', () async {
    final borde = await cargarMapa('assets/mapas/borde.txt');
    final casillasPorRegion = {
      for (final region in borde.regiones) region.id: region.coordenadas.length,
    };

    expect(borde.nombre, 'Borde');
    expect((borde.filas, borde.columnas), (7, 7));
    expect(borde.coordenadasIniciales, hasLength(6));
    expect(casillasPorRegion['B1'], 2);
    // Las 4 esquinas interiores y el centro forman una sola region amarilla.
    expect(casillasPorRegion['A1'], 5);
    expect(casillasPorRegion.values.reduce((a, b) => a + b), 49);
    mostrar(
      '"${borde.nombre}": ${borde.regiones.length} regiones '
      '(${casillasPorRegion.entries.map((e) => '${e.key}:${e.value}').join(' ')}).',
    );
  });

  test('una region puede tener sus propios puntos en el mapa', () {
    final mapa = leerMapa('''
# Prueba
Z1I Z1 Z2I Z2
V1I V1 R1I R1
L1I L1 A1I A1

Z1: 9 8 7
''');
    final porId = {for (final r in mapa.regiones) r.id: r};
    final registro = RegistroDeReclamos();
    final premiosZ1 = [
      for (var vez = 0; vez < 4; vez++) registro.reclamar(porId['Z1']!),
    ];

    // Z1 usa sus puntos; Z2, del mismo color, usa los del azul.
    expect(porId['Z1']!.puntuaciones, {1: 9, 2: 8, 3: 7});
    expect(porId['Z2']!.puntuaciones, TipoRegion.azul.puntuaciones);
    expect(premiosZ1, [9, 8, 7, 0]);
    mostrar('Z1 con puntos propios da $premiosZ1; Z2 usa los del azul.');
  });

  test('el archivo del mapa alas trae los puntos de su hoja', () async {
    final alas = await cargarMapa('assets/mapas/alas.txt');
    final puntos = {
      for (final region in alas.regiones)
        region.id: region.puntuaciones.values.join(' '),
    };

    expect(puntos, {
      'Z1': '7 5 3',
      'R1': '6 4 2',
      'R2': '6 4 2',
      'V1': '6 5 4',
      'L1': '7 5 3',
      'L2': '7 5 3',
      'A1': '7 5 3',
      'B1': '8 6 4',
    });
    mostrar('Alas: $puntos.');
  });

  test('el numero separa regiones del mismo color y el 2 lleva rayas', () {
    final mapa = leerMapa('''
# Prueba
Z1I Z1 Z2I Z2
v1I v1 v2I v2
R1I R1 R3I R3
B1 B1 B2 B2
N1 N1 N2 N2
''');

    final porId = {for (final r in mapa.regiones) r.id: r};
    expect(porId.keys, [
      'Z1',
      'Z2',
      'R1',
      'R3',
      'V1',
      'V2',
      'N1',
      'N2',
      'B1',
      'B2',
    ]);
    expect(porId['Z2']!.conRayas, isTrue);
    expect(porId['Z1']!.conRayas, isFalse);
    expect(porId['R3']!.conRayas, isFalse);
    expect(porId['V1']!.tipo, TipoRegion.verde);
    expect(porId['B1']!.tipo, TipoRegion.blanco);
    expect(porId['B2']!.conRayas, isTrue);
    // N1 es la naranja de 1 a 3 y N2 la de 4 a 6 (con rayas).
    expect(porId['N1']!.tipo, TipoRegion.naranjaBaja);
    expect(porId['N2']!.tipo, TipoRegion.naranjaAlta);
    expect(porId['N2']!.conRayas, isTrue);
    expect((mapa.filas, mapa.columnas), (5, 4));
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
      'dos iniciales en una blanca': (
        '# X\nB1I B1I R1I\nR1I R1I R1I',
        'region blanca B1',
      ),
      'naranja que no es N1 ni N2': ('# X\nN3', 'solo puede ser N1'),
      'puntos de una region que no existe': (
        '# X\nA1 A1\nZ9: 1 2 3',
        'no tiene una region Z9',
      ),
      'puntos mal escritos': ('# X\nA1 A1\nA1: 7 5', 'se escriben asi'),
      'puntos repetidos': (
        '# X\nA1 A1\nA1: 7 5 3\nA1: 6 4 2',
        'ya estaban en la linea 3',
      ),
      'cuatro iniciales en una naranja': (
        '# X\nN1I N1I N1I N1I\nR1I R1I R1 R1',
        'region naranja N1 tiene 4',
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
