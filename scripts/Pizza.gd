extends RigidBody2D

signal launched()
signal landed_idle()

@export var launch_power := 12.0
@export var max_launch_speed := 1550.0
@export var max_speed := 1900.0
@export var hold_damping := 0.98
@export var min_drag_to_launch := 12.0
@export var min_vertical_drag := 16.0
@export var max_drag_distance := 80.0
@export var max_side_drag := 180.0
@export var min_up_release_speed := 520.0
@export var side_launch_scale := 1.15
@export var max_launch_angle_deg := 76.0
@export var side_curve_power := 0.82
@export var vertical_curve_power := 0.9
@export var sling_half_width := 52.0
@export var sling_anchor_y_offset := -8.0

@onready var drag_area: Area2D = $DragArea
@onready var sling_base: Line2D = $SlingBase
@onready var sling_band: Line2D = $SlingBand
@onready var base_sprite: Sprite2D = $BaseSprite
@onready var toppings_container: Node2D = $Toppings

var _dragging := false
var _is_sliding_base := false
var _drag_start_touch_x := 0.0
var _drag_start_anchor_x := 0.0
var _drag_start_global := Vector2.ZERO
var _drag_current_global := Vector2.ZERO
var _idle_anchor := Vector2.ZERO
var _returning := false
var _orientation_rotated := false
var _return_tween: Tween
var _used_slot_indices: Array[int] = []
var _topping_nodes_by_kind := {
	Globals.ING_MUSHROOM: [],
	Globals.ING_PEPPERONI: [],
	Globals.ING_OLIVE: [],
	Globals.ING_ANCHOVY: [],
}
var _slot_positions: Array[Vector2] = []

const TEX_MASA := "res://img/masa.png"
const TEX_MASA_Q := "res://img/quesoconmasa.png"
const TEX_MUSH_MASA := "res://img/champinon_masa.png"
const TEX_PEP_MASA := "res://img/peperoni_masa.png"
const TEX_OLIVE_MASA := "res://img/aceituna_masa.png"
const TEX_ANCHOVY_MASA := "res://img/masa_anchoa.png"

const STATE_IDLE := 0
const STATE_DRAGGING := 1
const STATE_FLYING := 2
const STATE_RETURNING := 3
var _state := STATE_IDLE
var _controls_enabled := true

func _ready() -> void:
	sling_base.top_level = true
	sling_band.top_level = true
	sling_base.visible = true
	sling_band.visible = false
	drag_area.input_event.connect(_on_drag_area_input_event)
	_idle_anchor = global_position
	_update_idle_sling_base()
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_setup_pizza_visuals()

func _physics_process(_delta: float) -> void:
	if _dragging:
		global_position = _drag_current_global
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		_update_drag_visual()
	else:
		if linear_velocity.length() > max_speed:
			linear_velocity = linear_velocity.normalized() * max_speed

	# Turn-based flow: after one launch arc, pizza naturally falls and returns to idle.
	if _state == STATE_FLYING and linear_velocity.y > 0.0 and global_position.y >= _idle_anchor.y and not _returning:
		_start_return_to_idle()

	if not _dragging and _state == STATE_IDLE:
		_update_idle_sling_base()

func _update_drag_visual() -> void:
	sling_base.visible = true
	sling_band.visible = true
	_update_idle_sling_base()
	_update_sling_band()

func _on_drag_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		_process_drag(_screen_to_global((event as InputEventMouseMotion).position))
	elif event is InputEventScreenDrag:
		_process_drag(_screen_to_global((event as InputEventScreenDrag).position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()
	elif event is InputEventScreenTouch and not event.pressed:
		_end_drag()

func _process_drag(raw_global: Vector2) -> void:
	if _is_sliding_base:
		var tension_y := raw_global.y - _drag_start_global.y
		if tension_y > 28.0:
			_is_sliding_base = false
			_drag_start_global = global_position
		else:
			var dx := raw_global.x - _drag_start_touch_x
			var viewport_w := get_viewport_rect().size.x
			var target_x := clampf(_drag_start_anchor_x + dx, 70.0, viewport_w - 70.0)
			_idle_anchor.x = target_x
			global_position = Vector2(target_x, _idle_anchor.y)
			_drag_current_global = global_position
			_update_drag_visual()
			return
			
	_drag_current_global = _constrain_drag_point(raw_global)

func _begin_drag(screen_pos: Vector2) -> void:
	if not _controls_enabled or _dragging or _state != STATE_IDLE:
		return
	if _return_tween != null and _return_tween.is_running():
		_return_tween.kill()
		_return_tween = null
	_returning = false
	_dragging = true
	_is_sliding_base = true
	_state = STATE_DRAGGING
	freeze = true
	
	var raw := _screen_to_global(screen_pos)
	_drag_start_touch_x = raw.x
	_drag_start_anchor_x = _idle_anchor.x
	_drag_start_global = global_position
	_drag_current_global = global_position
	_update_drag_visual()

func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	_is_sliding_base = false
	var tension := _drag_current_global.y - _drag_start_global.y
	var drag_vec := _drag_current_global - _drag_start_global
	
	# Detectar pulsación rápida para girar 90 grados
	if drag_vec.length() < 10.0 and tension < 10.0:
		_toggle_orientation()
		sling_band.visible = false
		_start_return_to_idle()
		return

	if drag_vec.length() < min_drag_to_launch or tension < min_vertical_drag:
		sling_band.visible = false
		_start_return_to_idle()
		return

	freeze = false
	_state = STATE_FLYING
	sling_band.visible = false

	var v := _build_release_velocity()
	
	# Aplicar físicas según la orientación
	if _orientation_rotated:
		v *= 1.35      # Más veloz y tenso al estar de lado
		linear_damp = 0.0
		angular_velocity = randf_range(10.0, 16.0) * signf(v.x + 0.1)
	else:
		v *= 1.0      # Mantiene LA MISMA FÍSICA Y MAGIA QUE ANTES en lanzamiento normal
		linear_damp = 0.0
		angular_velocity = randf_range(2.0, 4.0) * signf(v.x + 0.1)
		
	linear_velocity = v
	launched.emit()

func _toggle_orientation() -> void:
	_orientation_rotated = not _orientation_rotated
	var target_rot = PI/2 if _orientation_rotated else 0.0
	
	if _return_tween != null and _return_tween.is_running():
		_return_tween.kill()
		
	var tw = create_tween()
	tw.tween_property(self, "rotation", target_rot, 0.15).set_trans(Tween.TRANS_SPRING)

func _screen_to_global(screen_pos: Vector2) -> Vector2:
	# Convert viewport screen coords -> global canvas coords (works for mouse & touch).
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _constrain_drag_point(raw_global: Vector2) -> Vector2:
	var p := raw_global

	# Sling can only be pulled downward from idle anchor.
	if p.y < _drag_start_global.y:
		p.y = _drag_start_global.y

	var down := clampf(p.y - _drag_start_global.y, 0.0, max_drag_distance)
	p.y = _drag_start_global.y + down
	p.x = clampf(p.x, _drag_start_global.x - max_side_drag, _drag_start_global.x + max_side_drag)
	
	var vw := get_viewport_rect().size.x
	var vh := get_viewport_rect().size.y
	p.x = clampf(p.x, 30.0, vw - 30.0)
	p.y = clampf(p.y, 30.0, vh - 20.0)
	
	return p

func _build_release_velocity() -> Vector2:
	var tension := _drag_current_global.y - _drag_start_global.y
	if tension < min_vertical_drag:
		return Vector2.ZERO

	# Tuned arcade model: boost lateral response while preserving vertical control.
	var dx := _drag_start_global.x - _drag_current_global.x
	var side_ratio := clampf(absf(dx) / max_side_drag, 0.0, 1.0)
	var down_ratio := clampf(tension / max_drag_distance, 0.0, 1.0)
	var side_term := pow(side_ratio, side_curve_power)
	var vertical_term := pow(down_ratio, vertical_curve_power)

	var speed_target := lerpf(float(min_up_release_speed), float(max_launch_speed), vertical_term)
	var release_x := signf(dx) * speed_target * side_launch_scale * side_term
	var release_y := -speed_target
	var v := Vector2(release_x, release_y)

	# Keep the launch inside a controllable cone, but wide enough for wall play.
	var max_angle := deg_to_rad(max_launch_angle_deg)
	var angle_from_up := absf(atan2(v.x, -v.y))
	if angle_from_up > max_angle:
		var s := signf(v.x)
		v.y = -maxf(float(min_up_release_speed), absf(v.x) / tan(max_angle))
		v.x = s * absf(v.x)

	if v.length() > max_launch_speed:
		v = v.normalized() * max_launch_speed
	return v

func _start_return_to_idle() -> void:
	if _returning:
		return
	_returning = true
	_state = STATE_RETURNING
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sling_base.visible = true
	sling_band.visible = false

	if _return_tween != null and _return_tween.is_running():
		_return_tween.kill()

	var from := global_position
	
	# Dinamically update idle anchor based on where it fell
	var viewport_w := get_viewport_rect().size.x
	_idle_anchor.x = clampf(from.x, 70.0, viewport_w - 70.0)
	
	var dx := _idle_anchor.x - from.x
	var dist := from.distance_to(_idle_anchor)
	var duration := clampf(0.22 + dist / 850.0, 0.22, 0.55)
	
	var target_rot := roundf(rotation / TAU) * TAU
	if absf(dx) > 20.0:
		target_rot += TAU * signf(dx)

	_return_tween = create_tween()
	_return_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_return_tween.parallel().tween_property(self, "global_position", _idle_anchor, duration)
	_return_tween.parallel().tween_property(self, "rotation", target_rot, duration)
	_return_tween.finished.connect(func() -> void:
		_returning = false
		_orientation_rotated = false
		_state = STATE_IDLE
		global_position = _idle_anchor
		rotation = 0.0
		linear_damp = 0.0
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		_update_idle_sling_base()
		landed_idle.emit()
	)

func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled and _dragging:
		_dragging = false
		sling_band.visible = false

func force_idle() -> void:
	if _return_tween != null and _return_tween.is_running():
		_return_tween.kill()
	_returning = false
	_dragging = false
	_orientation_rotated = false
	_state = STATE_IDLE
	freeze = true
	global_position = _idle_anchor
	rotation = 0.0
	linear_damp = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	sling_base.visible = true
	sling_band.visible = false
	_update_idle_sling_base()

func sync_toppings(progress: Dictionary) -> void:
	_update_cheese_layer(progress.get(Globals.ING_CHEESE, 0) > 0)
	_sync_small_topping(Globals.ING_MUSHROOM, int(progress.get(Globals.ING_MUSHROOM, 0)), TEX_MUSH_MASA)
	_sync_small_topping(Globals.ING_PEPPERONI, int(progress.get(Globals.ING_PEPPERONI, 0)), TEX_PEP_MASA)
	_sync_small_topping(Globals.ING_OLIVE, int(progress.get(Globals.ING_OLIVE, 0)), TEX_OLIVE_MASA)
	_sync_small_topping(Globals.ING_ANCHOVY, int(progress.get(Globals.ING_ANCHOVY, 0)), TEX_ANCHOVY_MASA)

func reset_toppings() -> void:
	for k in _topping_nodes_by_kind.keys():
		for n in _topping_nodes_by_kind[k]:
			if is_instance_valid(n):
				n.queue_free()
		_topping_nodes_by_kind[k].clear()
	_used_slot_indices.clear()
	_update_cheese_layer(false)

func _sling_anchor_left() -> Vector2:
	return _idle_anchor + Vector2(-sling_half_width, sling_anchor_y_offset)

func _sling_anchor_right() -> Vector2:
	return _idle_anchor + Vector2(sling_half_width, sling_anchor_y_offset)

func _update_idle_sling_base() -> void:
	sling_base.global_position = Vector2.ZERO
	sling_base.points = PackedVector2Array([
		_sling_anchor_left(),
		_sling_anchor_right()
	])

func _update_sling_band() -> void:
	var p0 := _sling_anchor_left()
	var p2 := _sling_anchor_right()
	var p1 := _drag_current_global
	var points := PackedVector2Array()
	var steps := 14
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		points.push_back(a.lerp(b, t))
	sling_band.global_position = Vector2.ZERO
	sling_band.points = points

func _setup_pizza_visuals() -> void:
	base_sprite.texture = load(TEX_MASA)
	base_sprite.centered = true
	base_sprite.z_index = 10
	toppings_container.z_index = 11
	_build_slots()
	reset_toppings()

func _update_cheese_layer(enabled: bool) -> void:
	base_sprite.texture = load(TEX_MASA_Q) if enabled else load(TEX_MASA)

func _build_slots() -> void:
	_slot_positions.clear()
	var rings: Array[float] = [20.0, 30.0, 38.0]
	for r in rings:
		for i in range(6):
			var a: float = (TAU / 6.0) * float(i) + randf_range(-0.12, 0.12)
			var p: Vector2 = Vector2(cos(a), sin(a)) * r
			p.y *= 0.82
			_slot_positions.append(p)
	_slot_positions.shuffle()

func _sync_small_topping(kind: String, target_count: int, texture_path: String) -> void:
	var arr: Array = _topping_nodes_by_kind[kind]
	while arr.size() > target_count:
		var last: Node2D = arr.pop_back()
		if is_instance_valid(last):
			var idx := int(last.get_meta("slot_idx", -1))
			_used_slot_indices.erase(idx)
			last.queue_free()

	while arr.size() < target_count:
		var slot_idx := _take_free_slot_index()
		if slot_idx < 0:
			break
		var spr := Sprite2D.new()
		spr.texture = load(texture_path)
		spr.centered = true
		spr.position = _slot_positions[slot_idx]
		spr.scale = Vector2.ONE * randf_range(0.92, 1.08)
		spr.rotation = randf_range(-0.35, 0.35)
		spr.z_index = 1
		spr.set_meta("slot_idx", slot_idx)
		toppings_container.add_child(spr)
		arr.append(spr)

	_topping_nodes_by_kind[kind] = arr

func _take_free_slot_index() -> int:
	var all := range(_slot_positions.size())
	var free: Array[int] = []
	for i in all:
		if not _used_slot_indices.has(i):
			free.append(i)
	if free.is_empty():
		return -1
	var idx := free[randi() % free.size()]
	_used_slot_indices.append(idx)
	return idx
