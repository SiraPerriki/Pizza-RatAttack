extends Area2D

@export var min_up_speed := 1300.0
@export var extra_up_speed := 360.0
@export var max_up_speed := 1950.0
@export var x_steer := 180.0

@export var is_lateral := false
@export var lateral_bounce_speed := 1400.0
@export var lateral_up_boost := 800.0

@export var is_top := false
@export var top_bounce_speed := 1500.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		var v := rb.linear_velocity
		var viewport_w := get_viewport_rect().size.x
		var center_x := viewport_w * 0.5

		if is_lateral:
			var dir_x := 1.0 if global_position.x < center_x else -1.0
			v.x = dir_x * lateral_bounce_speed
			v.y = -maxf(absf(v.y) * 0.8, lateral_up_boost)
			# Small angular bump
			rb.angular_velocity += dir_x * randf_range(8.0, 15.0)
		elif is_top:
			var dir_x := 1.0 if global_position.x < center_x else -1.0
			v.x += dir_x * 900.0
			v.y = maxf(absf(v.y) * 0.6, top_bounce_speed)
			rb.angular_velocity += dir_x * randf_range(15.0, 25.0)
		else:
			var target_y := clampf(max(min_up_speed, absf(v.y) + extra_up_speed), min_up_speed, max_up_speed)
			v.y = -target_y
			var dx := rb.global_position.x - center_x
			v.x += clampf(dx / center_x, -1.0, 1.0) * x_steer

		rb.linear_velocity = v
		
		# Efecto de partículas para rebote
		var main = body.get_parent().get_node_or_null("Main") as Node2D
		if main and main.has_method("create_bounce_effect"):
			var particle_system = main.get_node_or_null("ParticleSystem")
			if particle_system:
				particle_system.create_bounce_effect(global_position)
		
		# Play Bumper boing
		var audio = body.get_parent().get_node_or_null("AudioSystem")
		if audio and audio.has_method("play_bumper"):
			audio.play_bumper()

