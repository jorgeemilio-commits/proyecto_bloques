import 'dart:math';

// Reglas de una partida en linea (ver PROTOCOLO_MULTIJUGADOR.md): valores
// iniciales, rondas con jugadas simultaneas, reclamos de regiones, meta y
// ganadores. Aqui no hay tiempos ni red; salas.dart lleva los tiempos y manda
// los mensajes.

// Puntos para ganar segun cuantos jugadores empiezan la partida.
int metaPara(int jugadores) => switch (jugadores) {
  2 => 26,
  3 => 24,
  4 => 22,
  _ => 20,
};

// Lo que mando un jugador en su ronda: el numero que puso y donde, y la region
// que completo con el (si completo una) con sus premios.
class Jugada {
  final int x;
  final int y;
  final int numero;
  final String? region;
  final List<int> premios;

  const Jugada({
    required this.x,
    required this.y,
    required this.numero,
    this.region,
    this.premios = const [],
  });
}

// Un jugador dentro de la partida. Se queda en la partida aunque se rinda o
// salga, para que los demas sigan viendo su tablero y sus puntos.
class Participante {
  final String nombre;
  // Sus 6 valores iniciales, en el orden de las casillas iniciales del mapa.
  List<int>? iniciales;
  // Los numeros que coloco despues, como [x, y, numero].
  final List<List<int>> casillas = [];
  int puntos = 0;
  // 'jugando', 'llegoALaMeta' o 'rendido'.
  String situacion = 'jugando';
  // Si ya mando su jugada en esta ronda (o sus valores iniciales).
  bool yaJugo = false;
  // Su jugada de esta ronda; null si paso o todavia no juega.
  Jugada? jugada;
  // Region que completo en la ultima ronda y los puntos que le dio.
  ({String region, int puntos})? ultimoReclamo;

  Participante(this.nombre);

  bool get jugando => situacion == 'jugando';
}

class Partida {
  final int meta;
  final List<Participante> participantes;
  // Veces que se ha reclamado cada region entre todos.
  final Map<String, int> reclamos = {};
  // 'valoresIniciales', 'ronda', 'entreRondas' o 'terminada'.
  String fase = 'valoresIniciales';
  int ronda = 0;
  List<int>? dados;
  final List<String> ganadores = [];

  Partida(List<String> nombres)
    : meta = metaPara(nombres.length),
      participantes = [for (final nombre in nombres) Participante(nombre)];

  Participante? de(String nombre) {
    for (final participante in participantes) {
      if (participante.nombre == nombre) {
        return participante;
      }
    }
    return null;
  }

  Iterable<Participante> get _jugando =>
      participantes.where((participante) => participante.jugando);

  bool get todosTienenValores =>
      _jugando.every((participante) => participante.iniciales != null);

  // Guarda los valores iniciales del jugador. Devuelve false si no se pueden
  // poner (no es la fase, ya los tenia o no son 1 a 6 sin repetir).
  bool ponerValores(Participante participante, List<int> valores) {
    final validos =
        valores.length == 6 && valores.toSet().containsAll([1, 2, 3, 4, 5, 6]);
    if (fase != 'valoresIniciales' ||
        !participante.jugando ||
        participante.iniciales != null ||
        !validos) {
      return false;
    }
    participante.iniciales = valores;
    participante.yaJugo = true;
    return true;
  }

  // Al acabarse el tiempo: valores al azar a quien no los puso.
  void valoresAlAzar(Random azar) {
    for (final participante in _jugando) {
      participante.iniciales ??= ([1, 2, 3, 4, 5, 6]..shuffle(azar));
    }
  }

  // Tira los dados y empieza la siguiente ronda.
  void empezarRonda(Random azar) {
    fase = 'ronda';
    ronda++;
    dados = [azar.nextInt(6) + 1, azar.nextInt(6) + 1];
    for (final participante in participantes) {
      participante.yaJugo = false;
      participante.jugada = null;
    }
  }

  // Guarda la jugada del jugador en esta ronda (null = pasa). Devuelve false
  // si no puede jugar (no es la ronda, no esta jugando o ya jugo).
  bool jugar(Participante participante, Jugada? jugada) {
    if (fase != 'ronda' || !participante.jugando || participante.yaJugo) {
      return false;
    }
    participante.jugada = jugada;
    participante.yaJugo = true;
    return true;
  }

  // Termina la ronda: pone los numeros en los tableros, reparte los reclamos
  // y revisa quien llego a la meta. Quien no jugo, paso.
  void resolverRonda() {
    final reclamosDeLaRonda = <String, List<Participante>>{};
    for (final participante in participantes) {
      participante.ultimoReclamo = null;
      final jugada = participante.jugada;
      if (jugada == null || !participante.jugando) {
        continue;
      }
      participante.casillas.add([jugada.x, jugada.y, jugada.numero]);
      final region = jugada.region;
      if (region != null) {
        (reclamosDeLaRonda[region] ??= []).add(participante);
      }
    }

    // Si varios completaron la misma region en esta ronda, todos ganan el
    // mismo premio y la region avanza un solo nivel. Despues del tercer
    // reclamo la region ya no da puntos.
    for (final MapEntry(key: region, value: quienes)
        in reclamosDeLaRonda.entries) {
      final veces = reclamos[region] ?? 0;
      reclamos[region] = veces + 1;
      for (final participante in quienes) {
        final premios = participante.jugada!.premios;
        final puntos = veces < premios.length ? premios[veces] : 0;
        participante.puntos += puntos;
        participante.ultimoReclamo = (region: region, puntos: puntos);
      }
    }

    // Meta: gana el primero en llegar; si varios llegan en la misma ronda,
    // el de mas puntos (empatados, ganan todos). Los demas siguen jugando.
    final llegaron = _jugando
        .where((participante) => participante.puntos >= meta)
        .toList();
    for (final participante in llegaron) {
      participante.situacion = 'llegoALaMeta';
    }
    if (ganadores.isEmpty && llegaron.isNotEmpty) {
      final mejor = llegaron
          .map((participante) => participante.puntos)
          .reduce(max);
      ganadores.addAll([
        for (final participante in llegaron)
          if (participante.puntos == mejor) participante.nombre,
      ]);
    }

    for (final participante in participantes) {
      participante.jugada = null;
    }
    fase = 'entreRondas';
    _revisarFin();
  }

  // El jugador se rinde.
  void rendir(Participante participante) {
    if (!participante.jugando) {
      return;
    }
    participante.situacion = 'rendido';
    participante.jugada = null;
    _revisarFin();
  }

  // La partida termina en cuanto queda uno solo jugando (o ninguno). Si aun
  // no habia ganador (los demas se rindieron), gana el que queda.
  void _revisarFin() {
    final quedan = _jugando.toList();
    if (quedan.length > 1) {
      return;
    }
    if (quedan.length == 1 && ganadores.isEmpty) {
      ganadores.add(quedan.single.nombre);
    }
    fase = 'terminada';
  }
}
