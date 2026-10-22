import 'package:flutter/services.dart';

import 'mapa.dart';
import 'region.dart';
import 'tipo.dart';

// Lee un mapa escrito como texto. Formato:
//
//   # Nombre del mapa
//   A1 V1 Z1I L1 L1 L1 A1
//   V1 V1 Z1 Z1 L1 L1I V2
//   ...
//
// - La primera linea es el nombre, despues de '#'.
// - Cada linea siguiente es una fila; las casillas van separadas por espacios.
// - Cada casilla es la letra del color, el numero de region de ese color y,
//   si es casilla inicial, una 'I'. Ejemplo: 'Z1I'.
// - Letras: A amarillo, V verde, Z azul, L lila, R rojo, B blanco.
// - La region con numero 2 se dibuja con rayas.
//
// Si el texto tiene un error, lanza un FormatException que dice donde esta.

// Cantidad de casillas iniciales que debe tener todo mapa.
const int casillasInicialesPorMapa = 6;

const Map<String, TipoRegion> _tipoPorLetra = {
  'Z': TipoRegion.azul,
  'R': TipoRegion.rojo,
  'V': TipoRegion.verde,
  'L': TipoRegion.lila,
  'A': TipoRegion.amarillo,
  'B': TipoRegion.blanco,
};

// Letra del color, numero de region y la I opcional de casilla inicial.
final RegExp _formatoCasilla = RegExp(r'^([A-Z])(\d+)(I?)$');

// Archivo del mapa clasico dentro de los assets.
const String rutaMapaClasico = 'assets/mapas/clasico.txt';

// Lee el archivo de un mapa (en assets/mapas/) y lo convierte en Mapa.
Future<Mapa> cargarMapa(String ruta) async =>
    leerMapa(await rootBundle.loadString(ruta));

Mapa leerMapa(String texto) {
  // Se guarda el numero de linea original para los mensajes de error.
  final lineas = [
    for (final (indice, linea) in texto.split('\n').indexed)
      if (linea.trim().isNotEmpty) (numero: indice + 1, texto: linea.trim()),
  ];

  if (lineas.isEmpty || !lineas.first.texto.startsWith('#')) {
    throw const FormatException(
      'La primera linea debe ser el nombre del mapa, por ejemplo: # Clasico',
    );
  }
  final nombre = lineas.first.texto.substring(1).trim();
  if (nombre.isEmpty) {
    throw FormatException(
      'Linea ${lineas.first.numero}: falta el nombre despues de "#".',
    );
  }

  final filas = lineas.skip(1).toList();
  if (filas.isEmpty) {
    throw const FormatException('El mapa no tiene filas.');
  }

  final coordenadasPorRegion = <String, List<Coordenada>>{};
  final iniciales = <Coordenada>[];
  int? columnas;

  for (final (y, fila) in filas.indexed) {
    final casillas = fila.texto.split(RegExp(r'\s+'));
    columnas ??= casillas.length;
    if (casillas.length != columnas) {
      throw FormatException(
        'Linea ${fila.numero}: tiene ${casillas.length} casillas y la primera '
        'fila tiene $columnas.',
      );
    }

    for (final (x, casilla) in casillas.indexed) {
      final partes = _formatoCasilla.firstMatch(casilla.toUpperCase());
      if (partes == null || !_tipoPorLetra.containsKey(partes[1])) {
        throw FormatException(
          'Linea ${fila.numero}, casilla ${x + 1}: "$casilla" no es valida. '
          'Use letra de color (A, V, Z, L, R, B), numero de region y una I '
          'opcional, por ejemplo Z1 o Z1I.',
        );
      }

      final coordenada = Coordenada(x, y);
      final id = '${partes[1]}${int.parse(partes[2]!)}';
      coordenadasPorRegion.putIfAbsent(id, () => []).add(coordenada);
      if (partes[3] == 'I') {
        iniciales.add(coordenada);
      }
    }
  }

  final regiones = [
    for (final MapEntry(key: id, value: coordenadas)
        in coordenadasPorRegion.entries)
      Region(
        id,
        _tipoPorLetra[id[0]]!,
        List.unmodifiable(coordenadas),
        conRayas: int.parse(id.substring(1)) == 2,
      ),
  ]..sort(_compararRegiones);

  _validarIniciales(iniciales, regiones);

  return Mapa(
    nombre: nombre,
    filas: filas.length,
    columnas: columnas!,
    regiones: List.unmodifiable(regiones),
    coordenadasIniciales: List.unmodifiable(iniciales),
  );
}

// Ordena las regiones por color (azul, rojo, verde, lila, amarillo, blanco) y
// luego por numero, como se muestran en el panel de regiones.
int _compararRegiones(Region a, Region b) {
  final letras = _tipoPorLetra.keys.toList();
  final porColor = letras.indexOf(a.id[0]) - letras.indexOf(b.id[0]);
  if (porColor != 0) {
    return porColor;
  }
  return int.parse(a.id.substring(1)) - int.parse(b.id.substring(1));
}

void _validarIniciales(List<Coordenada> iniciales, List<Region> regiones) {
  if (iniciales.length != casillasInicialesPorMapa) {
    throw FormatException(
      'El mapa tiene ${iniciales.length} casillas iniciales (marcadas con I) '
      'y debe tener $casillasInicialesPorMapa.',
    );
  }

  // En las regiones donde todos los numeros deben ser iguales (azul, blanca)
  // no puede haber dos casillas iniciales, porque estas llevan numeros
  // distintos.
  final soloIguales = regiones.where(
    (region) => !region.tipo.esPosibleAgregar([1], 2),
  );
  for (final region in soloIguales) {
    final enLaRegion = iniciales.where(
      (inicial) =>
          region.coordenadas.any((c) => c.x == inicial.x && c.y == inicial.y),
    );
    if (enLaRegion.length > 1) {
      throw FormatException(
        'La region ${region.tipo.nombre} ${region.id} tiene '
        '${enLaRegion.length} casillas iniciales; solo puede tener una porque '
        'sus numeros deben ser iguales.',
      );
    }
  }
}
