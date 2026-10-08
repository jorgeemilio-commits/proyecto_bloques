import 'region.dart';

// Lleva la cuenta de cuantas veces se ha reclamado cada region entre todos los
// jugadores. Los reclamos son por region, no por color: las dos regiones
// azules tienen cada una sus propios reclamos.
class RegistroDeReclamos {
  final Map<Region, int> _reclamos = {};

  int vecesReclamada(Region region) => _reclamos[region] ?? 0;

  // Puntos que daria reclamar la region ahora (0 si ya se agotaron).
  int puntosDisponibles(Region region) =>
      region.tipo.puntuaciones[vecesReclamada(region) + 1] ?? 0;

  // Registra un reclamo de la region y devuelve los puntos que da.
  int reclamar(Region region) {
    final puntos = puntosDisponibles(region);
    _reclamos[region] = vecesReclamada(region) + 1;
    return puntos;
  }
}

// Resultado de completar una region: cual fue y cuantos puntos dio.
class ReclamoDeRegion {
  final Region region;
  final int puntos;

  const ReclamoDeRegion(this.region, this.puntos);
}
