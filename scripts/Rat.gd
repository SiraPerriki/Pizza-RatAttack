extends Area2D

signal picked(kind: String)

@export var kind := "rat"
@export var speed := 260.0
@export var direction := 1 # 1 => right, -1 => left
@export var frame_count := 4
@export var anim_fps := 10.0
@export var visual_scale := 2.8
@export var preferred_animation := "side_move"

const RAT_SHEET := "res://img/rata_move_side.png"

@onready var anim: AnimatedSprite2D = $RatAnim

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_animation()
	_apply_direction_visual()

func _process(delta: float) -> void:
	position.x += float(direction) * speed * delta
	_apply_direction_visual()

	var w := get_viewport_rect().size.x
	if position.x < -120.0 or position.x > w + 120.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		picked.emit(kind)
		queue_free()

func _setup_animation() -> void:
	# If the scene already has configured animations (edited in Godot),
	# respect them and only pick the best matching one.
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

	# Fallback: build frames from the strip automatically.
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
