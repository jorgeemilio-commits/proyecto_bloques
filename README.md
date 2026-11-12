# Proyecto Bloques

Versión digital del juego de mesa *Brilliant*: cada jugador llena las regiones
de colores de su tablero con los números de los dados. Se puede jugar solo
(offline) o en línea con hasta 6 jugadores, con cuentas de usuario.

El repositorio tiene dos programas:

| Carpeta | Qué es |
|---|---|
| `/` (raíz) | **El cliente**: la app de Flutter (Windows y Android). |
| `servidor/` | **El servidor**: cuentas (registro, inicio de sesión) y partidas en línea. Programa de Dart con SQLite. |

Para jugar **offline** solo hace falta el cliente, pero hay que iniciar sesión,
así que el servidor tiene que estar corriendo en alguna computadora.

## Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) 3.35 o más nuevo
  (incluye Dart). Revisa con `flutter doctor`.
- Para el cliente en Windows: Visual Studio con "Desarrollo para el escritorio
  con C++".
- Para el cliente en Android: Android Studio (o solo el Android SDK) y un
  teléfono con la depuración USB activada.

## Abrir el servidor

```cmd
cd servidor
dart pub get
dart run bin/servidor.dart
```

- Escucha en el puerto **8081** (el 8080 suele estar ocupado por otros
  programas, como Apache de XAMPP). Para usar otro: `--puerto 9090`.
- La primera vez crea `servidor/datos/` con la base de datos y la clave
  secreta de las sesiones. La base de datos nueva trae dos usuarios de prueba:
  `prueba` / `prueba1234` y `jugador2` / `jugador1234`.
- `servidor/datos/` **no se sube al repositorio** (está en el `.gitignore`):
  cada computadora tiene sus propias cuentas.
- Se detiene con `Ctrl+C`. Las cuentas y el historial se guardan; las salas en
  curso se pierden.
- Al arrancar muestra las direcciones por las que se le puede conectar.

Comprueba que responde abriendo `http://localhost:8081/cuenta` en el
navegador: debe salir `{"error":"Sesion no valida o vencida."}`.

### Conectarse desde otras redes (opcional, con ngrok)

Para que teléfonos de cualquier red (datos, otro Wi-Fi) lleguen al servidor,
se publica con [ngrok](https://ngrok.com), con el servidor ya corriendo:

```cmd
ngrok config add-authtoken <tu-token>     :: solo la primera vez
ngrok http --domain=<tu-dominio>.ngrok-free.dev 127.0.0.1:8081
```

- El dominio fijo gratis se obtiene en el panel de ngrok, en *Domains*.
- Usa `127.0.0.1:8081` y no solo `8081`: si no, ngrok busca por IPv6 y falla.
- El authtoken es personal: no lo subas al repositorio.

### Pruebas del servidor

```cmd
cd servidor
dart test
```

## Abrir el cliente (la app)

### 1. Elegir a qué servidor se conecta

La dirección está en `lib/cuenta/servicio_cuenta.dart`, en
`direccionServidor`. Cámbiala según dónde corre el servidor:

| Dónde corre la app | Dirección |
|---|---|
| Cualquier dispositivo, con ngrok | `https://<tu-dominio>.ngrok-free.dev` |
| La misma computadora que el servidor (Windows) | `http://localhost:8081` |
| Emulador de Android | `http://10.0.2.2:8081` |
| Teléfono en la misma red Wi-Fi | `http://<IP de la computadora>:8081` |

### 2. Correrla

```cmd
flutter pub get
flutter run -d windows
```

En un **teléfono Android** conectado por USB:

```cmd
flutter devices                  :: muestra el id del teléfono
flutter run -d <id del teléfono>
```

- En Xiaomi hay que activar también "Instalar vía USB" en las Opciones de
  desarrollador.
- En VS Code también se puede elegir el dispositivo abajo a la derecha y
  presionar F5.
- **Chrome no funciona**: el servidor no tiene CORS, así que el navegador
  bloquea las peticiones.

### Instalar la app en otros teléfonos (APK)

```cmd
flutter build apk --release
```

El instalador queda en `build/app/outputs/flutter-apk/app-release.apk`. Se pasa
al teléfono y se abre; Android pide permitir apps de fuentes desconocidas.

### Dos ventanas en la misma computadora

Para probar el multijugador con dos ventanas de Windows, abre la primera con
`flutter run -d windows` y la segunda con el programa ya compilado, **sin
volver a compilar**:

```cmd
build\windows\x64\runner\Debug\proyecto_bloques.exe
```

Cada ventana debe usar una cuenta distinta: una cuenta solo puede tener la
sesión abierta en un dispositivo.

### Pruebas del cliente

```cmd
flutter analyze
flutter test
```

## Cómo se juega en línea

1. Inicia sesión (o crea una cuenta) y presiona **Jugar**.
2. Uno crea una sala y comparte el código de 6 letras; los demás se unen con
   ese código (de 2 a 6 jugadores).
3. El anfitrión elige el mapa e inicia la partida.
4. Cada uno pone sus 6 valores iniciales y, en cada ronda, coloca uno de los
   dados o pasa. Gana el primero en llegar a la meta de puntos.

Las reglas completas están en `REGLAS.md`, y cómo hablan la app y el servidor
en `PROTOCOLO_MULTIJUGADOR.md`.
