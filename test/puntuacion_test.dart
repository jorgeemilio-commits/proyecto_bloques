import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:proyecto_bloques/widgets/celda_widget.dart';
import 'package:proyecto_bloques/widgets/tablero_widget.dart';
import 'ayudantes.dart';
import 'consola.dart';

// Llena tres de las cuatro casillas de la region azul Z1 con 4, para
// que colocar un 4 en (2,0) la complete. (2,0) tiene al lado el 4 de (2,1).
void dejarAzulUnoCasiCompleta(Tablero tablero) {
  celdaEn(tablero, 2, 1).numero = 4;
  celdaEn(tablero, 3, 1).numero = 4;
  celdaEn(tablero, 3, 2).numero = 4;
}

void main() {
  test('una region solo esta completa con todas sus casillas llenas', () {
    final tablero = crearTableroConDiagonal();
    final azulUno = region('Z1');

    final vacia = tablero.regionCompleta(azulUno);
    dejarAzulUnoCasiCompleta(tablero);
    final casiCompleta = tablero.regionCompleta(azulUno);
    celdaEn(tablero, 2, 0).numero = 4;
    final completa = tablero.regionCompleta(azulUno);

    expect(vacia, isFalse);
    expect(casiCompleta, isFalse);
    expect(completa, isTrue);
    mostrar(
      'AzulUno vacia: $vacia; con 3 de 4: $casiCompleta; '
      'con 4 de 4: $completa.',
    );
  });

  group('RegistroDeReclamos', () {
    test('cada reclamo da el siguiente premio y despues del tercero 0', () {
      final registro = RegistroDeReclamos();
      final azulUno = region('Z1');

      final premios = [
        for (var vez = 0; vez < 5; vez++) registro.reclamar(azulUno),
      ];

      expect(premios, [7, 5, 3, 0, 0]);
      expect(registro.vecesReclamada(azulUno), 5);
      mostrar('Reclamos sucesivos de una region azul: $premios.');
    });

    test('los reclamos son por region, no por color', () {
      final registro = RegistroDeReclamos();

      final primeraAzul = registro.reclamar(region('Z1'));
      final segundaAzul = registro.reclamar(region('Z2'));

      expect(primeraAzul, 7);
      expect(segundaAzul, 7);
      mostrar(
        'AzulUno da $primeraAzul y AzulDos tambien da $segundaAzul '
        '(cada region tiene sus reclamos).',
      );
    });
  });

  group('Puntos al completar una region con un dado', () {
    test('completar una region suma su puntuacion', () async {
      final tablero = crearTableroConDiagonal();
      dejarAzulUnoCasiCompleta(tablero);
      final bloc = TurnoBloc(tablero, azar: AzarFijo([4, 4]));

      bloc.add(const TurnoIniciado());
      await bloc.stream.first;
      bloc.add(DadoColocado(0, celdaEn(tablero, 2, 0)));
      await bloc.stream.first;

      expect(bloc.state.puntos, 7);
      expect(bloc.state.ultimoReclamo?.region, region('Z1'));
      expect(bloc.state.ultimoReclamo?.puntos, 7);
      expect(bloc.state.turno, 2);
      mostrar(
        'Se completo la region ${bloc.state.ultimoReclamo!.region.tipo.nombre}: '
        '+${bloc.state.ultimoReclamo!.puntos}, total ${bloc.state.puntos}.',
      );

      await bloc.close();
    });

    test('colocar sin completar una region no da puntos', () async {
      final tablero = crearTableroConDiagonal();
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
      final tablero = crearTableroConDiagonal();
      dejarAzulUnoCasiCompleta(tablero);
      // Region azul Z2: (5,5) ya tiene el 6 de la diagonal; falta (6,4).
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

    test('pasar el turno borra el aviso de la region completada', () async {
      final tablero = crearTableroConDiagonal();
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

  group('Color de las regiones reclamadas', () {
    String porcentaje(double valor) => '${(valor * 100).round()}%';

    test(
      'cada reclamo apaga mas el color hasta el tercero, sin cambiar el tono',
      () {
        final colores = [
          for (var veces = 0; veces <= 4; veces++)
            HSLColor.fromColor(
              colorDeRegion(TipoRegion.azul, vecesReclamada: veces),
            ),
        ];
        final saturaciones = colores.map((c) => c.saturation).toList();
        final luminosidades = colores.map((c) => c.lightness).toList();

        for (var veces = 1; veces <= 3; veces++) {
          expect(saturaciones[veces], lessThan(saturaciones[veces - 1]));
          expect(luminosidades[veces], lessThan(luminosidades[veces - 1]));
        }
        // Despues del tercer reclamo ya no se apaga mas.
        expect(saturaciones[4], closeTo(saturaciones[3], 0.001));
        expect(luminosidades[4], closeTo(luminosidades[3], 0.001));
        // El azul sigue siendo azul aunque este apagado.
        expect(colores[3].hue, closeTo(colores[0].hue, 1));
        mostrar(
          'Saturacion por reclamos 0-4: '
          '${saturaciones.map(porcentaje).join(' ')}; '
          'luminosidad: ${luminosidades.map(porcentaje).join(' ')}.',
        );
      },
    );

    testWidgets('solo se apagan las casillas de la region reclamada', (
      tester,
    ) async {
      CeldaWidget celdaDibujada(int x, int y) => tester.widget<CeldaWidget>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CeldaWidget &&
              widget.celda.coordenada.x == x &&
              widget.celda.coordenada.y == y,
        ),
      );

      Color? colorDeFondo(int x, int y) {
        final contenedor = find
            .descendant(
              of: find.byWidget(celdaDibujada(x, y)),
              matching: find.byType(Container),
            )
            .first;
        final decoracion =
            tester.widget<Container>(contenedor).decoration as BoxDecoration?;
        return decoracion?.color;
      }

      final registro = RegistroDeReclamos()..reclamar(region('Z1'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableroWidget(
              tablero: crearTableroConDiagonal(),
              vecesReclamada: registro.vecesReclamada,
            ),
          ),
        ),
      );

      // (2,0), (2,1), (3,1) y (3,2) son AzulUno; (6,4) es AzulDos.
      final reclamadas = [
        for (final (x, y) in const [(2, 0), (2, 1), (3, 1), (3, 2)])
          celdaDibujada(x, y).vecesReclamada,
      ];
      final otraAzul = celdaDibujada(6, 4).vecesReclamada;

      expect(reclamadas, [1, 1, 1, 1]);
      expect(otraAzul, 0);
      expect(
        colorDeFondo(2, 0),
        colorDeRegion(TipoRegion.azul, vecesReclamada: 1),
      );
      expect(colorDeFondo(6, 4), colorDeRegion(TipoRegion.azul));
      mostrar(
        'AzulUno reclamada una vez: sus casillas $reclamadas; '
        'AzulDos sigue en $otraAzul.',
      );
    });
  });
}
