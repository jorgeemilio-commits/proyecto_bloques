import 'package:flutter/material.dart';

abstract class TipoRegion {
  const TipoRegion();

  Color get color;
  String get descripcion;
  bool esPosibleAgregar(List<int> actuales, int posible);
  Map<int, int> get puntuaciones;

  static const TipoRegion amarillo = TipoAmarillo();
  static const TipoRegion rojo = TipoRojo();
  static const TipoRegion azul = TipoAzul();
  static const TipoRegion verde = TipoVerde();
  static const TipoRegion lila = TipoLila();
}

class TipoAzul extends TipoRegion {
  const TipoAzul();

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
  Color get color => const Color(0xFFFF0000);

  @override
  String get descripcion => 'No se permiten duplicados.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.toSet().length == actuales.length && !actuales.contains(posible);
  }

  @override
  Map<int, int> get puntuaciones => {1: 6, 2: 4, 3: 2};
}

class TipoAmarillo extends TipoRegion {
  const TipoAmarillo();

  @override
  Color get color => const Color(0xFFFFFF00);

  @override
  String get descripcion => 'No se permiten duplicados.';

  @override
  bool esPosibleAgregar(List<int> actuales, int posible) {
    return actuales.toSet().length == actuales.length && !actuales.contains(posible);
  }

  @override
  Map<int, int> get puntuaciones => {1: 8, 2: 6, 3: 4};
}

class TipoVerde extends TipoRegion {
  const TipoVerde();

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
