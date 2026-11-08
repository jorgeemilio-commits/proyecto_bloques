import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'base_de_datos.dart';
import 'salas.dart';
import 'seguridad.dart';

// Nombre de usuario: de 3 a 20 letras (incluidas las acentuadas y la ñ),
// numeros o guion bajo. \p{L} son letras de cualquier idioma, \p{M} los
// acentos escritos aparte y \p{N} los numeros.
final RegExp _formatoUsuario = RegExp(
  r'^[\p{L}\p{M}\p{N}_]{3,20}$',
  unicode: true,
);
const int _minimoContrasena = 8;

// Crea el manejador con las rutas del servidor:
// - POST /registro: crear cuenta.
// - POST /login: iniciar sesion; devuelve el JWT.
// - GET /cuenta: datos del usuario (pide el JWT).
// - DELETE /cuenta: borrar la cuenta (pide el JWT y la contraseña).
// - GET /historial: partidas en linea del usuario (pide el JWT).
// - GET /sala: WebSocket para jugar en linea (ver PROTOCOLO_MULTIJUGADOR.md).
//
// Si no se pasan [salas], se crean unas nuevas.
Handler crearManejador({
  required BaseDeDatos baseDeDatos,
  required Tokens tokens,
  int costoBcrypt = 10,
  Salas? salas,
}) {
  final rutas = Router(
    notFoundHandler: (_) => _error(404, 'Ruta no encontrada.'),
  );
  final salasDelServidor =
      salas ??
      Salas(
        usuarioDelToken: (token) =>
            _usuarioDeSesion(token, baseDeDatos, tokens)?.nombre,
        alTerminarPartida: (sala) => _guardarPartida(sala, baseDeDatos),
      );

  // El ping cada 10 segundos detecta pronto las conexiones caidas.
  rutas.get(
    '/sala',
    webSocketHandler((WebSocketChannel canal, _) {
      final conexion = _ConexionWebSocket(canal);
      salasDelServidor.conectar(conexion);
      canal.stream.listen(
        (mensaje) => salasDelServidor.recibir(
          conexion,
          mensaje is String ? mensaje : '',
        ),
        onDone: () => salasDelServidor.desconectar(conexion),
        onError: (_) {},
      );
    }, pingInterval: const Duration(seconds: 10)),
  );

  rutas.post('/registro', (Request peticion) async {
    final datos = await _leerJson(peticion);
    final usuario = datos?['usuario'];
    final contrasena = datos?['contrasena'];
    if (usuario is! String || !_formatoUsuario.hasMatch(usuario)) {
      return _error(
        400,
        'El usuario debe tener de 3 a 20 letras, números o guion bajo.',
      );
    }
    if (contrasena is! String || contrasena.length < _minimoContrasena) {
      return _error(
        400,
        'La contraseña debe tener al menos $_minimoContrasena caracteres.',
      );
    }

    final creado = baseDeDatos.crearUsuario(
      usuario,
      cifrarContrasena(contrasena, costo: costoBcrypt),
      DateTime.now(),
    );
    if (creado == null) {
      return _error(409, 'Ese nombre de usuario ya existe.');
    }
    return _json(201, {'usuario': creado.nombre});
  });

  rutas.post('/login', (Request peticion) async {
    final datos = await _leerJson(peticion);
    final usuario = datos?['usuario'];
    final contrasena = datos?['contrasena'];
    final encontrado = usuario is String
        ? baseDeDatos.usuarioPorNombre(usuario)
        : null;

    // El mismo mensaje si no existe el usuario o si la contraseña esta mal,
    // para no revelar que usuarios existen.
    if (encontrado == null ||
        contrasena is! String ||
        !verificarContrasena(contrasena, encontrado.hashContrasena)) {
      return _error(401, 'Usuario o contraseña incorrectos.');
    }
    // Sesion nueva: el token de cualquier otro dispositivo deja de valer, y si
    // ese dispositivo estaba conectado a una sala, se le saca.
    final versionSesion = baseDeDatos.nuevaSesion(encontrado.id);
    salasDelServidor.sesionNueva(encontrado.nombre);
    return _json(200, {
      'token': tokens.crear(encontrado.id, versionSesion: versionSesion),
      'usuario': encontrado.nombre,
    });
  });

  rutas.get('/cuenta', (Request peticion) {
    final usuario = _usuarioDelToken(peticion, baseDeDatos, tokens);
    if (usuario == null) {
      return _error(401, 'Sesion no valida o vencida.');
    }
    return _json(200, {
      'usuario': usuario.nombre,
      'creado': usuario.creado.toIso8601String(),
    });
  });

  rutas.get('/historial', (Request peticion) {
    final usuario = _usuarioDelToken(peticion, baseDeDatos, tokens);
    if (usuario == null) {
      return _error(401, 'Sesion no valida o vencida.');
    }
    final historial = baseDeDatos.historial(usuario.id);
    return _json(200, {
      'jugadas': historial.jugadas,
      'ganadas': historial.ganadas,
      'partidas': [
        for (final partida in historial.partidas)
          {
            'terminada': partida.terminada.toIso8601String(),
            'mapa': partida.mapa,
            'meta': partida.meta,
            'rondas': partida.rondas,
            'jugadores': [
              for (final jugador in partida.jugadores)
                {
                  'usuario': jugador.nombre,
                  'puntos': jugador.puntos,
                  'situacion': jugador.situacion,
                  'gano': jugador.gano,
                },
            ],
          },
      ],
    });
  });

  rutas.delete('/cuenta', (Request peticion) async {
    final usuario = _usuarioDelToken(peticion, baseDeDatos, tokens);
    if (usuario == null) {
      return _error(401, 'Sesion no valida o vencida.');
    }
    // Se pide la contraseña otra vez para confirmar.
    final contrasena = (await _leerJson(peticion))?['contrasena'];
    if (contrasena is! String ||
        !verificarContrasena(contrasena, usuario.hashContrasena)) {
      return _error(401, 'La contraseña no es correcta.');
    }

    baseDeDatos.borrarUsuario(usuario.id);
    return Response(204);
  });

  return rutas.call;
}

// Guarda en el historial la partida que termino en la sala. Los jugadores que
// borraron su cuenta durante la partida no se guardan. Si algo falla, solo se
// avisa en la consola: el servidor sigue funcionando.
void _guardarPartida(Sala sala, BaseDeDatos baseDeDatos) {
  final partida = sala.partida!;
  try {
    baseDeDatos.guardarPartida(
      mapa: sala.mapa,
      meta: partida.meta,
      rondas: partida.ronda,
      terminada: DateTime.now(),
      resultados: [
        for (final participante in partida.participantes)
          if (baseDeDatos.usuarioPorNombre(participante.nombre)
              case final usuario?)
            (
              usuarioId: usuario.id,
              puntos: participante.puntos,
              situacion: participante.situacion,
              gano: partida.ganadores.contains(participante.nombre),
            ),
      ],
    );
  } on Object catch (error) {
    print('No se pudo guardar la partida de la sala ${sala.codigo}: $error');
  }
}

// Usuario del token del encabezado "Authorization: Bearer <token>", o null si
// no hay token o no vale (ver _usuarioDeSesion).
Usuario? _usuarioDelToken(
  Request peticion,
  BaseDeDatos baseDeDatos,
  Tokens tokens,
) {
  final encabezado = peticion.headers['authorization'];
  if (encabezado == null || !encabezado.startsWith('Bearer ')) {
    return null;
  }
  return _usuarioDeSesion(
    encabezado.substring('Bearer '.length),
    baseDeDatos,
    tokens,
  );
}

// Usuario del token, o null si el token no es valido, el usuario ya no existe
// (cuenta borrada) o el token es de una sesion anterior (despues inicio sesion
// en otro dispositivo).
Usuario? _usuarioDeSesion(
  String token,
  BaseDeDatos baseDeDatos,
  Tokens tokens,
) {
  final datos = tokens.verificar(token);
  final usuario = datos == null
      ? null
      : baseDeDatos.usuarioPorId(datos.usuarioId);
  if (usuario == null || usuario.versionSesion != datos!.versionSesion) {
    return null;
  }
  return usuario;
}

// Lee el cuerpo como un objeto JSON, o devuelve null si no lo es.
Future<Map<String, dynamic>?> _leerJson(Request peticion) async {
  try {
    final datos = jsonDecode(await peticion.readAsString());
    return datos is Map<String, dynamic> ? datos : null;
  } on FormatException {
    return null;
  }
}

Response _json(int estado, Map<String, Object?> datos) => Response(
  estado,
  body: jsonEncode(datos),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Response _error(int estado, String mensaje) =>
    _json(estado, {'error': mensaje});

// Conexion de las salas sobre un WebSocket: los mensajes van como JSON.
class _ConexionWebSocket implements Conexion {
  final WebSocketChannel canal;

  _ConexionWebSocket(this.canal);

  @override
  void enviar(Map<String, Object?> mensaje) =>
      canal.sink.add(jsonEncode(mensaje));

  @override
  void cerrar() => canal.sink.close();
}
