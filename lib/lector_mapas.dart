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
// - Letras: A amarillo, V verde, Z azul, L lila, R rojo, B blanco y
//   N naranja. La naranja solo puede ser N1 (numeros del 1 al 3) o N2
//   (numeros del 4 al 6).
// - La region con numero 2 se dibuja con rayas.
// - Opcional, al final: los puntos propios de una region en este mapa, con su
//   identificador, dos puntos y sus tres premios. Ejemplo: 'L1: 7 5 3'. Las
//   regiones sin esa linea usan los puntos de su color.
//
// Si el texto tiene un error, lanza un FormatException que dice donde esta.

// Cantidad de casillas iniciales que debe tener todo mapa.
const int casillasInicialesPorMapa = 6;

// Letras de color en el orden en que se muestran las regiones.
const List<String> _letrasDeColor = ['Z', 'R', 'V', 'L', 'A', 'N', 'B'];

const Map<String, TipoRegion> _tipoPorLetra = {
  'Z': TipoRegion.azul,
  'R': TipoRegion.rojo,
  'V': TipoRegion.verde,
  'L': TipoRegion.lila,
  'A': TipoRegion.amarillo,
  'B': TipoRegion.blanco,
};

// Tipo de una region por su letra y numero. La naranja depende del numero:
// N1 es la de 1 a 3 y N2 la de 4 a 6; cualquier otra devuelve null.
TipoRegion? _tipoDeRegion(String letra, int numero) {
  if (letra == 'N') {
    return switch (numero) {
      1 => TipoRegion.naranjaBaja,
      2 => TipoRegion.naranjaAlta,
      _ => null,
    };
  }
  return _tipoPorLetra[letra];
}

// Letra del color, numero de region y la I opcional de casilla inicial.
final RegExp _formatoCasilla = RegExp(r'^([A-Z])(\d+)(I?)$');

// Puntos propios de una region: 'L1: 7 5 3'.
final RegExp _formatoPuntos = RegExp(
  r'^([A-Z]\d+)\s*:\s*(\d+)\s+(\d+)\s+(\d+)$',
);

// Carpeta de los mapas dentro de los assets y archivo del mapa clasico.
const String carpetaMapas = 'assets/mapas/';
const String rutaMapaClasico = '${carpetaMapas}clasico.txt';

// Rutas de todos los mapas (.txt) de la carpeta: el clasico primero y los
// demas en orden alfabetico. Para agregar un mapa basta con poner su archivo
// en assets/mapas/.
Future<List<String>> rutasDeMapas() async {
  final manifiesto = await AssetManifest.loadFromAssetBundle(rootBundle);
  final rutas =
      manifiesto
          .listAssets()
          .where(
            (ruta) => ruta.startsWith(carpetaMapas) && ruta.endsWith('.txt'),
          )
          .toList()
        ..sort();

  if (rutas.remove(rutaMapaClasico)) {
    rutas.insert(0, rutaMapaClasico);
  }
  return rutas;
}

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

  // Las lineas con ':' son puntos propios de regiones; las demas son filas.
  final filas = [
    for (final linea in lineas.skip(1))
      if (!linea.texto.contains(':')) linea,
  ];
  final puntosPropios = _leerPuntosPropios([
    for (final linea in lineas.skip(1))
      if (linea.texto.contains(':')) linea,
  ]);
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
      if (partes == null || !_letrasDeColor.contains(partes[1])) {
        throw FormatException(
          'Linea ${fila.numero}, casilla ${x + 1}: "$casilla" no es valida. '
          'Use letra de color (A, V, Z, L, R, B, N), numero de region y una I '
          'opcional, por ejemplo Z1 o Z1I.',
        );
      }
      if (_tipoDeRegion(partes[1]!, int.parse(partes[2]!)) == null) {
        throw FormatException(
          'Linea ${fila.numero}, casilla ${x + 1}: "$casilla" no es valida. '
          'La naranja solo puede ser N1 (numeros del 1 al 3) o N2 (del 4 '
          'al 6).',
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

  for (final MapEntry(key: id, value: linea) in puntosPropios.entries) {
    if (!coordenadasPorRegion.containsKey(id)) {
      throw FormatException(
        'Linea ${linea.numero}: el mapa no tiene una region $id.',
      );
    }
  }

  final regiones = [
    for (final MapEntry(key: id, value: coordenadas)
        in coordenadasPorRegion.entries)
      Region(
        id,
        _tipoDeRegion(id[0], int.parse(id.substring(1)))!,
        List.unmodifiable(coordenadas),
        conRayas: int.parse(id.substring(1)) == 2,
        puntuacionesPropias: puntosPropios[id]?.puntos,
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

// Lee las lineas de puntos propios ('L1: 7 5 3') y devuelve, por region, sus
// premios y la linea donde estaban (para los mensajes de error).
Map<String, ({Map<int, int> puntos, int numero})> _leerPuntosPropios(
  List<({int numero, String texto})> lineas,
) {
  final porRegion = <String, ({Map<int, int> puntos, int numero})>{};
  for (final linea in lineas) {
    final partes = _formatoPuntos.firstMatch(linea.texto.toUpperCase());
    if (partes == null) {
      throw FormatException(
        'Linea ${linea.numero}: "${linea.texto}" no es valida. Los puntos de '
        'una region se escriben asi: L1: 7 5 3',
      );
    }
    final id = '${partes[1]![0]}${int.parse(partes[1]!.substring(1))}';
    if (porRegion.containsKey(id)) {
      throw FormatException(
        'Linea ${linea.numero}: los puntos de la region $id ya estaban en la '
        'linea ${porRegion[id]!.numero}.',
      );
    }
    porRegion[id] = (
      puntos: {
        1: int.parse(partes[2]!),
        2: int.parse(partes[3]!),
        3: int.parse(partes[4]!),
      },
      numero: linea.numero,
    );
  }
  return porRegion;
}

// Ordena las regiones por color (azul, rojo, verde, lila, amarillo, naranja,
// blanco) y luego por numero, como se muestran en el panel de regiones.
int _compararRegiones(Region a, Region b) {
  final porColor =
      _letrasDeColor.indexOf(a.id[0]) - _letrasDeColor.indexOf(b.id[0]);
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

  // Las casillas iniciales llevan numeros distintos, asi que las de una misma
  // region deben poder tener numeros distintos que cumplan su regla. Por
  // ejemplo: una region azul o blanca solo admite una; una naranja, tres.
  for (final region in regiones) {
    final enLaRegion = iniciales
        .where(
          (inicial) => region.coordenadas.any(
            (c) => c.x == inicial.x && c.y == inicial.y,
          ),
        )
        .length;
    final posibles = _maximoDeNumerosDistintos(region.tipo);
    if (enLaRegion > posibles) {
      throw FormatException(
        'La region ${region.tipo.nombre} ${region.id} tiene $enLaRegion '
        'casillas iniciales, pero su regla solo permite $posibles numeros '
        'distintos.',
      );
    }
  }
}

// Cuantos numeros distintos del 1 al 6 caben juntos en una region de este
// tipo: se van agregando mientras la regla lo permita.
int _maximoDeNumerosDistintos(TipoRegion tipo) {
  final numeros = <int>[];
  for (var numero = 1; numero <= 6; numero++) {
    if (tipo.esPosibleAgregar(numeros, numero)) {
      numeros.add(numero);
    }
  }
  return numeros.length;
}
