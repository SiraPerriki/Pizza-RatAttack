# rata.gd
extends CharacterBody2D

@export var velocidad_patrulla = 40
@export var velocidad_persecucion = 70
@export var radio_deteccion = 100
@export var tiempo_max_persecucion = 3.0  # segundos persiguiendo
@export var tiempo_cooldown = 4.0          # segundos descansando

var estado = "patrulla"
var direccion_patrulla = Vector2.ZERO
var tiempo_cambio_direccion = 0.0
var tiempo_persiguiendo = 0.0
var tiempo_descanso = 0.0
var jugador = null

@onready var sprite := $AnimatedSprite2D

func _ready():
	cambiar_direccion()

func _physics_process(delta):
	tiempo_cambio_direccion -= delta

	if tiempo_cambio_direccion <= 0:
		cambiar_direccion()

	match estado:
		"patrulla":
			velocity = direccion_patrulla * velocidad_patrulla
			mover_sprite(direccion_patrulla)

		"persiguiendo":
			tiempo_persiguiendo += delta
			if tiempo_persiguiendo >= tiempo_max_persecucion:
				# Se cansa, entra en descanso
				estado = "descansando"
				tiempo_descanso = tiempo_cooldown
				jugador = null
				cambiar_direccion()
			elif jugador:
				var dir = (jugador.global_position - global_position).normalized()
				velocity = dir * velocidad_persecucion
				mover_sprite(dir)

		"descansando":
			# Sigue patrullando pero no puede detectar
			tiempo_descanso -= delta
			velocity = direccion_patrulla * velocidad_patrulla
			mover_sprite(direccion_patrulla)
			if tiempo_descanso <= 0:
				estado = "patrulla"

	move_and_slide()

func cambiar_direccion():
	tiempo_cambio_direccion = randf_range(1.5, 3.0)
	var angulo = randf() * TAU
	direccion_patrulla = Vector2(cos(angulo), sin(angulo))

func mover_sprite(dir: Vector2):
	if abs(dir.x) > abs(dir.y):
		sprite.flip_h = dir.x < 0
		sprite.play("rata_side")
	elif dir.y < 0:
		sprite.flip_h = false
		sprite.play("rata_up")
	else:
		sprite.flip_h = false
		sprite.play("rata_down")

func _on_detection_area_body_entered(body):
	if body.name == "Player" and estado == "patrulla":
		jugador = body
		estado = "persiguiendo"
		tiempo_persiguiendo = 0.0

func _on_detection_area_body_exited(body):
	if body.name == "Player" and estado == "persiguiendo":
		jugador = null
		estado = "patrulla"
		cambiar_direccion()
