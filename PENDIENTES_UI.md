# Pendientes de interfaz y pulido

Este documento recoge lo que hemos hablado en esta sesion y todavia queda en el tintero, sobre todo en interfaz, feedback visual y cohesion estetica.

## Implementado recientemente

- Panel de fin de partida rehecho para el caso de `nuevo record`.
- Boton de mute tambien en el menu de inicio, sincronizado con el mute de partida.
- Banda de vidas liberada para que los corazones ocupen una sola linea sin caja de fondo que los pise.
- Refuerzo de feedbacks ya aplicado:
  - pulso del marcador al sumar puntos
  - pulso mas vivo del combo
  - flash corto de pantalla al perder vida, ganar vida y completar pizza
  - destello visual al completar ingredientes
  - mensajes centrales con una entrada un poco mas viva

## Prioridad alta

- Limpiar el codigo muerto del HUD en [scripts/Main.gd](C:/Users/isasa/OneDrive/Desktop/PIZZASyRATAS/scripts/Main.gd).
- Sigue habiendo un bloque antiguo detras de `return` en `_refresh_hud()`.
- Conviene retirarlo para reducir ruido y evitar futuras regresiones.

## HUD inferior

- Dar mas presencia al bloque inferior completo.
- Objetivo: que se sienta mas maquina arcade y menos panel funcional.

- Reforzar la separacion visual entre:
  - vidas
  - marcador
  - objetivos de ingredientes

- Engrosar ligeramente marcos y rematar mejor luces/sombras del HUD.

- Hacer una pasada final de espaciado y alineacion optica tras test en movil real.

## Combo y marcador

- Convertir `COMBO` en el gran elemento dinamico del marcador.
- El combo debe ganar mas personalidad visual que `PUNTOS`.

- Posibles mejoras ya habladas:
  - color mas intenso segun racha
  - pequeno pulso al subir
  - glow propio o placa destacada
  - animacion mas agresiva al pasar ciertos umbrales

## Objetivos de ingredientes

- Potenciar mas la diferencia entre ingredientes pendientes y completados.

- Pendientes:
  - mas halo
  - mas luz interior
  - mas presencia de color

- Completados:
  - mas opacos
  - mas desaturados
  - borde mas apagado

- Feedback pendiente:
  - flash corto o destello cuando un ingrediente queda completado

## Botones de pausa y sonido

- Integrarlos mejor con el HUD.
- Ahora funcionan, pero aun se perciben algo separados del bloque principal.

- Lineas de mejora sugeridas:
  - misma altura optica que el marcador
  - iconos un poco mas grandes
  - posible fondo o columna compartida

## Feedback en el area de juego

- Dar mas vida al centro del tablero sin tocar fondos ni sprites base.

- Mejoras pendientes:
  - mensajes flotantes con mas estilo arcade
  - entradas y salidas con mas personalidad
  - destellos o anillos breves al completar ingrediente
  - feedback mas especial al completar pizza

## Mensajeria y jerarquia visual

- El sistema de mensajes se ha simplificado, pero queda una pasada de pulido visual.

- Pendiente:
  - diferenciar mejor mensaje principal y secundario
  - reforzar que `INGREDIENTE +N` mande mas que `+1 PUNTO`
  - revisar timing para que no tape momentos importantes del juego

## Menus y cohesion visual

- Extender la misma identidad visual del menu de inicio a todos los modales y pantallas secundarias con el mismo nivel de detalle.

- Puntos concretos pendientes:
  - rematar pausa, fin de partida y rankings con el mismo acabado arcade
  - revisar consistencia de margenes internos
  - afinar jerarquia tipografica entre titulo, subtitulo y acciones

## Marco del area jugable

- Dar un poco mas de sensacion de tablero o maquina recreativa al area de juego.

- Ideas ya habladas:
  - esquinas decorativas
  - borde interior tenue
  - alguna marca lateral o detalle de maquina
  - vigneta muy suave si no ensucia la lectura

## Siguiente orden recomendado

1. Arreglar el panel de nuevo record del fin de partida.
2. Rematar visualmente el HUD inferior.
3. Hacer protagonista al combo.
4. Mejorar feedbacks en el area central.
5. Dar una ultima pasada de cohesion global a menus y modales.
