# Cambios

Resumen de lo que se ha ido agregando al proyecto, de lo más reciente a lo más
antiguo. El detalle de cada cambio está en el historial de git.

## Pulido de la partida en línea

- Los errores al unirse a una sala (ya empezó, no existe, llena) aparecen
  junto al código, con una sacudida del campo.
- Botón grande y fijo para salir al terminar la partida.
- Controles: tocar el dado ancla y luego la casilla (predeterminado), o
  arrastrar el dado. Se elige en Configuración y se guarda en el teléfono.
- Configuración con el volumen de la música y los efectos.
- El tablero brilla y el teléfono vibra suave al empezar cada ronda.
- Dados y "Pasar" en una barra fija abajo; los tableros de los rivales debajo
  del propio, con la leyenda de colores.
- Modo espectador: quien se rinde, gana o pierde sigue viendo los tableros de
  los demás hasta salir.
- Fondos animados (menú, login, salas, partida y resultados), música en las
  salas y sonidos de victoria, último lugar y cuando un rival completa una
  región.
- Pestaña de "Regiones" más visible, con un globo de ayuda al empezar.

## Multijugador

- Salas con código de invitación, de 2 a 6 jugadores; el anfitrión elige el
  mapa y el tiempo por ronda (opcional) y todos marcan "Listo" para empezar.
- Partida en línea: valores iniciales, rondas simultáneas con los dados del
  servidor, reclamos con empates, meta según los jugadores y ganadores.
- Desconexiones: 15 segundos para volver; si no, cuenta como rendido.
- Rendirse en cualquier momento; la partida termina cuando queda un solo
  jugador jugando.
- Historial de partidas y estadísticas en "Mi cuenta".
- Conexión por internet con ngrok.

## Cuentas

- Servidor en Dart con SQLite: crear cuenta, iniciar sesión (bcrypt y JWT) y
  borrar la cuenta.
- Una cuenta solo puede tener la sesión abierta en un dispositivo.
- Pantallas de iniciar sesión, crear cuenta y "Mi cuenta".

## Juego base

- Tablero de regiones de colores con sus reglas, valores iniciales, dados con
  ancla, reclamos de regiones y puntos.
- Mapas leídos de archivos `.txt` en `assets/mapas/`, con selección de mapa.
- Menú principal, sonidos y tema oscuro con el estilo de un teléfono.
