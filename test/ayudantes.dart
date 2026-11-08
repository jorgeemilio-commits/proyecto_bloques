// Ayudantes compartidos por las pruebas.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proyecto_bloques/proyecto_bloques.dart';
import 'package:stream_channel/stream_channel.dart';

// El mapa clasico leido de su archivo real (assets/mapas/clasico.txt). Se lee
// directo del disco para poder usarlo en cualquier prueba sin esperar.
final Mapa mapaClasico = leerMapa(File(rutaMapaClasico).readAsStringSync());

// El mapa Bases, que tiene casillas iniciales dentro de sus dos regiones
// naranjas: (4,0) en la de arriba (4 a 6) y (1,6) en la de abajo (1 a 3).
final Mapa mapaBases = leerMapa(
  File('${carpetaMapas}bases.txt').readAsStringSync(),
);

// Region del mapa clasico por su identificador, por ejemplo 'Z1' (la azul de
// arriba) o 'Z2' (la azul rayada de abajo).
Region region(String id) =>
    mapaClasico.regiones.firstWhere((region) => region.id == id);

// Random que devuelve las caras indicadas en orden, para saber que saldra.
class AzarFijo implements Random {
  final List<int> caras;
  int _siguiente = 0;

  AzarFijo(this.caras);

  @override
  int nextInt(int max) => caras[_siguiente++ % caras.length] - 1;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

// Tablero real con los numeros 1 a 6 en la diagonal: (0,0)=1, (1,1)=2 ...
// (5,5)=6. Es una posicion fija para probar las reglas, sin depender de donde
// esten las casillas iniciales.
Tablero crearTableroConDiagonal() {
  final tablero = mapaClasico.crearTablero();
  for (var indice = 0; indice < 6; indice++) {
    celdaEn(tablero, indice, indice).numero = indice + 1;
  }
  return tablero;
}

Celda celdaEn(Tablero tablero, int x, int y) =>
    tablero.obtenerCelda(Coordenada(x, y));

// Servidor falso que responde como servidor/bin/servidor.dart, para probar
// el servicio sin red. Guarda los usuarios en memoria y usa como token
// "token-<usuario>".
MockClient servidorFalso() {
  final usuarios = <String, String>{};

  // Igual que el servidor real: JSON en UTF-8, para que lleguen bien los
  // acentos y la ñ (por ejemplo, en "contraseña").
  http.Response json(int estado, Map<String, Object?> datos) => http.Response(
    jsonEncode(datos),
    estado,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  return MockClient((peticion) async {
    final datos = peticion.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(peticion.body) as Map<String, dynamic>;
    final token = peticion.headers['authorization']?.replaceFirst(
      'Bearer token-',
      '',
    );
    final conSesion = token != null && usuarios.containsKey(token);

    switch ((peticion.method, peticion.url.path)) {
      case ('POST', '/registro'):
        if (usuarios.containsKey(datos['usuario'])) {
          return json(409, {'error': 'Ese nombre de usuario ya existe.'});
        }
        usuarios[datos['usuario'] as String] = datos['contrasena'] as String;
        return json(201, {'usuario': datos['usuario']});
      case ('POST', '/login'):
        if (usuarios[datos['usuario']] != datos['contrasena']) {
          return json(401, {'error': 'Usuario o contraseña incorrectos.'});
        }
        return json(200, {
          'token': 'token-${datos['usuario']}',
          'usuario': datos['usuario'],
        });
      case ('GET', '/cuenta') when conSesion:
        return json(200, {'usuario': token});
      // Historial fijo: una partida ganada en el mapa clasico.
      case ('GET', '/historial') when conSesion:
        return json(200, {
          'jugadas': 3,
          'ganadas': 1,
          'partidas': [
            {
              'terminada': '2026-11-08T18:30:00.000Z',
              'mapa': 'clasico',
              'meta': 26,
              'rondas': 14,
              'jugadores': [
                {
                  'usuario': token,
                  'puntos': 27,
                  'situacion': 'llegoALaMeta',
                  'gano': true,
                },
                {
                  'usuario': 'Luis',
                  'puntos': 19,
                  'situacion': 'jugando',
                  'gano': false,
                },
              ],
            },
          ],
        });
      case ('DELETE', '/cuenta') when conSesion:
        if (usuarios[token] != datos['contrasena']) {
          return json(401, {'error': 'La contraseña no es correcta.'});
        }
        usuarios.remove(token);
        return http.Response('', 204);
      default:
        return json(401, {'error': 'Sesion no valida o vencida.'});
    }
  });
}

// Servidor de salas falso: cada vez que la app abre una conexion, se crea un
// canal nuevo; la prueba lee lo que mando la app y le contesta.
class ServidorDeSalasFalso {
  final List<StreamChannelController<dynamic>> canales = [];
  final List<Map<String, dynamic>> recibidos = [];
  // Si es true, las conexiones nuevas se cierran enseguida (servidor caido).
  bool caido = false;

  StreamChannel<dynamic> abrir(Uri direccion) {
    final canal = StreamChannelController<dynamic>();
    canales.add(canal);
    canal.local.stream.listen(
      (texto) => recibidos.add(jsonDecode(texto as String)),
    );
    if (caido) {
      canal.local.sink.close();
    }
    return canal.foreign;
  }

  void mandar(Map<String, Object?> mensaje) =>
      canales.last.local.sink.add(jsonEncode(mensaje));

  void mandarSinSala() =>
      mandar({'tipo': 'estado', 'fase': 'sinSala', 'usuario': 'Ana'});

  void mandarLobby({String anfitrion = 'Ana'}) => mandar({
    'tipo': 'estado',
    'fase': 'lobby',
    'usuario': 'Ana',
    'codigo': 'K7MQ2P',
    'anfitrion': anfitrion,
    'mapa': 'clasico',
    'maximo': 6,
    'jugadores': [
      {'usuario': anfitrion, 'conectado': true},
      {
        'usuario': anfitrion == 'Ana' ? 'Luis' : 'Ana',
        'conectado': anfitrion != 'Ana',
      },
    ],
  });

  // Simula que se cae la conexion actual.
  void cortar() => canales.last.local.sink.close();
}
