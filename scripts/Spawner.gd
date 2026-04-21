extends Node2D

signal pickup_spawned(pickup: Area2D)

@export var ingredient_scene: PackedScene
@export var rat_scene: PackedScene

@export var lane_ys: Array[float] = [200.0, 300.0, 400.0]
@export var spawn_interval := 1.15
@export var rat_chance := 0.5

var requirements := {
	Globals.ING_CHEESE: 1,
	Globals.ING_MUSHROOM: 5,
	Globals.ING_PEPPERONI: 5,
	Globals.ING_OLIVE: 5,
	Globals.ING_ANCHOVY: 3,
}

var progress := {
	Globals.ING_CHEESE: 0,
	Globals.ING_MUSHROOM: 0,
	Globals.ING_PEPPERONI: 0,
	Globals.ING_OLIVE: 0,
	Globals.ING_ANCHOVY: 0,
}

var _phase := 0 # 0 => only cheese+rats, 1 => others+rats (cheese no more)
var _t := 0.0
var _time_since_last_life := 0.0
var _time_since_vertical_life := 0.0
var _life_spawn_side := 1
var _spawns_since_ingredient := 0
@export var max_spawns_without_ingredient := 2

func _process(delta: float) -> void:
	_t += delta
	_time_since_last_life += delta
	_time_since_vertical_life += delta
	
	if _t < spawn_interval:
		return
	_t = 0.0
	
	if _time_since_vertical_life >= 33.0:
		_time_since_vertical_life = 0.0
		var w = get_viewport_rect().size.x
		_emit_ingredient(Globals.ING_LIFE, randf_range(60.0, w - 60.0), true)
		return

	if _time_since_last_life >= 10.0:
		_time_since_last_life = 0.0
		var w = get_viewport_rect().size.x
		var sx = -60.0 if _life_spawn_side == 1 else w + 60.0
		_life_spawn_side *= -1
		_emit_ingredient(Globals.ING_LIFE, sx)
		return
		
	_spawn_one()

func set_progress(kind: String, count: int) -> void:
	if progress.has(kind):
		progress[kind] = count
	# Recompute phase every update so round restarts always enforce cheese first.
	_phase = 1 if progress[Globals.ING_CHEESE] >= requirements[Globals.ING_CHEESE] else 0
	if _phase == 0:
		_spawns_since_ingredient = 0

func remaining(kind: String) -> int:
	if not requirements.has(kind):
		return 0
	return maxi(0, requirements[kind] - progress.get(kind, 0))

func _spawn_one() -> void:
	if ingredient_scene == null or rat_scene == null:
		return

	if _phase == 0:
		# First phase: cheese + rats. Only one cheese in screen allowed.
		var has_cheese := false
		for c in get_children():
			if c.get("kind") == Globals.ING_CHEESE and not c.is_queued_for_deletion():
				has_cheese = true
				break
				
		var force_cheese := _spawns_since_ingredient >= max_spawns_without_ingredient
		if has_cheese or (not force_cheese and randf() < rat_chance):
			_emit_instance(rat_scene)
			_spawns_since_ingredient += 1
		else:
			_emit_ingredient(Globals.ING_CHEESE)
			_spawns_since_ingredient = 0
		return

	# Phase 1: remaining ingredients + rats (no more cheese).
	# When an ingredient is completed, its "slot" effectively becomes a rat slot.
	var remaining_pool: Array[String] = []
	var completed_slots := 0
	for k in [Globals.ING_MUSHROOM, Globals.ING_PEPPERONI, Globals.ING_OLIVE, Globals.ING_ANCHOVY]:
		if remaining(k) > 0:
			remaining_pool.append(k)
		else:
			completed_slots += 1

	# Base rats are now doubled for testing. Completed ingredients further increase danger.
	var effective_rat_chance := rat_chance + (1.0 - rat_chance) * (float(completed_slots) / 4.0)
	var force_ingredient := _spawns_since_ingredient >= max_spawns_without_ingredient and not remaining_pool.is_empty()
	if not force_ingredient and randf() < effective_rat_chance:
		_emit_instance(rat_scene)
		_spawns_since_ingredient += 1
		return

	if remaining_pool.is_empty():
		_emit_instance(rat_scene)
		_spawns_since_ingredient += 1
		return
	_emit_ingredient(remaining_pool[randi() % remaining_pool.size()])
	_spawns_since_ingredient = 0

func _emit_ingredient(kind: String, forced_x: float = -999.0, is_vertical: bool = false) -> void:
	var node := ingredient_scene.instantiate() as Area2D
	node.kind = kind
	if is_vertical:
		node.position = Vector2(forced_x, -60.0)
		node.set("is_vertical", true)
	else:
		var sx = _spawn_x() if forced_x <= -900.0 else forced_x
		node.position = Vector2(sx, _spawn_y())
		node.direction = _spawn_dir(node.position.x)
	add_child(node)
	pickup_spawned.emit(node)

func _emit_instance(scene: PackedScene) -> void:
	var node := scene.instantiate() as Area2D
	
	if node is Area2D and node.has_method("_trigger_behavior_event"): # is Rat
		# 30% chance to spawn top-down
		if randf() < 0.30:
			node.position = Vector2(randf_range(100.0, 620.0), -60.0)
			node.set("is_vertical", true)
			add_child(node)
			pickup_spawned.emit(node)
			return
			
	node.position = Vector2(_spawn_x(), _spawn_y())
	node.direction = _spawn_dir(node.position.x)
	add_child(node)
	pickup_spawned.emit(node)

func _spawn_x() -> float:
	var w := get_viewport_rect().size.x
	return -60.0 if randf() < 0.5 else w + 60.0

func _spawn_dir(x: float) -> int:
	var w := get_viewport_rect().size.x
	return 1 if x < w * 0.5 else -1
	
func _spawn_y() -> float:
	return lane_ys[randi() % lane_ys.size()]
