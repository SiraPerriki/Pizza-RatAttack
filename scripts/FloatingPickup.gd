extends Area2D

signal picked(kind: String)

@export var kind := ""
@export var speed := 220.0
@export var direction := 1 # 1 => right, -1 => left

const PICKUP_TEXTURES := {
	Globals.ING_CHEESE: "res://img/queso.png",
	Globals.ING_MUSHROOM: "res://img/champinon.png",
	Globals.ING_PEPPERONI: "res://img/peperoni.png",
	Globals.ING_OLIVE: "res://img/aceituna.png",
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _process(delta: float) -> void:
	position.x += float(direction) * speed * delta

	var w := get_viewport_rect().size.x
	if position.x < -80.0:
		queue_free()
	elif position.x > w + 80.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		picked.emit(kind)
		queue_free()

func _setup_visuals() -> void:
	var spr := get_node_or_null("VisualSprite") as Sprite2D
	if spr != null and PICKUP_TEXTURES.has(kind):
		spr.texture = load(PICKUP_TEXTURES[kind])

