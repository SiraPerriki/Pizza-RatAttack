extends Area2D

@export var min_up_speed := 1300.0
@export var extra_up_speed := 360.0
@export var max_up_speed := 1950.0
@export var x_steer := 180.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		var v := rb.linear_velocity
		var target_y := clampf(max(min_up_speed, absf(v.y) + extra_up_speed), min_up_speed, max_up_speed)
		v.y = -target_y

		var viewport_w := get_viewport_rect().size.x
		var center_x := viewport_w * 0.5
		var dx := rb.global_position.x - center_x
		v.x += clampf(dx / center_x, -1.0, 1.0) * x_steer

		rb.linear_velocity = v

