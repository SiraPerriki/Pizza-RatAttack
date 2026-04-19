extends Node2D

@export var pizza_scene: PackedScene

@onready var pizza_spawn: Marker2D = $PizzaSpawn
@onready var spawner: Node2D = $Spawner
@onready var lives_label: RichTextLabel = $HUD/LivesLabel
@onready var goals_label: RichTextLabel = $HUD/GoalsLabel
@onready var phase_label: RichTextLabel = $HUD/PhaseLabel
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var feedback_timer: Timer = $HUD/FeedbackTimer
@onready var start_screen: CanvasLayer = $StartScreen
@onready var start_button: Button = $StartScreen/Panel/StartButton
@onready var quit_button_start: Button = $StartScreen/Panel/QuitButton
@onready var end_screen: CanvasLayer = $EndScreen
@onready var end_title: RichTextLabel = $EndScreen/Panel/Title
@onready var restart_button: Button = $EndScreen/Panel/RestartButton
@onready var quit_button_end: Button = $EndScreen/Panel/QuitButton

var lives := 3
var progress := {
	Globals.ING_CHEESE: 0,
	Globals.ING_MUSHROOM: 0,
	Globals.ING_PEPPERONI: 0,
	Globals.ING_OLIVE: 0,
}
var requirements := {
	Globals.ING_CHEESE: 1,
	Globals.ING_MUSHROOM: 5,
	Globals.ING_PEPPERONI: 5,
	Globals.ING_OLIVE: 5,
}

var _pizza: RigidBody2D
var _turn_active := false
var _turn_caught := false
var _is_playing := false
const MAX_LIVES := 3

func _ready() -> void:
	randomize()
	_assign_scenes()

	if spawner.has_signal("pickup_spawned"):
		spawner.pickup_spawned.connect(_on_pickup_spawned)
	feedback_timer.timeout.connect(_on_feedback_timeout)
	start_button.pressed.connect(_on_start_pressed)
	quit_button_start.pressed.connect(_on_quit_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button_end.pressed.connect(_on_quit_pressed)

	_show_start_screen()

func _assign_scenes() -> void:
	if pizza_scene == null:
		pizza_scene = load("res://scenes/Pizza.tscn")
	if spawner != null:
		if spawner.get("ingredient_scene") == null:
			spawner.set("ingredient_scene", load("res://scenes/Ingredient.tscn"))
		if spawner.get("rat_scene") == null:
			spawner.set("rat_scene", load("res://scenes/Rat.tscn"))

func _spawn_pizza() -> void:
	if pizza_scene == null:
		pizza_scene = load("res://scenes/Pizza.tscn")
	if is_instance_valid(_pizza):
		_pizza.queue_free()
	_pizza = pizza_scene.instantiate() as RigidBody2D
	_pizza.global_position = pizza_spawn.global_position
	if _pizza.has_signal("launched"):
		_pizza.launched.connect(_on_pizza_launched)
	if _pizza.has_signal("landed_idle"):
		_pizza.landed_idle.connect(_on_pizza_landed_idle)
	add_child(_pizza)
	if _pizza.has_method("force_idle"):
		_pizza.force_idle()
	if _pizza.has_method("reset_toppings"):
		_pizza.reset_toppings()
	if _pizza.has_method("set_controls_enabled"):
		_pizza.set_controls_enabled(_is_playing)

func _on_pickup_spawned(pickup: Area2D) -> void:
	if pickup.has_signal("picked"):
		pickup.picked.connect(_on_pickup_picked)

func _on_pickup_picked(kind: String) -> void:
	if not _is_playing:
		return
	_turn_caught = true

	if kind == "rat":
		lives -= 1
		_show_feedback("!Mordisco de rata!", Color(1, 0.34, 0.34, 1))
		if lives <= 0:
			_end_match(false)
			return
		_refresh_hud()
		return

	if progress.has(kind):
		if progress[kind] < requirements.get(kind, 0):
			progress[kind] += 1
			match kind:
				Globals.ING_CHEESE:
					_show_feedback("!Ya tienes el queso!", Color(1, 0.94, 0.4, 1))
				Globals.ING_MUSHROOM:
					_show_feedback("Has cogido champinion", Color(0.86, 0.8, 0.74, 1))
				Globals.ING_PEPPERONI:
					_show_feedback("Has cogido pepperoni", Color(0.95, 0.35, 0.35, 1))
				Globals.ING_OLIVE:
					_show_feedback("Has cogido aceituna", Color(0.4, 0.85, 0.4, 1))
		else:
			_show_feedback("Ese ingrediente ya esta completo", Color(0.9, 0.9, 0.9, 1))

	_sync_spawner()
	_sync_pizza_toppings()
	_refresh_hud()
	if _is_completed():
		_end_match(true)

func _sync_spawner() -> void:
	for k in progress.keys():
		spawner.set_progress(k, progress[k])

func _is_completed() -> bool:
	for k in requirements.keys():
		if progress.get(k, 0) < requirements[k]:
			return false
	return true

func _refresh_hud() -> void:
	lives_label.text = _build_hearts_text()

	# Ingredientes en línea horizontal con emojis
	goals_label.text = (
		"[b][color=#FFE55A]🧀 %d/%d[/color][/b]   " % [progress[Globals.ING_CHEESE], requirements[Globals.ING_CHEESE]] +
		"[b][color=#E5D1BF]🍄 %d/%d[/color][/b]   " % [progress[Globals.ING_MUSHROOM], requirements[Globals.ING_MUSHROOM]] +
		"[b][color=#FF6D6D]🌶 %d/%d[/color][/b]   " % [progress[Globals.ING_PEPPERONI], requirements[Globals.ING_PEPPERONI]] +
		"[b][color=#7BE07B]🫒 %d/%d[/color][/b]" % [progress[Globals.ING_OLIVE], requirements[Globals.ING_OLIVE]]
	)

	# Fase: texto compacto alineado a la derecha
	if progress[Globals.ING_CHEESE] < requirements[Globals.ING_CHEESE]:
		phase_label.text = "[right][color=#FFE55A]🧀 Queso primero[/color][/right]"
	else:
		phase_label.text = "[right][color=#AADDAA]Ingredientes libres[/color][/right]"

func _build_hearts_text() -> String:
	var t := "[b]Vidas:[/b] "
	for i in range(MAX_LIVES):
		if i < lives:
			t += "[color=#FF4A4A]♥[/color] "
		else:
			t += "[color=#555555]♥[/color] "
	return t.strip_edges()

func _reset_round_data() -> void:
	lives = 3
	_turn_active = false
	_turn_caught = false
	for k in progress.keys():
		progress[k] = 0
	for c in spawner.get_children():
		c.queue_free()
	feedback_label.text = ""
	feedback_timer.stop()
	_sync_spawner()
	_sync_pizza_toppings()
	_refresh_hud()

func _set_play_state(playing: bool) -> void:
	_is_playing = playing
	spawner.set_process(playing)
	if is_instance_valid(_pizza) and _pizza.has_method("set_controls_enabled"):
		_pizza.set_controls_enabled(playing)
	if is_instance_valid(_pizza) and not playing and _pizza.has_method("force_idle"):
		_pizza.force_idle()

func _show_start_screen() -> void:
	_set_play_state(false)
	_reset_round_data()
	_spawn_pizza()
	start_screen.visible = true
	end_screen.visible = false
	phase_label.text = "[right]¡Pulsa Iniciar![/right]"

func _start_match() -> void:
	_reset_round_data()
	_spawn_pizza()
	start_screen.visible = false
	end_screen.visible = false
	_set_play_state(true)

func _end_match(victory: bool) -> void:
	_set_play_state(false)
	end_title.text = "[center][b][color=#7BE07B]🍕 PIZZA COMPLETA! 🍕[/color][/b][/center]" if victory else "[center][b][color=#FF6D6D]💀 GAME OVER 💀[/color][/b][/center]"
	end_screen.visible = true

func _on_start_pressed() -> void:
	_start_match()

func _on_restart_pressed() -> void:
	_start_match()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_pizza_launched() -> void:
	if not _is_playing:
		return
	_turn_active = true
	_turn_caught = false

func _on_pizza_landed_idle() -> void:
	if _is_playing and _turn_active and not _turn_caught:
		_show_feedback("No has cogido nada", Color(0.88, 0.88, 0.88, 1))
	_turn_active = false

func _show_feedback(text: String, color: Color = Color.WHITE) -> void:
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_timer.start()

func _on_feedback_timeout() -> void:
	feedback_label.text = ""

func _sync_pizza_toppings() -> void:
	if is_instance_valid(_pizza) and _pizza.has_method("sync_toppings"):
		_pizza.sync_toppings(progress)
