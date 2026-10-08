import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/main.dart' show VistaPreviaTablero;
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'ayudantes.dart';
import 'consola.dart';

// Llena tres de las cuatro casillas de la region RegionAzulUno con 4, para
// que colocar un 4 en (2,0) la complete. (2,0) tiene al lado el 4 de (2,1).
void dejarAzulUnoCasiCompleta(Tablero tablero) {
  celdaEn(tablero, 2, 1).numero = 4;
  celdaEn(tablero, 3, 1).numero = 4;
  celdaEn(tablero, 3, 2).numero = 4;
}

void main() {
  group('Region completa', () {
    test('una region con casillas vacias no esta completa', () {
      final tablero = crearTableroConIniciales();
      const region = RegionAzulUno();

      expect(tablero.regionCompleta(region), isFalse);
      mostrar('AzulUno vacia: completa = ${tablero.regionCompleta(region)}.');
    });

    test('una region con todas sus casillas llenas esta completa', () {
      final tablero = crearTableroConIniciales();
      const region = RegionAzulUno();
      dejarAzulUnoCasiCompleta(tablero);

      final casiCompleta = tablero.regionCompleta(region);
      celdaEn(tablero, 2, 0).numero = 4;
      final completa = tablero.regionCompleta(region);

      expect(casiCompleta, isFalse);
      expect(completa, isTrue);
      mostrar('AzulUno con 3 de 4: $casiCompleta; con 4 de 4: $completa.');
    });
  });

  group('RegistroDeReclamos', () {
    test('cada reclamo da el siguiente premio y despues del tercero 0', () {
      final registro = RegistroDeReclamos();
      const region = RegionAzulUno();

      final premios = [
        for (var vez = 0; vez < 5; vez++) registro.reclamar(region),
      ];

      expect(premios, [7, 5, 3, 0, 0]);
      expect(registro.vecesReclamada(region), 5);
      mostrar('Reclamos sucesivos de una region azul: $premios.');
    });

    test('los reclamos son por region, no por color', () {
      final registro = RegistroDeReclamos();

      final primeraAzul = registro.reclamar(const RegionAzulUno());
      final segundaAzul = registro.reclamar(const RegionAzulDos());

      expect(primeraAzul, 7);
      expect(segundaAzul, 7);
      mostrar(
        'AzulUno da $primeraAzul y AzulDos tambien da $segundaAzul '
        '(cada region tiene sus reclamos).',
      );
    });

    test('el primer reclamo de cada color da su puntuacion mas alta', () {
      final registro = RegistroDeReclamos();
      final primeros = {
        'amarilla': registro.reclamar(const RegionAmarilla()),
        'azul': registro.reclamar(const RegionAzulUno()),
        'roja': registro.reclamar(const RegionRojaUno()),
        'lila': registro.reclamar(const RegionLilaUno()),
        'verde': registro.reclamar(const RegionVerdeUno()),
      };

      expect(primeros, {
        'amarilla': 8,
        'azul': 7,
        'roja': 6,
        'lila': 6,
        'verde': 4,
      });
      mostrar('Primer reclamo por color: $primeros.');
    });

    test('puntosDisponibles no registra un reclamo', () {
      final registro = RegistroDeReclamos();
      const region = RegionVerdeUno();

      final disponibles = registro.puntosDisponibles(region);

      expect(disponibles, 4);
      expect(registro.vecesReclamada(region), 0);
      mostrar('Verde disponible: $disponibles; reclamos: 0.');
    });
  });

  group('Puntos al completar una region con un dado', () {
    test('completar una region suma su puntuacion', () async {
      final tablero = crearTableroConIniciales();
      dejarAzulUnoCasiCompleta(tablero);
      final bloc = TurnoBloc(tablero, azar: AzarFijo([4, 4]));

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(0, celdaEn(tablero, 2, 0)));
      await bloc.stream.first;

      expect(bloc.state.puntos, 7);
      expect(bloc.state.ultimoReclamo?.region, const RegionAzulUno());
      expect(bloc.state.ultimoReclamo?.puntos, 7);
      expect(bloc.state.turno, 2);
      mostrar(
        'Se completo la region ${bloc.state.ultimoReclamo!.region.tipo.nombre}: '
        '+${bloc.state.ultimoReclamo!.puntos}, total ${bloc.state.puntos}.',
      );

      await bloc.close();
    });

    test('colocar sin completar una region no da puntos', () async {
      final tablero = crearTableroConIniciales();
      final bloc = TurnoBloc(tablero, azar: AzarFijo([1, 5]));

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(1, celdaEn(tablero, 1, 0)));
      await bloc.stream.first;

      expect(bloc.state.puntos, 0);
      expect(bloc.state.ultimoReclamo, isNull);
      mostrar(
        'Se coloco 5 en (1,0) sin completar region: '
        'puntos ${bloc.state.puntos}.',
      );

      await bloc.close();
    });

    test('los puntos de varias regiones se acumulan', () async {
      final tablero = crearTableroConIniciales();
      dejarAzulUnoCasiCompleta(tablero);
      // RegionAzulDos: (5,5) ya tiene el 6 inicial; falta (6,4).
      celdaEn(tablero, 6, 5).numero = 6;
      celdaEn(tablero, 5, 6).numero = 6;
      final bloc = TurnoBloc(tablero, azar: AzarFijo([4, 4, 6, 6]));

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(0, celdaEn(tablero, 2, 0)));
      await bloc.stream.first;
      final despuesDeLaPrimera = bloc.state.puntos;
      bloc.add(DadoColocado(0, celdaEn(tablero, 6, 4)));
      await bloc.stream.first;

      expect(despuesDeLaPrimera, 7);
      expect(bloc.state.puntos, 14);
      mostrar(
        'AzulUno: $despuesDeLaPrimera pts; con AzulDos: '
        '${bloc.state.puntos} pts.',
      );

      await bloc.close();
    });

    test('una region ya reclamada da el siguiente premio', () async {
      final tablero = crearTableroConIniciales();
      dejarAzulUnoCasiCompleta(tablero);
      final registro = RegistroDeReclamos()..reclamar(const RegionAzulUno());
      final bloc = TurnoBloc(
        tablero,
        azar: AzarFijo([4, 4]),
        reclamos: registro,
      );

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(0, celdaEn(tablero, 2, 0)));
      await bloc.stream.first;

      expect(bloc.state.puntos, 5);
      mostrar(
        'AzulUno ya reclamada una vez: da ${bloc.state.puntos} '
        '(segundo premio).',
      );

      await bloc.close();
    });

    test('despues del tercer reclamo la region ya no da puntos', () async {
      final tablero = crearTableroConIniciales();
      dejarAzulUnoCasiCompleta(tablero);
      final registro = RegistroDeReclamos();
      for (var vez = 0; vez < 3; vez++) {
        registro.reclamar(const RegionAzulUno());
      }
      final bloc = TurnoBloc(
        tablero,
        azar: AzarFijo([4, 4]),
        reclamos: registro,
      );

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(0, celdaEn(tablero, 2, 0)));
      await bloc.stream.first;

      expect(bloc.state.puntos, 0);
      expect(bloc.state.ultimoReclamo?.puntos, 0);
      mostrar(
        'AzulUno reclamada 3 veces: da ${bloc.state.ultimoReclamo!.puntos} pts.',
      );

      await bloc.close();
    });

    test('pasar el turno borra el aviso de la region completada', () async {
      final tablero = crearTableroConIniciales();
      dejarAzulUnoCasiCompleta(tablero);
      final bloc = TurnoBloc(tablero, azar: AzarFijo([4, 4]));

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(0, celdaEn(tablero, 2, 0)));
      await bloc.stream.first;
      bloc.add(const TurnoPasado());
      await bloc.stream.first;

      expect(bloc.state.ultimoReclamo, isNull);
      expect(bloc.state.puntos, 7);
      mostrar(
        'Tras pasar: aviso = ${bloc.state.ultimoReclamo}, '
        'puntos conservados = ${bloc.state.puntos}.',
      );

      await bloc.close();
    });
  });

  testWidgets('al iniciar la partida se muestran 0 puntos', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VistaPreviaTablero()));

    final celdasIniciales = find.byWidgetPredicate(
      (widget) => widget is CeldaWidget && widget.esInicial,
    );
    const numeros = [1, 2, 3, 5, 6];

    for (var indice = 0; indice < numeros.length; indice++) {
      await tester.tap(celdasIniciales.at(indice + 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${numeros[indice]}').last);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.widgetWithText(FilledButton, 'Listo'));
    await tester.pumpAndSettle();

    expect(find.text('0 pts'), findsOneWidget);
    mostrar('El encabezado muestra "0 pts" en el Turno 1.');
  });
}
