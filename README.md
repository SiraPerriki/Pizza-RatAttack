# PIZZAS y RATAS

Minijuego arcade vertical hecho en Godot. Lanzas la pizza desde la parte inferior, cazas ingredientes para completarla y evitas las ratas que te quitan vidas.

## Estado actual

- Dos modos de juego:
  - `MODO FACIL`: mantiene el comportamiento base actual.
  - `MODO EXPERTO`: aumenta la dificultad por pizza completada.
- Ranking separado por modo.
- Menus con direccion visual arcade/pizzeria.
- HUD inferior rehecho para movil con vidas, marcador y objetivos.
- Celebracion al completar pizza con `pizza_completa.png`.
- Mensajeria de pickups simplificada:
  - `INGREDIENTE +1`, `+2`, `+3` si se encadena mientras el mensaje sigue activo.
  - `+1 PUNTO` para recogidas con menor jerarquia.

## Modo experto

Cada pizza completada sube el nivel de dificultad.

- Velocidad de ratas e ingredientes: `+10%` por pizza.
- Presion de ratas: `+10%` por pizza.
- Tras conseguir el queso, los ingredientes completados siguen apareciendo.
- Los ingredientes repetidos no avanzan la pizza y puntuan menos.
- Al completar una pizza, se carga una nueva masa y se reinicia la fase de `queso primero`.

## Como abrir el proyecto

1. Abre Godot 4.x.
2. Importa esta carpeta como proyecto.
3. Ejecuta `scenes/Main.tscn`.

## Estructura principal

- [scenes/Main.tscn](C:/Users/isasa/OneDrive/Desktop/PIZZASyRATAS/scenes/Main.tscn)
- [scripts/Main.gd](C:/Users/isasa/OneDrive/Desktop/PIZZASyRATAS/scripts/Main.gd)
- [scripts/Spawner.gd](C:/Users/isasa/OneDrive/Desktop/PIZZASyRATAS/scripts/Spawner.gd)
- `img/`: sprites e interfaz
- `sounds/`: audio y efectos

## Documentacion de pendientes

La hoja de ruta abierta de interfaz y pulido visual esta en:

- [PENDIENTES_UI.md](C:/Users/isasa/OneDrive/Desktop/PIZZASyRATAS/PENDIENTES_UI.md)
