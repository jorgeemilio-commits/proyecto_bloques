import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'consola.dart';

String comoTexto(Coordenada c) => '(${c.x},${c.y})';

void main() {
  // Necesario para leer archivos de assets con rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el archivo del mapa clasico da el mismo mapa que el codigo', () async {
    final leido = await cargarMapa(rutaMapaClasico);

    expect(leido.nombre, mapaClasico.nombre);
    expect((leido.filas, leido.columnas), (7, 7));
    expect(
      leido.coordenadasIniciales.map(comoTexto),
      mapaClasico.coordenadasIniciales.map(comoTexto),
    );
    // Mismas regiones, en el mismo orden, con el mismo color, rayas y casillas.
    expect(
      leido.regiones.map((r) => r.id),
      mapaClasico.regiones.map((r) => r.id),
    );
    for (final esperada in mapaClasico.regiones) {
      final region = leido.regiones.firstWhere((r) => r.id == esperada.id);
      expect(region.tipo, esperada.tipo, reason: esperada.id);
      expect(region.conRayas, esperada.conRayas, reason: esperada.id);
      expect(
        region.coordenadas.map(comoTexto).toSet(),
        esperada.coordenadas.map(comoTexto).toSet(),
        reason: esperada.id,
      );
    }
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
