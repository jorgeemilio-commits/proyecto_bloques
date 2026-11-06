import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_bloques/cuenta/servicio_cuenta.dart';
import 'package:proyecto_bloques/multijugador/servicio_sala.dart';
import 'ayudantes.dart';
import 'consola.dart';

Future<void> esperar([int milisegundos = 0]) =>
    Future<void>.delayed(Duration(milliseconds: milisegundos));

void main() {
  late ServidorDeSalasFalso servidor;
  late ServicioDeSala sala;
  late List<String> avisos;

  setUp(() async {
    final cuenta = ServicioDeCuenta(cliente: servidorFalso());
    await cuenta.crearCuenta('Ana', 'secreta123');
    await cuenta.iniciarSesion('Ana', 'secreta123');
    servidor = ServidorDeSalasFalso();
    sala = ServicioDeSala(
      cuenta: cuenta,
      abrirCanal: servidor.abrir,
      esperaEntreIntentos: const Duration(milliseconds: 10),
      tiempoReconexion: const Duration(milliseconds: 100),
    );
    avisos = [];
    sala.avisos.listen(avisos.add);
  });

  tearDown(() => sala.dispose());

  test(
    'se identifica, recibe la sala y manda los mensajes del lobby',
    () async {
      sala.conectar();
      await esperar();
      final hola = servidor.recibidos.first;
      servidor.mandarLobby();
      await esperar();
      sala.unirse('K7MQ2P');
      servidor.mandar({'tipo': 'aviso', 'texto': 'Luis se desconectó.'});
      servidor.mandar({
        'tipo': 'error',
        'codigo': 'salaLlena',
        'mensaje': 'La sala ya tiene 6 jugadores.',
      });
      await esperar();

      expect(sala.direccion.toString(), endsWith('/sala'));
      expect(hola, {'tipo': 'hola', 'token': 'token-Ana'});
      expect(sala.conexion, EstadoConexion.conectado);
      expect(sala.estado!.codigo, 'K7MQ2P');
      expect(sala.estado!.soyAnfitrion, isTrue);
      expect(sala.estado!.jugadores.map((j) => (j.usuario, j.conectado)), [
        ('Ana', true),
        ('Luis', false),
      ]);
      expect(servidor.recibidos.last, {'tipo': 'unirse', 'codigo': 'K7MQ2P'});
      expect(avisos, ['Luis se desconectó.', 'La sala ya tiene 6 jugadores.']);
      mostrar(
        'hola con el token, sala ${sala.estado!.codigo}, avisos: $avisos',
      );
    },
  );

  test('si se cae la conexion, reconecta sola y sigue en la sala', () async {
    sala.conectar();
    await esperar();
    servidor.mandarLobby();
    await esperar();

    servidor.cortar();
    await esperar();
    final alCaer = sala.conexion;
    final codigoAlCaer = sala.estado?.codigo;
    await esperar(30);
    final holaAlVolver = servidor.recibidos.last;
    servidor.mandarLobby();
    await esperar();

    expect(alCaer, EstadoConexion.reconectando);
    // Mientras reconecta se sigue viendo la sala.
    expect(codigoAlCaer, 'K7MQ2P');
    expect(holaAlVolver['tipo'], 'hola');
    expect(servidor.canales, hasLength(2));
    expect(sala.conexion, EstadoConexion.conectado);
    mostrar('Se cayo, quedo $alCaer y volvio con un hola nuevo.');
  });

  test('si el servidor no vuelve, se rinde con un mensaje claro', () async {
    sala.conectar();
    await esperar();
    servidor.mandarLobby();
    await esperar();

    servidor.caido = true;
    servidor.cortar();
    await esperar(200);

    expect(sala.conexion, EstadoConexion.desconectado);
    expect(sala.estado, isNull);
    expect(avisos.last, 'Se perdió la conexión con el servidor.');
    // Lo intento varias veces antes de rendirse.
    expect(servidor.canales.length, greaterThan(2));
    mostrar('Tras ${servidor.canales.length - 1} reintentos: "${avisos.last}"');
  });

  test('abrir la partida en otro dispositivo no reintenta', () async {
    sala.conectar();
    await esperar();
    servidor.mandarLobby();
    await esperar();

    servidor.mandar({
      'tipo': 'error',
      'codigo': 'sesionReemplazada',
      'mensaje': 'Abriste la partida en otro dispositivo.',
    });
    servidor.cortar();
    await esperar(50);

    expect(sala.conexion, EstadoConexion.desconectado);
    expect(servidor.canales, hasLength(1));
    expect(avisos.last, 'Abriste la partida en otro dispositivo.');
    mostrar('Sesion reemplazada: "${avisos.last}", sin reintentos.');
  });
}
