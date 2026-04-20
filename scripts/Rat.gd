extends Area2D

signal picked(kind: String, pos: Vector2, node_ref: Node)

@export var kind := "rat"
@export var speed := 260.0
@export var direction := 1 # 1 => right, -1 => left
@export var frame_count := 4
@export var anim_fps := 10.0
@export var visual_scale := 4.0
@export var preferred_animation := "side_move"

const RAT_SHEET := "res://img/rata_move_side.png"

@onready var anim: AnimatedSprite2D = $RatAnim

# Variables de movimiento orgánico
var _speed_mult := 1.0      # multiplicador de velocidad actual
var _event_timer := 0.0     # tiempo hasta el próximo cambio de comportamiento
var _is_paused := false     # la rata está parada
var _pause_timer := 0.0     # tiempo que dura la pausa

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_animation()
	_apply_direction_visual()
	# Iniciamos con valores aleatorios para que no todas cambien a la vez
	_speed_mult = randf_range(0.85, 1.15)
	_event_timer = randf_range(0.8, 2.4)

func _process(delta: float) -> void:
	_update_movement(delta)
	_apply_direction_visual()

	var w := get_viewport_rect().size.x
	if position.x < -120.0 or position.x > w + 120.0:
		queue_free()

func _update_movement(delta: float) -> void:
	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_is_paused = false
			# Tras la pausa, pequeño acelerón
			_speed_mult = randf_range(1.15, 1.6)
			_event_timer = randf_range(0.6, 1.6)
			anim.play()
		return

	# Movimiento normal con multiplicador de velocidad
	position.x += float(direction) * speed * _speed_mult * delta

	# Cuenta atrás hasta el próximo evento
	_event_timer -= delta
	if _event_timer <= 0.0:
		_trigger_behavior_event()

func _trigger_behavior_event() -> void:
	# 20% de probabilidad de pausa, 80% de cambio de velocidad
	if randf() < 0.20:
		_is_paused = true
		_pause_timer = randf_range(0.18, 0.50)
		anim.pause()
	else:
		# Variación de velocidad: puede ir lento o rápido
		_speed_mult = randf_range(0.55, 1.55)
		_event_timer = randf_range(0.7, 2.2)

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		picked.emit(kind, global_position, self)

func _setup_animation() -> void:
	# Si la escena ya tiene animaciones configuradas, respetarlas
	if anim.sprite_frames != null:
		if anim.sprite_frames.has_animation(preferred_animation):
			anim.play(preferred_animation)
			anim.scale = Vector2.ONE * visual_scale
			return
		if anim.sprite_frames.has_animation("rat_move"):
			anim.play("rat_move")
			anim.scale = Vector2.ONE * visual_scale
			return
		if anim.sprite_frames.has_animation("walk"):
			anim.play("walk")
			anim.scale = Vector2.ONE * visual_scale
			return

	# Fallback: construir frames desde el sprite strip
	var tex := load(RAT_SHEET) as Texture2D
	if tex == null:
		return

	anim.scale = Vector2.ONE * visual_scale

	var fw := int(tex.get_width() / frame_count)
	var fh := tex.get_height()
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", anim_fps)

	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * fw, 0, fw, fh)
		frames.add_frame("walk", atlas)

	anim.sprite_frames = frames
	anim.play("walk")

func _apply_direction_visual() -> void:
	anim.flip_h = direction < 0
