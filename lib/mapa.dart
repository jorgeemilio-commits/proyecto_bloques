import 'region.dart';
import 'tablero.dart';

// Un mapa del juego: su nombre, su tamaño, sus regiones de colores y las
// casillas iniciales que el jugador llena antes de empezar.
class Mapa {
  final String nombre;
  final int filas;
  final int columnas;
  final List<Region> regiones;
  final List<Coordenada> coordenadasIniciales;

  const Mapa({
    required this.nombre,
    required this.filas,
    required this.columnas,
    required this.regiones,
    required this.coordenadasIniciales,
  });

  // Crea un tablero nuevo y vacio con este mapa.
  Tablero crearTablero() => Tablero.desdeRegiones(
    filas: filas,
    columnas: columnas,
    regiones: regiones,
    coordenadasIniciales: coordenadasIniciales,
  );
}

// Mapa con el que se juega por ahora.
const Mapa mapaClasico = Mapa(
  nombre: 'Clásico',
  filas: 7,
  columnas: 7,
  regiones: regionesMapa,
  coordenadasIniciales: coordenadasIniciales,
);
