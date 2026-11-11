import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/cuenta/servicio_cuenta.dart';
import 'package:proyecto_bloques/multijugador/servicio_sala.dart';
import 'package:proyecto_bloques/pantallas/multijugador.dart';
import 'ayudantes.dart';
import 'consola.dart';

Finder porLlave(String llave) => find.byKey(ValueKey(llave));

void main() {
  late ServidorDeSalasFalso servidor;

  // Abre la pantalla con una sesion de Ana y el servidor de salas falso, ya
  // conectada y sin sala.
  Future<void> abrir(WidgetTester tester) async {
    final cuenta = ServicioDeCuenta(cliente: servidorFalso());
    await cuenta.crearCuenta('Ana', 'secreta123');
    await cuenta.iniciarSesion('Ana', 'secreta123');
    servidor = ServidorDeSalasFalso();
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaMultijugador(
          sala: ServicioDeSala(
            cuenta: cuenta,
            abrirCanal: servidor.abrir,
            esperaEntreIntentos: const Duration(milliseconds: 10),
          ),
        ),
      ),
    );
    servidor.mandarSinSala();
    await tester.pump();
  }

  // Cierra la pantalla, para que se desconecte y no queden tiempos pendientes.
  Future<void> cerrar(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('crear sala muestra la sala de espera y luego la partida', (
    tester,
  ) async {
    await abrir(tester);
    final entrada = porLlave('entrada-sala').evaluate().isNotEmpty;

    await tester.tap(porLlave('boton-crear-sala'));
    await tester.pump();
    final pidio = servidor.recibidos.last;
    servidor.mandarLobby();
    await tester.pump();
    final codigo = tester.widget<Text>(porLlave('codigo-sala')).data;
    final luisDesconectado = find
        .descendant(
          of: porLlave('jugador-Luis'),
          matching: find.textContaining('Desconectado'),
        )
        .evaluate()
        .isNotEmpty;
    final puedeIniciar =
        tester.widget<FilledButton>(porLlave('boton-iniciar')).onPressed !=
        null;

    await tester.tap(porLlave('boton-iniciar'));
    await tester.pump();
    final pidioIniciar = servidor.recibidos.last;
    servidor.mandar({
      'tipo': 'estado',
      'fase': 'valoresIniciales',
      'usuario': 'Ana',
      'codigo': 'K7MQ2P',
      'anfitrion': 'Ana',
      'mapa': 'clasico',
      'meta': 26,
      'jugadores': [
        {'usuario': 'Ana', 'conectado': true},
        {'usuario': 'Luis', 'conectado': true},
      ],
    });
    await tester.pump();
    // La partida se reconoce por el titulo de la barra.
    final partida = find.text('Partida').evaluate().isNotEmpty;

    // Rendirse pide confirmacion antes de mandarlo.
    await tester.tap(porLlave('boton-rendirse'));
    await tester.pumpAndSettle();
    final antesDeConfirmar = servidor.recibidos.last;
    await tester.tap(porLlave('confirmar-rendirse'));
    await tester.pumpAndSettle();
    final rendido = servidor.recibidos.last;
    await cerrar(tester);

    expect(entrada, isTrue);
    expect(pidio, {'tipo': 'crearSala'});
    expect(codigo, 'K7MQ2P');
    expect(luisDesconectado, isTrue);
    expect(puedeIniciar, isTrue);
    expect(pidioIniciar, {'tipo': 'iniciar'});
    expect(partida, isTrue);
    expect(antesDeConfirmar, {'tipo': 'iniciar'});
    expect(rendido, {'tipo': 'rendirse'});
    mostrar(
      'Crear sala -> sala $codigo con Luis desconectado -> iniciar -> '
      'rendirse (con confirmacion).',
    );
  });

  testWidgets('unirse con codigo, ver el error y la barra de reconexion', (
    tester,
  ) async {
    await abrir(tester);

    await tester.enterText(porLlave('campo-codigo'), 'k7mq2p');
    await tester.tap(porLlave('boton-unirse'));
    await tester.pump();
    final pidio = servidor.recibidos.last;
    servidor.mandar({
      'tipo': 'error',
      'codigo': 'salaNoExiste',
      'mensaje': 'No existe una sala con ese código.',
    });
    await tester.pump();
    final error = find
        .text('No existe una sala con ese código.')
        .evaluate()
        .isNotEmpty;

    servidor.cortar();
    await tester.pump();
    final reconectando = porLlave('barra-reconectando').evaluate().isNotEmpty;
    await cerrar(tester);

    expect(pidio, {'tipo': 'unirse', 'codigo': 'k7mq2p'});
    expect(error, isTrue);
    expect(reconectando, isTrue);
    mostrar('Unirse con k7mq2p -> error en pantalla; al caer, "Reconectando".');
  });

  testWidgets(
    'sin flecha en la sala; atras en la partida pregunta y se rinde',
    (tester) async {
      final cuenta = ServicioDeCuenta(cliente: servidorFalso());
      await cuenta.crearCuenta('Ana', 'secreta123');
      await cuenta.iniciarSesion('Ana', 'secreta123');
      servidor = ServidorDeSalasFalso();
      // La pantalla se abre encima de otra, como desde el menu.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PantallaMultijugador(
                    sala: ServicioDeSala(
                      cuenta: cuenta,
                      abrirCanal: servidor.abrir,
                    ),
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      // Mientras conecta hay un circulo girando: se espera la animacion de
      // entrada en lugar de pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // En la sala de espera no hay flecha de atras, solo "Borrar sala".
      servidor.mandarLobby();
      await tester.pump();
      final flechaEnLobby = find.byType(BackButton).evaluate().isNotEmpty;
      final botonDelAnfitrion = find
          .descendant(
            of: porLlave('boton-salir-sala'),
            matching: find.text('Borrar sala'),
          )
          .evaluate()
          .isNotEmpty;
      servidor.mandar({
        'tipo': 'estado',
        'fase': 'valoresIniciales',
        'usuario': 'Ana',
        'codigo': 'K7MQ2P',
        'anfitrion': 'Ana',
        'mapa': 'clasico',
        'meta': 26,
        'jugadores': [
          {'usuario': 'Ana', 'conectado': true},
          {'usuario': 'Luis', 'conectado': true},
        ],
      });
      await tester.pump();

      // Atras y "Cancelar": sigue en la partida.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      final sigueAlCancelar = find.text('Partida').evaluate().isNotEmpty;

      // Atras y "Rendirme": se rinde y vuelve al menu.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(porLlave('confirmar-rendirse'));
      await tester.pumpAndSettle();

      expect(flechaEnLobby, isFalse);
      expect(botonDelAnfitrion, isTrue);
      expect(sigueAlCancelar, isTrue);
      expect(porLlave('pantalla-multijugador'), findsNothing);
      expect(servidor.recibidos.last, {'tipo': 'rendirse'});
      mostrar('Atras en la partida: Cancelar sigue; Rendirme manda rendirse.');
    },
  );

  testWidgets(
    'partida: manda los valores, pasa, ve al rival y los resultados',
    (tester) async {
      await abrir(tester);
      // Estado de la partida con lo que cambia en cada fase.
      void mandarPartida(
        String fase, {
        List<int>? misIniciales,
        bool yaJugue = false,
        List<String> ganadores = const [],
      }) => servidor.mandar({
        'tipo': 'estado',
        'fase': fase,
        'usuario': 'Ana',
        'codigo': 'K7MQ2P',
        'anfitrion': 'Ana',
        'mapa': 'clasico',
        'meta': 26,
        'ronda': fase == 'valoresIniciales' ? 0 : 1,
        'dados': fase == 'valoresIniciales' ? null : [3, 5],
        'ganadores': ganadores,
        'reclamos': <String, int>{},
        'jugadores': [
          {
            'usuario': 'Ana',
            'conectado': true,
            'situacion': ganadores.contains('Ana') ? 'llegoALaMeta' : 'jugando',
            'yaJugo': yaJugue,
            'puntos': ganadores.contains('Ana') ? 26 : 0,
            'iniciales': misIniciales,
            'casillas': <List<int>>[],
          },
          {
            'usuario': 'Luis',
            'conectado': true,
            'situacion': 'jugando',
            'yaJugo': false,
            'puntos': 7,
            'iniciales': fase == 'valoresIniciales' ? null : [1, 2, 3, 4, 5, 6],
            'casillas': [
              [3, 0, 4],
            ],
          },
        ],
      });

      // Valores iniciales: al azar y "Listo".
      mandarPartida('valoresIniciales');
      await tester.pumpAndSettle();
      await tester.tap(porLlave('boton-aleatorio'));
      await tester.pump();
      await tester.tap(porLlave('boton-listo'));
      await tester.pump();
      final valores = servidor.recibidos.last;

      // Ronda 1: se ve al rival y se puede pasar.
      mandarPartida('ronda', misIniciales: [6, 5, 4, 3, 2, 1]);
      await tester.pumpAndSettle();
      final veAlRival = porLlave('rival-Luis').evaluate().isNotEmpty;
      await tester.tap(porLlave('boton-pasar'));
      await tester.pump();
      final paso = servidor.recibidos.last;
      final esperando = porLlave('esperando-ronda').evaluate().isNotEmpty;

      // Fin: Ana gano.
      mandarPartida(
        'terminada',
        misIniciales: [6, 5, 4, 3, 2, 1],
        ganadores: ['Ana'],
      );
      await tester.pumpAndSettle();
      final gano = find.text('¡Ganaste!').evaluate().isNotEmpty;
      await cerrar(tester);

      expect(valores['tipo'], 'valoresIniciales');
      expect((valores['valores'] as List).toSet(), {1, 2, 3, 4, 5, 6});
      expect(veAlRival, isTrue);
      expect(paso, {'tipo': 'pasar', 'ronda': 1});
      expect(esperando, isTrue);
      expect(gano, isTrue);
      mostrar(
        'Valores ${valores['valores']} -> ronda 1: pasa y espera -> ¡Ganaste!',
      );
    },
  );

  testWidgets(
    'aviso que entra por la derecha si un rival completa una region',
    (tester) async {
      await abrir(tester);
      // Ronda 1 y, al terminar, Luis completo la region Z1 (+7).
      void mandarRonda(String fase, {bool luisReclamo = false}) =>
          servidor.mandar({
            'tipo': 'estado',
            'fase': fase,
            'usuario': 'Ana',
            'codigo': 'K7MQ2P',
            'anfitrion': 'Ana',
            'mapa': 'clasico',
            'meta': 26,
            'ronda': 1,
            'dados': [3, 5],
            'ganadores': <String>[],
            'reclamos': luisReclamo ? {'Z1': 1} : <String, int>{},
            'jugadores': [
              {
                'usuario': 'Ana',
                'conectado': true,
                'iniciales': [1, 2, 3, 4, 5, 6],
              },
              {
                'usuario': 'Luis',
                'conectado': true,
                'puntos': luisReclamo ? 7 : 0,
                'iniciales': [6, 5, 4, 3, 2, 1],
                'ultimoReclamo': luisReclamo
                    ? {'region': 'Z1', 'puntos': 7}
                    : null,
              },
            ],
          });

      mandarRonda('ronda');
      await tester.pumpAndSettle();
      mandarRonda('entreRondas', luisReclamo: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final aviso = find.byKey(const ValueKey('texto-aviso-reclamo'));
      final texto = aviso.evaluate().isEmpty
          ? null
          : tester.widget<Text>(aviso).textSpan!.toPlainText();
      // A los pocos segundos se desvanece y se quita.
      await tester.pump(const Duration(seconds: 4));
      final sigue = aviso.evaluate().isNotEmpty;
      await cerrar(tester);

      expect(texto, startsWith('Luis completó una región'));
      expect(texto, endsWith('+7'));
      expect(sigue, isFalse);
      mostrar('Aviso: "$texto" y luego se quita solo.');
    },
  );

  testWidgets('el anfitrion elige el mapa con las tarjetas, como en offline', (
    tester,
  ) async {
    await abrir(tester);
    servidor.mandarLobby();
    await tester.pumpAndSettle();
    final tarjeta = porLlave('mapa-de-la-sala').evaluate().isNotEmpty;

    await tester.ensureVisible(porLlave('mapa-de-la-sala'));
    await tester.tap(porLlave('mapa-de-la-sala'));
    await tester.pumpAndSettle();
    final abrioLaEleccion = porLlave('seleccion-mapa').evaluate().isNotEmpty;
    await tester.ensureVisible(porLlave('mapa-borde'));
    await tester.pumpAndSettle();
    await tester.tap(porLlave('mapa-borde'));
    await tester.pumpAndSettle();
    final pidio = servidor.recibidos.last;
    final regreso = porLlave('seleccion-mapa').evaluate().isEmpty;
    await cerrar(tester);

    expect(tarjeta, isTrue);
    expect(abrioLaEleccion, isTrue);
    expect(pidio, {'tipo': 'elegirMapa', 'mapa': 'borde'});
    expect(regreso, isTrue);
    mostrar('Tarjeta del mapa -> Elige un mapa -> Borde -> elegirMapa borde.');
  });

  testWidgets('al salir de la pantalla en el lobby, sale de la sala', (
    tester,
  ) async {
    await abrir(tester);
    servidor.mandarLobby(anfitrion: 'Luis');
    await tester.pump();
    final esperando = find
        .textContaining('Esperando a que el anfitrión')
        .evaluate()
        .isNotEmpty;
    final sinBotonIniciar = porLlave('boton-iniciar').evaluate().isEmpty;

    await cerrar(tester);

    expect(esperando, isTrue);
    expect(sinBotonIniciar, isTrue);
    expect(servidor.recibidos.last, {'tipo': 'salir'});
    mostrar(
      'No anfitrion: espera sin boton de iniciar; al cerrar manda salir.',
    );
  });
}
