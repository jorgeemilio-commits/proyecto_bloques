import 'tipo.dart';
/*es de los colores del tablero
enum Region {
	amarillo1(TipoRegion.amarillo),
	amarillo2(TipoRegion.amarillo),
	amarillo3(TipoRegion.amarillo),
	rojo1(TipoRegion.rojo),
	rojo2(TipoRegion.rojo),
	rojo3(TipoRegion.rojo),
	azul1(TipoRegion.azul),
	azul2(TipoRegion.azul),
	azul3(TipoRegion.azul),
	verde1(TipoRegion.verde),
	verde2(TipoRegion.verde),
	verde3(TipoRegion.verde),
	lila1(TipoRegion.lila),
	lila2(TipoRegion.lila),
	lila3(TipoRegion.lila);

	final TipoRegion tipo;

	const Region(this.tipo);
}

// Clase para representar una celda del tablero
class Celda {
	final Region region;
	final int? numero;

	const Celda({required this.region, this.numero});
}

// Función para obtener los números de una región específica del tablero
List<int> obtenerNumerosRegion(
	List<List<Celda>> tablero,
	Region region,
) {
	return [
		for (final fila in tablero)
			for (final celda in fila)
				if (celda.region == region && celda.numero != null) celda.numero!,
	];
}
*/

abstract class Region {
  final TipoRegion tipo;
}

class Coordenada {
  final int x;
  final int y;

  const Coordenada(this.x, this.y);
}

//cual sistema de coordenadas se usa para el tablero
//que dificultad hay de capturar la informacion
//que dificultad hay para mapaearla al modelo

//quien se encarga de que no existan duplicados