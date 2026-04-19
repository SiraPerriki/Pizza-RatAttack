extends Node2D

signal pickup_spawned(pickup: Area2D)

@export var ingredient_scene: PackedScene
@export var rat_scene: PackedScene

@export var lane_y := 300.0
@export var spawn_interval := 1.15
@export var rat_chance := 0.5

var requirements := {
	Globals.ING_CHEESE: 1,
	Globals.ING_MUSHROOM: 5,
	Globals.ING_PEPPERONI: 5,
	Globals.ING_OLIVE: 5,
}

var progress := {
	Globals.ING_CHEESE: 0,
	Globals.ING_MUSHROOM: 0,
	Globals.ING_PEPPERONI: 0,
	Globals.ING_OLIVE: 0,
}

var _phase := 0 # 0 => only cheese+rats, 1 => others+rats (cheese no more)
var _t := 0.0
var _spawns_since_ingredient := 0
@export var max_spawns_without_ingredient := 2

func _process(delta: float) -> void:
	_t += delta
	if _t < spawn_interval:
		return
	_t = 0.0
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
		# First phase: cheese + rats.
		var force_cheese := _spawns_since_ingredient >= max_spawns_without_ingredient
		if not force_cheese and randf() < rat_chance:
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
	for k in [Globals.ING_MUSHROOM, Globals.ING_PEPPERONI, Globals.ING_OLIVE]:
		if remaining(k) > 0:
			remaining_pool.append(k)
		else:
			completed_slots += 1

	# Base rats are now doubled for testing. Completed ingredients further increase danger.
	var effective_rat_chance := rat_chance + (1.0 - rat_chance) * (float(completed_slots) / 3.0)
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

func _emit_ingredient(kind: String) -> void:
	var node := ingredient_scene.instantiate() as Area2D
	node.kind = kind
	node.position = Vector2(_spawn_x(), lane_y)
	node.direction = _spawn_dir(node.position.x)
	add_child(node)
	pickup_spawned.emit(node)

func _emit_instance(scene: PackedScene) -> void:
	var node := scene.instantiate() as Area2D
	node.position = Vector2(_spawn_x(), lane_y)
	node.direction = _spawn_dir(node.position.x)
	add_child(node)
	pickup_spawned.emit(node)

func _spawn_x() -> float:
	var w := get_viewport_rect().size.x
	return -60.0 if randf() < 0.5 else w + 60.0

func _spawn_dir(x: float) -> int:
	var w := get_viewport_rect().size.x
	return 1 if x < w * 0.5 else -1


