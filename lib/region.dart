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
  final List<Coordenada> coordenadas;

	const Region(this.tipo, this.coordenadas);
}

class Coordenada {
  final int x;
  final int y;

  const Coordenada(this.x, this.y);

	// Dos coordenadas son iguales cuando representan la misma posición.
	@override
	bool operator ==(Object objetoComparado) {
		if (objetoComparado is! Coordenada) {
			return false;
		}

		return objetoComparado.x == x && objetoComparado.y == y;
	}

	// Los objetos iguales deben producir el mismo hashCode.
	// Esto permite usar Coordenada correctamente en Set, Map y contains.
	@override
	int get hashCode => Object.hash(x, y);
}

// Regiones y coordenadas
// Super permite que se pueda crear una region de un tipo especifico (por ejemplo, RegionAzulUno hijo de tipo azul y herada sus caracteristicas)
class RegionAzulUno extends Region {
	const RegionAzulUno()
			: super(TipoRegion.azul, const [
					Coordenada(2, 0),
					Coordenada(2, 1),
					Coordenada(3, 1),
					Coordenada(3, 2),
				]);
}

class RegionAzulDos extends Region {
	const RegionAzulDos()
			: super(TipoRegion.azul, const [
					Coordenada(6, 4),
					Coordenada(5, 5),
					Coordenada(6, 5),
					Coordenada(5, 6),
				]);
}

class RegionRojaUno extends Region {
	const RegionRojaUno()
			: super(TipoRegion.rojo, const [
					Coordenada(1, 2),
					Coordenada(2, 2),
					Coordenada(1, 3),
					Coordenada(1, 4),
					Coordenada(0, 5),
					Coordenada(1, 5),
				]);
}

class RegionRojaDos extends Region {
	const RegionRojaDos()
			: super(TipoRegion.rojo, const [
					Coordenada(4, 4),
					Coordenada(5, 4),
					Coordenada(3, 5),
					Coordenada(4, 5),
					Coordenada(3, 6),
					Coordenada(4, 6),
				]);
}

class RegionVerdeUno extends Region {
	const RegionVerdeUno()
			: super(TipoRegion.verde, const [
					Coordenada(1, 0),
					Coordenada(0, 1),
					Coordenada(1, 1),
					Coordenada(0, 2),
					Coordenada(0, 3),
					Coordenada(0, 4),
				]);
}

class RegionVerdeDos extends Region {
	const RegionVerdeDos()
			: super(TipoRegion.verde, const [
					Coordenada(6, 1),
					Coordenada(5, 2),
					Coordenada(6, 2),
					Coordenada(4, 3),
					Coordenada(5, 3),
					Coordenada(6, 3),
				]);
}

class RegionLilaUno extends Region {
	const RegionLilaUno()
			: super(TipoRegion.lila, const [
					Coordenada(3, 0),
					Coordenada(4, 0),
					Coordenada(5, 0),
					Coordenada(4, 1),
					Coordenada(5, 1),
					Coordenada(4, 2),
				]);
}

class RegionLilaDos extends Region {
	const RegionLilaDos()
			: super(TipoRegion.lila, const [
					Coordenada(2, 3),
					Coordenada(2, 4),
					Coordenada(3, 4),
					Coordenada(2, 5),
					Coordenada(1, 6),
					Coordenada(2, 6),
				]);
}

class RegionAmarilla extends Region {
	const RegionAmarilla()
			: super(TipoRegion.amarillo, const [
					Coordenada(0, 0),
					Coordenada(6, 0),
					Coordenada(3, 3),
					Coordenada(0, 6),
					Coordenada(6, 6),
				]);
}

const List<Region> regionesMapa = [
	RegionAzulUno(),
	RegionAzulDos(),
	RegionRojaUno(),
	RegionRojaDos(),
	RegionVerdeUno(),
	RegionVerdeDos(),
	RegionLilaUno(),
	RegionLilaDos(),
	RegionAmarilla(),
];


//cual sistema de coordenadas se usa para el tablero
//que dificultad hay de capturar la informacion
//que dificultad hay para mapaearla al modelo

//quien se encarga de que no existan duplicados