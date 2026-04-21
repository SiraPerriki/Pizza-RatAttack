extends Area2D

signal picked(kind: String, pos: Vector2, node_ref: Node)

@export var kind := "rat"
@export var speed := 260.0
@export var direction := 1 # 1 => right, -1 => left
@export var frame_count := 4
@export var anim_fps := 10.0
@export var visual_scale := 4.0
@export var preferred_animation := "side_move"
@export var is_vertical := false

const RAT_SHEET := "res://img/rata_move_side.png"

@onready var anim: AnimatedSprite2D = $RatAnim

# Variables de movimiento orgánico
var _speed_mult := 1.0
var _event_timer := 0.0
var _is_paused := false
var _pause_timer := 0.0
var _y_dir := 0.0
var _seq_state := 0 # 0: lateral, 1: descender, 2: ascender

var _is_panic := false
var _panic_velocity := Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_animation()
	_apply_direction_visual()
	# Iniciamos con valores aleatorios para que no todas cambien a la vez
	_speed_mult = randf_range(0.85, 1.15)
	_event_timer = randf_range(0.8, 2.4)
	_y_dir = randf_range(-0.4, 0.4)

func _process(delta: float) -> void:
	_update_movement(delta)
	_apply_direction_visual()

	var w := get_viewport_rect().size.x
	var h := get_viewport_rect().size.y
	if position.x < -200.0 or position.x > w + 200.0 or position.y < -200.0 or position.y > h + 200.0:
		queue_free()

func _update_movement(delta: float) -> void:
	if _is_panic:
		position += _panic_velocity * delta
		return

	if _is_paused:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_is_paused = false
			_speed_mult = randf_range(1.15, 1.6)
			_event_timer = randf_range(0.6, 1.6)
			anim.play()
		return

	if is_vertical:
		# Movimiento de emboscada desde arriba (estrictamente cardinal)
		if position.y > 600:
			# Escape completamente lateral sin diagonal
			_y_dir = sign(position.x - (get_viewport_rect().size.x / 2.0))
			if _y_dir == 0: _y_dir = 1.0
			position.x += _y_dir * speed * 1.8 * delta
		else:
			position.y += speed * _speed_mult * delta

	else:
		# Movimiento secuencial escalonado
		if _seq_state == 0:
			position.x += float(direction) * speed * _speed_mult * delta
		else:
			position.y += _y_dir * speed * _speed_mult * delta

	_event_timer -= delta
	if _event_timer <= 0.0:
		_trigger_behavior_event()

func _trigger_behavior_event() -> void:
	if randf() < 0.15:
		_is_paused = true
		_pause_timer = randf_range(0.18, 0.50)
		anim.pause()
		return

	_speed_mult = randf_range(0.5, 1.9)
	
	if _seq_state == 0: # Si iba lateral
		var action = randf()
		if action < 0.25 and position.y < 580:
			_seq_state = 1 # Bajar unos pasitos
			_event_timer = randf_range(0.5, 1.2)
			_y_dir = 1.0
		elif action < 0.50 and position.y > 100:
			_seq_state = 2 # Escapar hacia arriba (rat_up)
			_event_timer = randf_range(0.8, 3.0)
			_y_dir = -1.0
		elif action < 0.65:
			# Media vuelta
			direction *= -1
			_event_timer = randf_range(0.8, 2.0)
		else:
			_seq_state = 0 # Seguir lateral normal
			_event_timer = randf_range(0.8, 2.0)
			_y_dir = 0.0
	else:
		# Tras subir o bajar, vuelve a lateral (quizá dándose la vuelta)
		if randf() < 0.35:
			direction *= -1
		_seq_state = 0
		_event_timer = randf_range(0.5, 2.0)
		_y_dir = 0.0

func start_panic_mode() -> void:
	_is_panic = true
	_is_paused = false
	var angles = [0.0, PI/2, PI, -PI/2] # Movimiento estrictamente en cruz (no diagonal)
	var angle = angles[randi() % angles.size()]
	_panic_velocity = Vector2(cos(angle), sin(angle)) * speed * randf_range(1.4, 3.0)
	anim.play()

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
	var vx = 0.0
	var vy = 0.0
	
	if _is_panic:
		vx = _panic_velocity.x
		vy = _panic_velocity.y
	elif is_vertical:
		if position.y > 600:
			vx = _y_dir * 1.0 # Trazado de escape cardinal horizontal
			vy = 0.0
		else:
			vx = 0.0
			vy = 1.0 # Trazado vertical cardinal
	else:
		vx = float(direction) if _seq_state == 0 else 0.0
		vy = _y_dir if _seq_state != 0 else 0.0
		
	# Si la componente vertical es predominante, usar up/down
	if abs(vy) > abs(vx) + 0.15: 
		if vy < 0 and anim.sprite_frames != null and anim.sprite_frames.has_animation("rat_up"):
			anim.play("rat_up")
			anim.flip_h = false
		elif vy > 0 and anim.sprite_frames != null and anim.sprite_frames.has_animation("rat_down"):
			anim.play("rat_down")
			anim.flip_h = false
		else:
			if anim.sprite_frames != null and anim.sprite_frames.has_animation(preferred_animation):
				anim.play(preferred_animation)
			anim.flip_h = vx < 0
	else:
		if anim.sprite_frames != null and anim.sprite_frames.has_animation(preferred_animation):
			anim.play(preferred_animation)
		elif anim.sprite_frames != null and anim.sprite_frames.has_animation("rat_move"):
			anim.play("rat_move")
		anim.flip_h = vx < 0
