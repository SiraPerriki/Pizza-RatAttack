extends Area2D

signal picked(kind: String)

@export var kind := ""
@export var speed := 220.0
@export var direction := 1 # 1 => right, -1 => left

# Parámetros del movimiento flotante
@export var bob_amplitude := 7.0   # píxeles de oscilación vertical
@export var bob_speed := 1.7       # frecuencia de la onda
@export var pulse_amount := 0.04   # variación de escala (4%)
@export var pulse_speed := 2.3     # frecuencia del pulso de escala

const PICKUP_TEXTURES := {
	Globals.ING_CHEESE: "res://img/queso.png",
	Globals.ING_MUSHROOM: "res://img/champinon.png",
	Globals.ING_PEPPERONI: "res://img/peperoni.png",
	Globals.ING_OLIVE: "res://img/aceituna.png",
}

var _time := 0.0
var _phase := 0.0    # fase aleatoria para que no oscilen todos igual
var _base_y := 0.0   # altura de referencia al nacer

func _ready() -> void:
	# Fase aleatoria: si todos nacen con _phase=0 oscilarían sincronizados
	_phase = randf() * TAU
	# Guardamos la Y de spawn como referencia para la oscilación
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _process(delta: float) -> void:
	_time += delta

	# Movimiento horizontal constante
	position.x += float(direction) * speed * delta

	# Flotación vertical: seno sobre la Y base
	position.y = _base_y + sin(_time * bob_speed + _phase) * bob_amplitude

	# Micro-pulso de escala: el ingrediente "respira" ligeramente
	# Usamos una segunda frecuencia para que no esté sincronizado con el bob
	var pulse := 1.0 + sin(_time * pulse_speed + _phase * 1.4) * pulse_amount
	scale = Vector2.ONE * pulse

	# Eliminar si sale de pantalla
	var w := get_viewport_rect().size.x
	if position.x < -80.0 or position.x > w + 80.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		picked.emit(kind)
		queue_free()

func _setup_visuals() -> void:
	var spr := get_node_or_null("VisualSprite") as Sprite2D
	if spr != null and PICKUP_TEXTURES.has(kind):
		spr.texture = load(PICKUP_TEXTURES[kind])
