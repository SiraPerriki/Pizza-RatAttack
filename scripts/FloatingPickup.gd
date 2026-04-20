extends Area2D

signal picked(kind: String, pos: Vector2, node_ref: Node)

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
	Globals.ING_MUSHROOM: "res://img/champinon_ingrediente.png",
	Globals.ING_PEPPERONI: "res://img/peperoni_ingrediente.png",
	Globals.ING_OLIVE: "res://img/aceituna_ingrediente.png",
	Globals.ING_ANCHOVY: "res://img/anchoa_ingrediente.png",
	Globals.ING_LIFE: "res://img/vida.png",
}

@export var visual_scale := 2.0
@export var is_vertical := false

var _time := 0.0
var _phase := 0.0    # fase aleatoria para que no oscilen todos igual
var _base_y := 0.0   # altura de referencia al nacer
var _base_x := 0.0

func _ready() -> void:
	# Fase aleatoria: si todos nacen con _phase=0 oscilarían sincronizados
	_phase = randf() * TAU
	# Guardamos la Y de spawn como referencia para la oscilación
	_base_y = position.y
	_base_x = position.x
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _process(delta: float) -> void:
	_time += delta
	
	if is_vertical:
		position.y += speed * delta * 0.7  # Gravedad suave
		position.x = _base_x + sin(_time * bob_speed + _phase) * bob_amplitude
	else:
		position.x += float(direction) * speed * delta
		position.y = _base_y + sin(_time * bob_speed + _phase) * bob_amplitude

	# Micro-pulso de escala: el ingrediente "respira" ligeramente
	var pulse := 1.0 + sin(_time * pulse_speed + _phase * 1.4) * pulse_amount
	scale = Vector2.ONE * visual_scale * pulse

	# Eliminar si sale de pantalla
	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	if is_vertical and position.y > h + 100.0:
		queue_free()
	elif not is_vertical and (position.x < -120.0 or position.x > w + 120.0):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		picked.emit(kind, global_position, self)
		queue_free()

func _setup_visuals() -> void:
	var spr := get_node_or_null("VisualSprite") as Sprite2D
	if spr != null and PICKUP_TEXTURES.has(kind):
		spr.texture = load(PICKUP_TEXTURES[kind])
