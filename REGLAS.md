# Reglas del juego

## Preparación

- Cada jugador tiene **su propio tablero** de 7×7 dividido en regiones de colores.
- Al inicio, cada jugador llena las **6 casillas iniciales** con números del 1 al 6.
  - Todas las casillas iniciales deben tener un número.
  - No puede haber números repetidos entre las casillas iniciales.
- Al presionar **Listo**, las casillas iniciales quedan bloqueadas.

> Las coordenadas de las casillas iniciales se definen en el código (`coordenadasIniciales` en `lib/region.dart`). Siempre son 6 y deben elegirse de forma que **no queden dos dentro de la misma región azul**, porque la regla de "sin repetidos" chocaría con la regla azul de "todos iguales".

## Turno

1. Se tiran **2 dados** automáticamente. **Todos los jugadores usan la misma tirada.**
2. Cada jugador elige cuál de los dos números es el **ancla** y cuál es el **número a insertar**.
   - Ejemplo: con (2, 6), puede usar el 2 como ancla e insertar un 6, o al revés.
3. El **ancla** es cualquier casilla de su tablero que tenga ese número, ya sea inicial o colocada en un turno anterior.
4. El número a insertar se coloca en una casilla **vacía** adyacente al ancla (arriba, abajo, izquierda o derecha), **solo si la regla del color de esa región lo permite**.
5. El jugador **siempre puede pasar**, aunque tenga una jugada válida. Si no tiene ninguna jugada posible, se salta su turno.
6. Todos juegan **al mismo tiempo**. La siguiente tirada se hace cuando todos los jugadores colocaron o pasaron.

## Reglas por color de región

|  Color   |                       Regla                      | Ejemplo válido | Ejemplo inválido |
| Azul     | Todos los números deben ser **idénticos**        | 3, 3, 3, 3     | 3, 3, 4          |
| Rojo     | Todos los números deben ser **diferentes**       | 1, 2, 5, 6     | 1, 2, 2          |
| Amarillo | Todos los números deben ser **diferentes**       | 1, 3, 4, 6     | 4, 4             |
| Lila     | Máximo **2 números distintos** en toda la región | 2, 2, 5, 5, 2  | 2, 1, 2, 3, 2    |
| Verde    | **Cualquier** número                             | 1, 1, 4, 6     | —                |

## Puntuación

- Cuando un jugador **llena por completo una región**, la reclama y gana puntos.
- Los reclamos son **por región**, no por color: cada una de las 9 regiones tiene sus propios reclamos.
- Cada región se puede reclamar **3 veces** entre todos los jugadores. El primero en llenarla gana el primer premio, el segundo el siguiente, etc.
- Después del tercer reclamo, llenar esa región **ya no da puntos**.
- **Empate en un reclamo:** si varios jugadores llenan la misma región en la misma tirada, **todos ganan ese premio**, y el siguiente reclamo pasa al siguiente nivel.
  - Ejemplo (azul): dos jugadores la llenan a la vez y ganan 7 cada uno; el próximo que la llene gana 5.

| Color | 1.er reclamo | 2.º reclamo | 3.er reclamo |
|---|---|---|---|
| Amarillo | 8 | 6 | 4 |
| Azul | 7 | 5 | 3 |
| Rojo | 6 | 4 | 2 |
| Lila | 6 | 4 | 2 |
| Verde | 4 | 3 | 2 |

## Fin de la partida

- Cuando un jugador llega a **26 puntos**, termina la partida para él. Los demás siguen jugando hasta llegar a 26.
- No es posible que el tablero se llene antes de llegar a 26 puntos.
- **Gana el primero en llegar a 26.** Si varios llegan en la misma ronda, gana el que tenga **más puntos**.

## Pendiente por definir

- Qué pasa si dos jugadores llegan a 26 en la misma ronda con **exactamente los mismos puntos**.
- Número máximo de jugadores (probablemente 4) y detalles del juego en red.
