# Protocolo multijugador

Cómo hablan la app y el servidor para jugar en línea: lobby con código de
invitación, partida con rondas simultáneas, desconexiones y rendirse.

## Ideas generales

- **Conexión:** un WebSocket en la ruta `/sala` del mismo servidor de cuentas.
  Con ngrok es `wss://dreamt-broken-broadly.ngrok-free.dev/sala`.
- **Mensajes:** texto JSON con un campo `tipo`. Ejemplo:
  `{"tipo": "unirse", "codigo": "K7MQ2P"}`.
- **El servidor manda el estado completo**, no solo lo que cambió. Cada vez que
  algo cambia, envía a todos los de la sala un mensaje `estado` con todo lo que
  necesitan para dibujar la pantalla. Así, reconectarse es solo recibir el
  último `estado`.
- **El servidor decide:** tira los dados, lleva el tiempo de cada ronda,
  reparte los reclamos, suma los puntos y decide quién gana.
- **La app valida las jugadas.** El servidor confía en lo que manda la app
  (dónde puso cada número y qué región completó). Es un proyecto de clase.
- **Las salas viven en la memoria del servidor.** Si el servidor se reinicia,
  se pierden.

## Conexión y sesión

1. La app abre el WebSocket y su **primer mensaje** es `hola` con el token de
   la sesión (el JWT de `/login`). Va en el mensaje y no en la URL para que no
   quede en los registros de ngrok.
2. Si el token no es válido, o no llega `hola` en 10 segundos, el servidor
   manda `error` (`sesionInvalida`) y cierra.
3. Si el token es válido, el servidor responde `estado`. Si el usuario ya
   estaba en una sala (por ejemplo, se le cayó la conexión), ese `estado` es el
   de su sala y sigue donde iba.
4. **Una cuenta, una conexión:** si la misma cuenta se conecta otra vez, la
   conexión nueva reemplaza a la vieja. La vieja recibe `error`
   (`sesionReemplazada`) y se cierra. Así funciona también la reconexión.
   Además, una cuenta solo puede tener la sesión abierta en un dispositivo:
   al iniciar sesión en otro, el token anterior deja de valer y, si ese
   dispositivo estaba conectado, recibe `sesionReemplazada` y su app vuelve
   al inicio de sesión.
5. **Latido:** el servidor manda un ping de WebSocket cada 10 segundos. Si una
   conexión no responde, se considera caída.

## Mensajes de la app al servidor

### Lobby

| `tipo` | Campos | Quién | Qué hace |
|---|---|---|---|
| `hola` | `token` | todos | Primer mensaje: identifica al jugador. |
| `crearSala` | — | todos | Crea una sala nueva; quien la crea es el anfitrión. |
| `unirse` | `codigo` | todos | Entra a la sala con ese código. |
| `salir` | — | todos | Sale de la sala en el lobby. |
| `elegirMapa` | `mapa` | anfitrión | Cambia el mapa (nombre del archivo sin `.txt`, por ejemplo `clasico`). |
| `iniciar` | — | anfitrión | Empieza la partida (mínimo 2 jugadores). |

### Partida

| `tipo` | Campos | Qué hace |
|---|---|---|
| `valoresIniciales` | `valores` | Los 6 valores iniciales del jugador; equivale a presionar "Listo". |
| `colocar` | `ronda`, `x`, `y`, `numero`, `reclamo` | La jugada de la ronda. `reclamo` es `null` o la región que completó. |
| `pasar` | `ronda` | El jugador pasa en esta ronda. |
| `rendirse` | — | Se rinde: sale de la partida y los demás siguen. |

- `valores` son los 6 números (1 a 6, sin repetir) en el orden de las casillas
  iniciales del mapa, por ejemplo `[4, 2, 5, 1, 6, 3]`. Van sin coordenadas
  para que el servidor pueda poner valores al azar sin conocer el mapa (ver
  "Partida").
- `reclamo` es `{"region": "Z1", "premios": [7, 5, 3]}`. Lleva los premios
  porque la app es la que conoce el mapa; el servidor solo usa esos números
  para repartir los puntos.
- `ronda` evita que una jugada vieja (que llegó tarde) cuente en la ronda
  siguiente: si no coincide con la ronda actual, el servidor la ignora.
- Cada jugador manda **una** jugada por ronda (`colocar` o `pasar`). Si manda
  otra, el servidor la ignora.

## Mensajes del servidor a la app

| `tipo` | Campos | Cuándo |
|---|---|---|
| `estado` | ver abajo | Cada vez que algo cambia, a todos los de la sala. |
| `aviso` | `texto` | Para mostrar un momento: "Ana se desconectó", "Luis se rindió"… |
| `error` | `codigo`, `mensaje` | Algo no se pudo hacer; `mensaje` ya viene listo para mostrar. |

### El mensaje `estado`

Sin sala (recién conectado):

```json
{"tipo": "estado", "fase": "sinSala", "usuario": "Ana"}
```

En el lobby:

```json
{
  "tipo": "estado",
  "fase": "lobby",
  "usuario": "Ana",
  "codigo": "K7MQ2P",
  "anfitrion": "Ana",
  "mapa": "clasico",
  "maximo": 6,
  "jugadores": [
    {"usuario": "Ana", "conectado": true},
    {"usuario": "Luis", "conectado": false}
  ]
}
```

En la partida (además de lo del lobby):

```json
{
  "tipo": "estado",
  "fase": "ronda",
  "meta": 26,
  "ronda": 7,
  "dados": [3, 5],
  "restanteMs": 31500,
  "ganadores": [],
  "reclamos": {"Z1": 1},
  "jugadores": [
    {
      "usuario": "Ana",
      "conectado": true,
      "situacion": "jugando",
      "yaJugo": true,
      "puntos": 12,
      "iniciales": [4, 2, 5, 1, 6, 3],
      "casillas": [[3, 0, 4], [3, 1, 2]],
      "ultimoReclamo": {"region": "Z1", "puntos": 7}
    }
  ]
}
```

- `fase`: `sinSala`, `lobby`, `valoresIniciales`, `ronda`, `entreRondas` o
  `terminada`.
- `restanteMs`: milisegundos que le quedan a la ronda (o a la fase de valores
  iniciales) en el momento de enviar.
  La app hace la cuenta regresiva con su propio reloj, para no depender de que
  los relojes coincidan.
- `situacion` de cada jugador: `jugando`, `llegoALaMeta` o `rendido`. Si se
  le cayó la conexión sigue `jugando`, con `conectado: false` mientras tiene
  su tiempo para volver.
- `yaJugo`: si ya mandó su jugada en esta ronda (en `valoresIniciales`: si ya
  mandó sus valores). Las jugadas de los demás **no se ven hasta que termina
  la ronda**: `casillas` solo cambia al resolverla, para que nadie copie.
- `iniciales`: sus 6 valores iniciales en el orden de las casillas iniciales
  del mapa (`null` mientras no los tenga). Los de los rivales **no se ven
  hasta que empieza la ronda 1**: mientras tanto llegan como `null`.
- `reclamos`: cuántas veces se ha reclamado cada región (por su id). Sirve
  para apagar las regiones ya reclamadas y mostrar los puntos que les quedan.
- `casillas`: los números que colocó después, como lista de `[x, y, numero]`.
  Con `iniciales` y `casillas` se dibujan los tableros de los rivales.

## Lobby

- **Código:** 6 caracteres de `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (sin 0, O, 1,
  I ni L, que se confunden al dictarlos). La app lo pasa a mayúsculas.
- **Jugadores:** de 2 a 6.
- **Mapa:** lo elige el anfitrión; al crear la sala es `clasico`.
- **Si el anfitrión sale** en el lobby, **la sala se deshace**: todos quedan
  sin sala (`sinSala`) y reciben el aviso "El anfitrión cerró la sala.". Si
  sale otro jugador, la sala sigue. Si ya no queda nadie, la sala se borra.
- **Desconexión en el lobby:** el jugador sigue en la lista como
  `conectado: false` durante 80 segundos; si no vuelve, sale de la sala (y si
  era el anfitrión, la sala se deshace).

## Partida

1. **Inicio:** el anfitrión manda `iniciar`. La sala se cierra a nuevos
   jugadores y pasa a `valoresIniciales`. La meta queda fija según cuántos
   empezaron: 2 = 26, 3 = 24, 4 = 22, 5 y 6 = 20. No cambia aunque después
   alguien se rinda o se desconecte.
2. **Valores iniciales:** cada jugador pone los suyos en su app y manda
   `valoresIniciales`. Hay **1 minuto**: a quien no los mandó a tiempo (o está
   desconectado), el servidor le pone valores al azar (1 a 6 sin repetir) y su
   app los adopta en lugar de lo que llevaba. La ronda 1 empieza cuando todos
   tienen valores, ya sea porque los mandaron o al acabarse el minuto.
3. **Ronda:** el servidor tira los 2 dados, pasa a `ronda` y espera hasta
   **40 segundos**. Termina antes si todos los jugadores que siguen jugando y
   están conectados ya mandaron su jugada (a los desconectados no se les
   espera). Quien no jugó a tiempo, pasa.
4. **Resolver la ronda:**
   - Se agrupan los reclamos por región. Si varios completaron la misma región
     en la misma ronda, **todos ganan el mismo premio** (el siguiente que toca)
     y la región avanza solo un nivel. Ejemplo: dos jugadores ganan 7 y el
     próximo que la complete gana 5.
   - Tras el tercer reclamo, la región ya no da puntos (premio 0).
   - Se suman los puntos y se actualizan los tableros de todos.
5. **Meta:** quien llega a la meta queda en `llegoALaMeta` y ya no juega.
   - **Gana** el primero en llegar. Si varios llegan en la misma ronda, gana el
     de más puntos; si empatan en puntos, ganan todos los empatados.
   - Después de que hay ganador, **los demás siguen jugando** hasta llegar a la
     meta (como en el juego de mesa), mientras queden al menos dos jugando.
     Quien ya llegó puede seguir viendo la partida o salir.
6. **Entre rondas:** `entreRondas` dura 1 segundo para mostrar los resultados y
   luego empieza la siguiente ronda.
7. **Fin:** la partida termina (`terminada`) en cuanto queda **un solo
   jugador jugando** (o ninguno): ya sea porque los demás llegaron a la meta o
   porque se rindieron. Si todavía no había ganador, gana el que quedó.

## Desconexiones y rendirse

- **Se cae la conexión:** el jugador queda con `conectado: false` y los demás
  reciben un `aviso`. Tiene **80 segundos** para volver.
  - Mientras tanto la partida **no se detiene**: en cada ronda pasa
    automáticamente por él.
  - Si vuelve a tiempo (conecta de nuevo y manda `hola`), recibe el `estado`
    completo y sigue en la ronda en curso.
  - Si no vuelve, cuenta como **rendido**.
- **Rendirse:** el jugador manda `rendirse` (la app pide confirmación). Pasa a
  `rendido`, ya no juega, y los demás reciben un `aviso`. Su tablero y puntos
  se siguen viendo, y él queda libre (`sinSala`) para entrar a otra sala.
  Quien ya llegó a la meta (o con la partida terminada) también manda
  `rendirse` para salir: solo sale, sin cambiar su situación.
- **Se cae el servidor:** la app no puede reconectarse; después de intentarlo
  durante 80 segundos muestra un mensaje y vuelve al menú.
- Una sala en `terminada` se borra cuando todos salen, o a los 5 minutos.

## Errores

| `codigo` | `mensaje` |
|---|---|
| `sesionInvalida` | Tu sesión no es válida. Vuelve a iniciar sesión. |
| `sesionReemplazada` | Tu cuenta se abrió en otro dispositivo. |
| `salaNoExiste` | No existe una sala con ese código. |
| `salaLlena` | La sala ya tiene 6 jugadores. |
| `partidaEmpezada` | Esa partida ya empezó. |
| `yaEnSala` | Ya estás en una sala. |
| `soloAnfitrion` | Solo el anfitrión puede hacer eso. |
| `faltanJugadores` | Se necesitan al menos 2 jugadores para empezar. |
| `mensajeInvalido` | Mensaje no válido. |

