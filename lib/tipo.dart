import 'package:flutter/material.dart';

abstract class TipoRegion {
  const TipoRegion();

  Color get color;
  // Nombre del color como se dice de una region ("region roja").
  String get nombre;
  String get descripcion;
  bool esPosibleAgregar(List<int> actuales, int posible);
  Map<int, int> get puntuaciones;

  static const TipoRegion amarillo = TipoAmarillo();
  static const TipoRegion rojo = TipoRojo();
  static const TipoRegion azul = TipoAzul();
  static const TipoRegion verde = TipoVerde();
  static const TipoRegion lila = TipoLila();
  static const TipoRegion blanco = TipoBlanco();
  static const TipoRegion naranjaBaja = TipoNaranja(minimo: 1, maximo: 3);
  static const TipoRegion naranjaAlta = TipoNaranja(minimo: 4, maximo: 6);
}

// Naranja: solo acepta numeros dentro de su rango. Hay dos regiones naranjas
// con el mismo color pero distinto rango (1-3 y 4-6), asi que funcionan como
// dos tipos distintos.
class TipoNaranja extends TipoRegion {
  final int minimo;
  final int maximo;

  const TipoNaranja({required this.minimo, required this.maximo});

  @override
  String get nombre => 'naranja';

  @override
  Color get color => const Color(0xFFFF8000);

  @override
  String get descripcion => 'Solo números del $minimo al $maximo.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) =>
      posible >= minimo && posible <= maximo;

  @override
  Map<int, int> get puntuaciones => {1: 6, 2: 4, 3: 3};
}

class TipoBlanco extends TipoRegion {
  const TipoBlanco();

  @override
  String get nombre => 'blanca';

  @override
  Color get color => const Color(0xFFFFFFFF);

  @override
  String get descripcion => 'Todos los números deben ser iguales.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.isEmpty || actuales.every((element) => element == posible);
  }

  @override
  Map<int, int> get puntuaciones => {1: 3, 2: 2, 3: 1};
}

class TipoAzul extends TipoRegion {
  const TipoAzul();

  @override
  String get nombre => 'azul';

  @override
  Color get color => const Color(0xFF0000FF);

  @override
  String get descripcion => 'Todos los números deben ser iguales.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.isEmpty || actuales.every((element) => element == posible);
  }

  @override
  Map<int, int> get puntuaciones => {1: 7, 2: 5, 3: 3};
}

class TipoRojo extends TipoRegion {
  const TipoRojo();

  @override
  String get nombre => 'roja';

  @override
  Color get color => const Color(0xFFFF0000);

  @override
  String get descripcion => 'No se permiten duplicados.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.toSet().length == actuales.length &&
        !actuales.contains(posible);
  }

  @override
  Map<int, int> get puntuaciones => {1: 6, 2: 4, 3: 2};
}

class TipoAmarillo extends TipoRegion {
  const TipoAmarillo();

  @override
  String get nombre => 'amarilla';

  @override
  Color get color => const Color(0xFFFFFF00);

  @override
  String get descripcion => 'No se permiten duplicados.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.toSet().length == actuales.length &&
        !actuales.contains(posible);
  }

  @override
  Map<int, int> get puntuaciones => {1: 8, 2: 6, 3: 4};
}

class TipoVerde extends TipoRegion {
  const TipoVerde();

  @override
  String get nombre => 'verde';

  @override
  Color get color => const Color(0xFF00FF00);

  @override
  String get descripcion => 'Cualquier número es válido.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) => true;

  @override
  Map<int, int> get puntuaciones => {1: 4, 2: 3, 3: 2};
}

class TipoLila extends TipoRegion {
  const TipoLila();

  @override
  String get nombre => 'lila';

  @override
  Color get color => const Color(0xFF800080);

  @override
  String get descripcion => 'Solo se permiten hasta dos números diferentes.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return {...actuales, posible}.length <= 2;
  }

  @override
  Map<int, int> get puntuaciones => {1: 6, 2: 4, 3: 2};
}
