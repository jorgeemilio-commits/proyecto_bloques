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
    final partida = porLlave('partida-pendiente').evaluate().isNotEmpty;

    // Al cerrar la pantalla en la partida no se manda "salir".
    await cerrar(tester);

    expect(entrada, isTrue);
    expect(pidio, {'tipo': 'crearSala'});
    expect(codigo, 'K7MQ2P');
    expect(luisDesconectado, isTrue);
    expect(puedeIniciar, isTrue);
    expect(pidioIniciar, {'tipo': 'iniciar'});
    expect(partida, isTrue);
    expect(servidor.recibidos.last, {'tipo': 'iniciar'});
    mostrar('Crear sala -> sala $codigo con Luis desconectado -> iniciar.');
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
