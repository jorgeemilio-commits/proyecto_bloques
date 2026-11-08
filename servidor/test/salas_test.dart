import 'dart:convert';
import 'dart:io';

import 'package:servidor/src/base_de_datos.dart';
import 'package:servidor/src/rutas.dart';
import 'package:servidor/src/salas.dart';
import 'package:servidor/src/seguridad.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Conexion falsa: guarda lo que le manda el servidor.
class ConexionFalsa implements Conexion {
  final List<Map<String, Object?>> mensajes = [];
  bool cerrada = false;

  // Se guarda una copia hecha con JSON, como lo que viaja por la red: asi los
  // cambios posteriores del servidor no alteran lo que ya se "envio".
  @override
  void enviar(Map<String, Object?> mensaje) =>
      mensajes.add(jsonDecode(jsonEncode(mensaje)) as Map<String, Object?>);

  @override
  void cerrar() => cerrada = true;

  List<Map<String, Object?>> deTipo(String tipo) =>
      mensajes.where((mensaje) => mensaje['tipo'] == tipo).toList();

  Map<String, Object?> get estado => deTipo('estado').last;
  String? get ultimoError => deTipo('error').lastOrNull?['codigo'] as String?;

  List<String> get jugadores => [
    for (final jugador in estado['jugadores'] as List)
      (jugador as Map)['usuario'] as String,
  ];

  // Datos de cada jugador en la partida, por su nombre.
  Map<String, Map<String, Object?>> get enPartida => {
    for (final jugador in estado['jugadores'] as List)
      (jugador as Map)['usuario'] as String: jugador.cast<String, Object?>(),
  };

  Map<String, Object?> get situaciones => {
    for (final MapEntry(:key, :value) in enPartida.entries)
      key: value['situacion'],
  };
}

const _esperaCorta = Duration(milliseconds: 50);

void main() {
  late Salas salas;

  setUp(() {
    // En las pruebas el token es "token-<usuario>".
    salas = Salas(
      usuarioDelToken: (token) =>
          token.startsWith('token-') ? token.substring(6) : null,
      esperaReconexion: _esperaCorta,
    );
  });

  tearDown(() => salas.cerrar());

  void mandar(ConexionFalsa conexion, Map<String, Object?> mensaje) =>
      salas.recibir(conexion, jsonEncode(mensaje));

  // Conecta al usuario y manda "hola".
  ConexionFalsa conectar(String usuario) {
    final conexion = ConexionFalsa();
    salas.conectar(conexion);
    mandar(conexion, {'tipo': 'hola', 'token': 'token-$usuario'});
    return conexion;
  }

  test('crear una sala y unirse con el codigo', () {
    final ana = conectar('Ana');
    final luis = conectar('Luis');

    mandar(ana, {'tipo': 'crearSala'});
    final codigo = ana.estado['codigo'] as String;
    // Se puede escribir en minusculas y con espacios.
    mandar(luis, {'tipo': 'unirse', 'codigo': ' ${codigo.toLowerCase()} '});

    expect(codigo, matches(RegExp(r'^[A-HJKMNP-Z2-9]{6}$')));
    expect(ana.estado['fase'], 'lobby');
    expect(ana.estado['anfitrion'], 'Ana');
    expect(ana.jugadores, ['Ana', 'Luis']);
    expect(luis.jugadores, ['Ana', 'Luis']);
    expect(luis.estado['mapa'], 'clasico');
  });

  test('errores del lobby', () {
    final ana = conectar('Ana');
    mandar(ana, {'tipo': 'crearSala'});
    final codigo = ana.estado['codigo'];

    final otro = conectar('Otro');
    mandar(otro, {'tipo': 'unirse', 'codigo': 'ZZZZZZ'});
    final noExiste = otro.ultimoError;
    mandar(ana, {'tipo': 'iniciar'});
    final faltan = ana.ultimoError;
    mandar(ana, {'tipo': 'crearSala'});
    final yaEnSala = ana.ultimoError;

    // Se llena con 6 jugadores.
    for (final nombre in ['B', 'C', 'D', 'E', 'F']) {
      mandar(conectar(nombre), {'tipo': 'unirse', 'codigo': codigo});
    }
    mandar(otro, {'tipo': 'unirse', 'codigo': codigo});
    final llena = otro.ultimoError;
    mandar(otro, {'tipo': 'nadaQueVer'});
    final invalido = otro.ultimoError;

    expect(noExiste, 'salaNoExiste');
    expect(faltan, 'faltanJugadores');
    expect(yaEnSala, 'yaEnSala');
    expect(llena, 'salaLlena');
    expect(invalido, 'mensajeInvalido');
    expect(ana.jugadores, hasLength(6));
  });

  test('solo el anfitrion elige el mapa e inicia; luego ya no se entra', () {
    final ana = conectar('Ana');
    final luis = conectar('Luis');
    final tarde = conectar('Tarde');
    mandar(ana, {'tipo': 'crearSala'});
    final codigo = ana.estado['codigo'];
    mandar(luis, {'tipo': 'unirse', 'codigo': codigo});

    mandar(luis, {'tipo': 'iniciar'});
    final errorDeLuis = luis.ultimoError;
    mandar(ana, {'tipo': 'elegirMapa', 'mapa': 'borde'});
    mandar(ana, {'tipo': 'iniciar'});
    mandar(tarde, {'tipo': 'unirse', 'codigo': codigo});

    expect(errorDeLuis, 'soloAnfitrion');
    expect(luis.estado['mapa'], 'borde');
    expect(luis.estado['fase'], 'valoresIniciales');
    // Con 2 jugadores la meta es 26.
    expect(luis.estado['meta'], 26);
    expect(tarde.ultimoError, 'partidaEmpezada');
  });

  test(
    'si sale un jugador sigue la sala; si sale el anfitrion, se deshace',
    () {
      final ana = conectar('Ana');
      final luis = conectar('Luis');
      final eva = conectar('Eva');
      mandar(ana, {'tipo': 'crearSala'});
      final codigo = ana.estado['codigo'] as String;
      mandar(luis, {'tipo': 'unirse', 'codigo': codigo});
      mandar(eva, {'tipo': 'unirse', 'codigo': codigo});

      mandar(eva, {'tipo': 'salir'});
      final quedan = ana.jugadores;
      mandar(ana, {'tipo': 'salir'});

      expect(quedan, ['Ana', 'Luis']);
      expect(eva.estado['fase'], 'sinSala');
      // Al salir el anfitrion, todos quedan sin sala y la sala se borra.
      expect(ana.estado['fase'], 'sinSala');
      expect(luis.estado['fase'], 'sinSala');
      expect(luis.deTipo('aviso').last['texto'], 'El anfitrión cerró la sala.');
      expect(salas.sala(codigo), isNull);
    },
  );

  test(
    'si el anfitrion se desconecta y no vuelve, la sala se deshace',
    () async {
      final ana = conectar('Ana');
      final luis = conectar('Luis');
      mandar(ana, {'tipo': 'crearSala'});
      final codigo = ana.estado['codigo'] as String;
      mandar(luis, {'tipo': 'unirse', 'codigo': codigo});

      salas.desconectar(ana);
      final sigueAlCaer = luis.estado['fase'];
      await Future<void>.delayed(_esperaCorta * 2);

      expect(sigueAlCaer, 'lobby');
      expect(luis.estado['fase'], 'sinSala');
      expect(salas.sala(codigo), isNull);
    },
  );

  test(
    'desconectarse: puede volver a tiempo; si no, sale de la sala',
    () async {
      final ana = conectar('Ana');
      var luis = conectar('Luis');
      mandar(ana, {'tipo': 'crearSala'});
      mandar(luis, {'tipo': 'unirse', 'codigo': ana.estado['codigo']});

      // Se cae y vuelve antes de que acabe el tiempo.
      salas.desconectar(luis);
      final conectadoAlCaer = (ana.estado['jugadores'] as List)[1];
      luis = conectar('Luis');
      await Future<void>.delayed(_esperaCorta * 2);
      final sigueTrasVolver = ana.jugadores;

      // Se cae y no vuelve.
      salas.desconectar(luis);
      await Future<void>.delayed(_esperaCorta * 2);

      expect(conectadoAlCaer, {'usuario': 'Luis', 'conectado': false});
      expect(sigueTrasVolver, ['Ana', 'Luis']);
      expect(luis.estado['fase'], 'lobby');
      expect(ana.jugadores, ['Ana']);
      expect(ana.deTipo('aviso').map((aviso) => aviso['texto']), [
        'Luis se desconectó.',
        'Luis volvió.',
        'Luis se desconectó.',
        'Luis salió de la sala.',
      ]);
    },
  );

  test('la misma cuenta en otra conexion reemplaza a la vieja', () {
    final vieja = conectar('Ana');
    mandar(vieja, {'tipo': 'crearSala'});
    final codigo = vieja.estado['codigo'];

    final nueva = conectar('Ana');

    expect(vieja.ultimoError, 'sesionReemplazada');
    expect(vieja.cerrada, isTrue);
    // La conexion nueva sigue en la misma sala.
    expect(nueva.estado['codigo'], codigo);
  });

  test('iniciar sesion en otro dispositivo saca a la conexion vieja', () {
    final ana = conectar('Ana');
    final luis = conectar('Luis');
    mandar(ana, {'tipo': 'crearSala'});
    mandar(luis, {'tipo': 'unirse', 'codigo': ana.estado['codigo']});

    salas.sesionNueva('Luis');

    expect(luis.ultimoError, 'sesionReemplazada');
    expect(luis.cerrada, isTrue);
    // Para los demas es como si se le cayera la red: sigue en la sala.
    expect(ana.estado['jugadores'], [
      {'usuario': 'Ana', 'conectado': true},
      {'usuario': 'Luis', 'conectado': false},
    ]);
  });

  test('sin un token valido no se puede entrar', () {
    final conexion = ConexionFalsa();
    salas.conectar(conexion);
    mandar(conexion, {'tipo': 'hola', 'token': 'falso'});

    expect(conexion.ultimoError, 'sesionInvalida');
    expect(conexion.cerrada, isTrue);
  });

  test(
    'en la partida: rendirse, o no volver a tiempo, deja la partida',
    () async {
      final ana = conectar('Ana');
      final luis = conectar('Luis');
      final eva = conectar('Eva');
      mandar(ana, {'tipo': 'crearSala'});
      final codigo = ana.estado['codigo'] as String;
      mandar(luis, {'tipo': 'unirse', 'codigo': codigo});
      mandar(eva, {'tipo': 'unirse', 'codigo': codigo});
      mandar(ana, {'tipo': 'iniciar'});

      mandar(luis, {'tipo': 'rendirse'});
      final faseDeLuis = luis.estado['fase'];
      // Eva se cae: al volver a tiempo sigue en la partida.
      salas.desconectar(eva);
      final evaVuelve = conectar('Eva');
      final faseAlVolver = evaVuelve.estado['fase'];
      // Se cae otra vez y ya no vuelve.
      salas.desconectar(evaVuelve);
      await Future<void>.delayed(_esperaCorta * 2);
      // Ya sin partida, Eva puede entrar a otra sala.
      final evaDespues = conectar('Eva');

      expect(faseDeLuis, 'sinSala');
      expect(faseAlVolver, 'valoresIniciales');
      expect(evaDespues.estado['fase'], 'sinSala');
      // Los que se rindieron siguen en la lista; Ana quedo sola y gano.
      expect(ana.situaciones, {
        'Ana': 'jugando',
        'Luis': 'rendido',
        'Eva': 'rendido',
      });
      expect(ana.estado['fase'], 'terminada');
      expect(ana.estado['ganadores'], ['Ana']);
      expect(ana.deTipo('aviso').map((aviso) => aviso['texto']), [
        'Luis se rindió.',
        'Eva se desconectó.',
        'Eva volvió.',
        'Eva se desconectó.',
        'Eva se rindió.',
      ]);
    },
  );

  group('partida', () {
    // Tiempos cortos para que la partida avance rapido en las pruebas.
    setUp(() {
      salas.cerrar();
      salas = Salas(
        usuarioDelToken: (token) =>
            token.startsWith('token-') ? token.substring(6) : null,
        esperaReconexion: const Duration(seconds: 5),
        esperaValoresIniciales: const Duration(milliseconds: 60),
        esperaRonda: const Duration(milliseconds: 100),
        esperaEntreRondas: const Duration(milliseconds: 20),
        esperaSalaTerminada: const Duration(milliseconds: 50),
      );
    });

    // Ana y Luis en una sala con la partida ya iniciada.
    (ConexionFalsa, ConexionFalsa) iniciada() {
      final ana = conectar('Ana');
      final luis = conectar('Luis');
      mandar(ana, {'tipo': 'crearSala'});
      mandar(luis, {'tipo': 'unirse', 'codigo': ana.estado['codigo']});
      mandar(ana, {'tipo': 'iniciar'});
      return (ana, luis);
    }

    test(
      'valores iniciales: ocultos para los demas; al azar si no llegan',
      () async {
        final (ana, luis) = iniciada();

        mandar(ana, {
          'tipo': 'valoresIniciales',
          'valores': [6, 5, 4, 3, 2, 1],
        });
        final anaVistaPorLuis = luis.enPartida['Ana'];
        final anaVistaPorAna = ana.enPartida['Ana'];
        final restante = ana.estado['restanteMs'] as int;
        // Luis no los manda: al acabarse el minuto se le ponen al azar.
        await Future<void>.delayed(const Duration(milliseconds: 90));

        expect(ana.estado['meta'], 26);
        expect(restante, inInclusiveRange(1, 60));
        expect(anaVistaPorLuis!['yaJugo'], isTrue);
        expect(anaVistaPorLuis['iniciales'], isNull);
        expect(anaVistaPorAna!['iniciales'], [6, 5, 4, 3, 2, 1]);
        expect(luis.estado['fase'], 'ronda');
        expect(luis.estado['ronda'], 1);
        expect((luis.enPartida['Luis']!['iniciales'] as List).toSet(), {
          1,
          2,
          3,
          4,
          5,
          6,
        });
        // Ya en la ronda, cada uno ve los valores iniciales del otro.
        expect(luis.enPartida['Ana']!['iniciales'], [6, 5, 4, 3, 2, 1]);
      },
    );

    test('ronda: termina cuando todos juegan, y reparte los puntos', () {
      final (ana, luis) = iniciada();
      for (final quien in [ana, luis]) {
        mandar(quien, {
          'tipo': 'valoresIniciales',
          'valores': [1, 2, 3, 4, 5, 6],
        });
      }
      final dados = ana.estado['dados'] as List;

      mandar(ana, {
        'tipo': 'colocar',
        'ronda': 1,
        'x': 3,
        'y': 0,
        'numero': 4,
        'reclamo': {
          'region': 'Z1',
          'premios': [7, 5, 3],
        },
      });
      // Mientras Luis no juega, Ana no ve aun la jugada en su tablero.
      final casillasAntes = luis.enPartida['Ana']!['casillas'];
      mandar(luis, {'tipo': 'pasar', 'ronda': 1});
      // Una jugada de una ronda que ya paso no cuenta.
      mandar(luis, {'tipo': 'pasar', 'ronda': 1});

      expect(dados, hasLength(2));
      expect(casillasAntes, isEmpty);
      expect(luis.estado['fase'], 'entreRondas');
      expect(luis.enPartida['Ana']!['casillas'], [
        [3, 0, 4],
      ]);
      expect(luis.enPartida['Ana']!['puntos'], 7);
      expect(luis.enPartida['Ana']!['ultimoReclamo'], {
        'region': 'Z1',
        'puntos': 7,
      });
      expect(luis.ultimoError, 'mensajeInvalido');
    });

    test(
      'ronda: quien no juega a tiempo pasa; el desconectado no se espera',
      () async {
        final (ana, luis) = iniciada();
        for (final quien in [ana, luis]) {
          mandar(quien, {
            'tipo': 'valoresIniciales',
            'valores': [1, 2, 3, 4, 5, 6],
          });
        }

        // Ronda 1: nadie juega; al acabarse el tiempo pasa a la ronda 2.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        final rondaTrasEsperar = ana.estado['ronda'];
        // Luis se desconecta: Ana juega y la ronda termina sin esperarlo.
        salas.desconectar(luis);
        mandar(ana, {'tipo': 'pasar', 'ronda': rondaTrasEsperar});

        expect(rondaTrasEsperar, 2);
        expect(ana.estado['fase'], 'entreRondas');
        expect(ana.enPartida['Luis']!['conectado'], isFalse);
      },
    );
  });

  test('una sala con la partida terminada se borra al rato', () async {
    salas.cerrar();
    salas = Salas(
      usuarioDelToken: (token) =>
          token.startsWith('token-') ? token.substring(6) : null,
      esperaSalaTerminada: const Duration(milliseconds: 50),
    );
    final ana = conectar('Ana');
    final luis = conectar('Luis');
    mandar(ana, {'tipo': 'crearSala'});
    final codigo = ana.estado['codigo'] as String;
    mandar(luis, {'tipo': 'unirse', 'codigo': codigo});
    mandar(ana, {'tipo': 'iniciar'});

    // Luis se rinde: Ana gana y la partida termina.
    mandar(luis, {'tipo': 'rendirse'});
    final faseAlTerminar = ana.estado['fase'];
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(faseAlTerminar, 'terminada');
    expect(ana.estado['fase'], 'sinSala');
    expect(salas.sala(codigo), isNull);
  });

  test('por WebSocket de verdad: hola y crear sala', () async {
    final baseDeDatos = BaseDeDatos.enMemoria();
    final tokens = Tokens(crearSecreto());
    final ana = baseDeDatos.crearUsuario(
      'Ana',
      cifrarContrasena('secreta123', costo: 4),
      DateTime.now(),
    )!;
    final servidor = await shelf_io.serve(
      crearManejador(baseDeDatos: baseDeDatos, tokens: tokens),
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() async {
      await servidor.close(force: true);
      baseDeDatos.cerrar();
    });

    final canal = WebSocketChannel.connect(
      Uri.parse('ws://localhost:${servidor.port}/sala'),
    );
    final respuestas = canal.stream
        .map((texto) => jsonDecode(texto as String) as Map<String, dynamic>)
        .asBroadcastStream();
    canal.sink.add(jsonEncode({'tipo': 'hola', 'token': tokens.crear(ana.id)}));
    final alEntrar = await respuestas.first;
    canal.sink.add(jsonEncode({'tipo': 'crearSala'}));
    final conSala = await respuestas.first;
    await canal.sink.close();

    expect(alEntrar['fase'], 'sinSala');
    expect(alEntrar['usuario'], 'Ana');
    expect(conSala['fase'], 'lobby');
    expect(conSala['jugadores'], [
      {'usuario': 'Ana', 'conectado': true},
    ]);
  });
}
