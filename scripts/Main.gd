extends Node2D

@export var pizza_scene: PackedScene

@onready var pizza_spawn: Marker2D = $PizzaSpawn
@onready var spawner: Node2D = $Spawner
@onready var lives_label: RichTextLabel = $HUD/LivesLabel
@onready var goals_label: RichTextLabel = $HUD/GoalsLabel
@onready var phase_label: RichTextLabel = $HUD/PhaseLabel
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var feedback_timer: Timer = $HUD/FeedbackTimer
@onready var pause_button: Button = $HUD/PauseButton
@onready var start_screen: CanvasLayer = $StartScreen
@onready var start_button: Button = $StartScreen/Panel/StartButton
@onready var quit_button_start: Button = $StartScreen/Panel/QuitButton
@onready var pause_screen: CanvasLayer = $PauseScreen
@onready var resume_button: Button = $PauseScreen/Panel/ResumeButton
@onready var quit_button_pause: Button = $PauseScreen/Panel/QuitButton
@onready var end_screen: CanvasLayer = $EndScreen
@onready var score_final_label: RichTextLabel = $EndScreen/Panel/ScoreFinalLabel
@onready var end_title: RichTextLabel = $EndScreen/Panel/Title
@onready var restart_button: Button = $EndScreen/Panel/RestartButton
@onready var quit_button_end: Button = $EndScreen/Panel/QuitButton
@onready var score_label: RichTextLabel = $HUD/ScoreLabel
@onready var lives_container: HBoxContainer = $HUD/LivesContainer
@onready var bg_option: OptionButton = $StartScreen/Panel/BgOption
@onready var bg_image: TextureRect = $BgImage
@onready var bg_checker: ColorRect = $Background
@onready var danger_overlay: ColorRect = $HUD/DangerOverlay

var score := 0
var combo := 1
var lives := 3
var round_time := 0.0

var rankings_score := []
var rankings_time := []
const SAVE_PATH := "user://pizza_rankings.json"

var progress := {
	Globals.ING_CHEESE: 0,
	Globals.ING_MUSHROOM: 0,
	Globals.ING_PEPPERONI: 0,
	Globals.ING_OLIVE: 0,
	Globals.ING_ANCHOVY: 0,
}
var requirements := {
	Globals.ING_CHEESE: 1,
	Globals.ING_MUSHROOM: 5,
	Globals.ING_PEPPERONI: 5,
	Globals.ING_OLIVE: 5,
	Globals.ING_ANCHOVY: 3,
}

var _pizza: RigidBody2D
var _turn_active := false
var _turn_caught := false
var _is_playing := false
var _camera_shake_time := 0.0
var _is_invulnerable := false

func _ready() -> void:
	randomize()
	_assign_scenes()
	_apply_pixel_theme()

	if spawner.has_signal("pickup_spawned"):
		spawner.pickup_spawned.connect(_on_pickup_spawned)
	feedback_timer.timeout.connect(_on_feedback_timeout)
	start_button.pressed.connect(_on_start_pressed)
	quit_button_start.pressed.connect(_on_quit_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button_end.pressed.connect(_on_quit_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button_pause.pressed.connect(_on_quit_pressed)

	_load_rankings()
	bg_option.add_item("Fondo Mantel", 0)
	bg_option.add_item("Fondo Rosa", 1)
	bg_option.add_item("Fondo Verde", 2)
	bg_option.item_selected.connect(_on_bg_selected)
	_on_bg_selected(0)

	var name_inp = get_node_or_null("EndScreen/Panel/NameInput")
	if name_inp:
		name_inp.text_submitted.connect(_on_name_submitted)
	
	var music = AudioStreamPlayer.new()
	add_child(music)
	if ResourceLoader.exists("res://audio/music_loop.ogg"):
		music.stream = load("res://audio/music_loop.ogg")
	elif ResourceLoader.exists("res://audio/arcade.ogg"):
		music.stream = load("res://audio/arcade.ogg")
	elif ResourceLoader.exists("res://audio/music_loop.mp3"):
		music.stream = load("res://audio/music_loop.mp3")
	music.autoplay = true
	music.play()
	
	if has_node("HUD/ScoreLabel"):
		score_label.pivot_offset = Vector2(340, 30)

	_show_start_screen()

func _apply_pixel_theme() -> void:
	var font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	if font:
		var t := Theme.new()
		t.default_font = font
		
		# Some font size adjustments for the blocky pixel font
		var controls = [
			lives_label, goals_label, phase_label, feedback_label,
			start_button, quit_button_start, restart_button, quit_button_end,
			end_title, $StartScreen/Panel/Title, $StartScreen/Panel/Subtitle,
			pause_button, $PauseScreen/Panel/Title, resume_button, quit_button_pause
		]
		for c in controls:
			if is_instance_valid(c) and c is Control:
				c.theme = t
				
		# Update default font sizes to match the pixel-art blockiness
		lives_label.add_theme_font_size_override("normal_font_size", 18)
		goals_label.add_theme_font_size_override("normal_font_size", 14)
		phase_label.add_theme_font_size_override("normal_font_size", 14)
		feedback_label.add_theme_font_size_override("font_size", 22)
		
		# Adding line spacing overrides
		$StartScreen/Panel/Title.add_theme_constant_override("line_separation", 10)
		$StartScreen/Panel/Subtitle.add_theme_constant_override("line_separation", 12)
		goals_label.add_theme_constant_override("line_separation", 6)
		
		$StartScreen/Panel/Title.add_theme_font_size_override("normal_font_size", 28)
		$StartScreen/Panel/Subtitle.add_theme_font_size_override("normal_font_size", 16)
		end_title.add_theme_font_size_override("normal_font_size", 32)
		start_button.add_theme_font_size_override("font_size", 18)
		quit_button_start.add_theme_font_size_override("font_size", 16)
		restart_button.add_theme_font_size_override("font_size", 18)
		quit_button_end.add_theme_font_size_override("font_size", 16)
		
		$PauseScreen/Panel/Title.add_theme_font_size_override("normal_font_size", 32)
		pause_button.add_theme_font_size_override("font_size", 18)
		resume_button.add_theme_font_size_override("font_size", 20)
		quit_button_pause.add_theme_font_size_override("font_size", 16)

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

func _on_pickup_picked(kind: String, pos: Vector2 = Vector2.ZERO, node_ref: Node = null) -> void:
	if not _is_playing:
		return
	_turn_caught = true

	if kind == "rat":
		if _is_invulnerable:
			if is_instance_valid(node_ref) and node_ref.has_method("queue_free"):
				node_ref.queue_free()
			return
			
		_is_invulnerable = true
		_start_invulnerability()
		
		combo = 1
		lives -= 1
		_spawn_floating_text("-1 VIDA!", pos, Color(1, 0.2, 0.2))
		_show_feedback("!Mordisco de rata!", Color(1, 0.34, 0.34, 1))
		
		# Pegar rata a la pizza y teñirla de rojo
		if is_instance_valid(node_ref) and is_instance_valid(_pizza):
			if node_ref.has_method("set_deferred"):
				node_ref.set_deferred("monitoring", false)
			node_ref.process_mode = Node.PROCESS_MODE_DISABLED
			node_ref.modulate = Color(1.5, 0.2, 0.2, 1.0)
			var p = node_ref.get_parent()
			if p:
				p.remove_child(node_ref)
			_pizza.add_child(node_ref)
			node_ref.global_position = pos
			_rat_escape(node_ref)
			
		_trigger_hitstop(lives <= 0)
		return

	if kind == Globals.ING_LIFE:
		lives += 1
		_spawn_floating_text("+1 VIDA!", pos, Color(1, 0.4, 0.8))
		_refresh_hud()
		if is_instance_valid(node_ref) and node_ref.has_method("queue_free"):
			node_ref.queue_free()
		return

	var pts := 10 * combo
	score += pts
	_spawn_floating_text("+%d" % pts, pos, Color(0.4, 1, 0.4))
	
	var tw = create_tween()
	tw.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.05).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(score_label, "modulate", Color(1.5, 1.5, 0.5), 0.05)
	tw.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.15)
	tw.parallel().tween_property(score_label, "modulate", Color(1, 1, 1), 0.15)
	
	if combo > 1:
		_spawn_floating_text("Combo x%d!" % combo, pos + Vector2(0, 30), Color(1, 0.9, 0.2))
	combo += 1

	if is_instance_valid(node_ref) and node_ref.has_method("queue_free"):
		node_ref.queue_free()

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
				Globals.ING_ANCHOVY:
					_show_feedback("Has cogido anchoa", Color(0.3, 0.6, 0.9, 1))
		else:
			_show_feedback("Ese ingrediente ya esta completo", Color(0.9, 0.9, 0.9, 1))

	_sync_spawner()
	_sync_pizza_toppings()
	_refresh_hud()
	if _is_completed():
		_end_match(true)

func _trigger_hitstop(is_fatal: bool) -> void:
	Engine.time_scale = 0.05
	_camera_shake_time = 0.4
	
	# Usamos un timer ignorando el time_scale para que cuente tiempo real 0.4s
	await get_tree().create_timer(0.4, true, false, true).timeout
	Engine.time_scale = 1.0
	
	if is_fatal:
		await get_tree().create_timer(1.0, true, false, true).timeout
		_end_match(false)
	else:
		_refresh_hud()

func _start_invulnerability() -> void:
	# El pizza debería parpadear si tuviéramos acceso a su sprite, 
	# pero por ahora bloqueamos colisiones mortales lógicamente
	await get_tree().create_timer(1.0, true, false, true).timeout
	_is_invulnerable = false

func _rat_escape(node: Node) -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	if is_instance_valid(node):
		var tw = create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(node, "position", node.position + Vector2(randf_range(-150, 150), -600), 0.5).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(node, "rotation", randf_range(-10, 10), 0.5)
		tw.parallel().tween_property(node, "modulate:a", 0.0, 0.4).set_delay(0.1)
		tw.chain().tween_callback(node.queue_free)

func _sync_spawner() -> void:
	for k in progress.keys():
		spawner.set_progress(k, progress[k])

func _is_completed() -> bool:
	for k in requirements.keys():
		if progress.get(k, 0) < requirements[k]:
			return false
	return true

func _refresh_hud() -> void:
	_update_lives_container()
	var m = int(round_time) / 60
	var s = int(round_time) % 60
	score_label.text = "[right]⏱ %02d:%02d | %d [color=#AAA]x%d[/color][/right]" % [m, s, score, combo]

	# Ingredientes en línea horizontal con emojis
	goals_label.text = (
		"[b][color=#FFE55A]🧀 %d/%d[/color][/b]   " % [progress[Globals.ING_CHEESE], requirements[Globals.ING_CHEESE]] +
		"[b][color=#E5D1BF]🍄 %d/%d[/color][/b]   " % [progress[Globals.ING_MUSHROOM], requirements[Globals.ING_MUSHROOM]] +
		"[b][color=#FF6D6D]🌶 %d/%d[/color][/b]   " % [progress[Globals.ING_PEPPERONI], requirements[Globals.ING_PEPPERONI]] +
		"[b][color=#7BE07B]🫒 %d/%d[/color][/b]   " % [progress[Globals.ING_OLIVE], requirements[Globals.ING_OLIVE]] +
		"[b][color=#8BC5FF]🐟 %d/%d[/color][/b]" % [progress[Globals.ING_ANCHOVY], requirements[Globals.ING_ANCHOVY]]
	)

	# Fase: texto compacto alineado a la derecha
	if progress[Globals.ING_CHEESE] < requirements[Globals.ING_CHEESE]:
		phase_label.text = "[right][color=#FFE55A]🧀 Queso primero[/color][/right]"
	else:
		phase_label.text = "[right][color=#AADDAA]Ingredientes libres[/color][/right]"

func _update_lives_container() -> void:
	for child in lives_container.get_children():
		child.queue_free()
		
	for i in range(lives):
		var t = TextureRect.new()
		t.texture = load("res://img/vida.png")
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(36, 36)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lives_container.add_child(t)

func _reset_round_data() -> void:
	lives = 3
	score = 0
	combo = 1
	round_time = 0.0
	_is_invulnerable = false
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
	get_tree().paused = false
	if pause_screen: pause_screen.visible = false
	_set_play_state(false)
	_reset_round_data()
	_spawn_pizza()
	_show_panel_animated(start_screen, $StartScreen/Panel)
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
	var is_rec = _is_record()
	var m = int(round_time) / 60
	var s = int(round_time) % 60

	end_title.text = "[center][b][color=#7BE07B]🍕 PIZZA COMPLETA! 🍕[/color][/b][/center]" if victory else "[center][b][color=#FF6D6D]💀 GAME OVER 💀[/color][/b][/center]"
	score_final_label.text = "[center]Puntuación: %d  (⏱️%02d:%02d)\n" % [score, m, s]

	var name_inp = get_node_or_null("EndScreen/Panel/NameInput") as LineEdit
	var btn_res = get_node_or_null("EndScreen/Panel/RestartButton") as Button
	if is_rec and name_inp:
		score_final_label.text += "\n[color=#FFD700]¡NUEVO RÉCORD! Escribe tu nombre:[/color][/center]"
		name_inp.visible = true
		name_inp.text = ""
		name_inp.grab_focus()
		if btn_res: btn_res.visible = false
	else:
		score_final_label.text += "\n[color=#999]No has superado ningún récord.[/color]\n"
		var t = "\n[color=#FFE0B2][b]-- TOP 5 PUNTOS --[/b]\n"
		for r in rankings_score:
			t += "%s : %d pts (⏱%02d:%02d)\n" % [r["name"], r["score"], int(r["time"])/60, int(r["time"])%60]
		score_final_label.text += t + "[/color][/center]"
		if name_inp: name_inp.visible = false
		if btn_res: btn_res.visible = true
		
	_show_panel_animated(end_screen, $EndScreen/Panel)

func _is_record() -> bool:
	if score > 0:
		if rankings_score.size() < 5: return true
		for r in rankings_score:
			if score > r["score"]: return true
	if round_time > 0.0:
		if rankings_time.size() < 5: return true
		for r in rankings_time:
			if round_time > r["time"]: return true
	return false

func _on_name_submitted(new_text: String) -> void:
	var player_name = new_text.strip_edges()
	if player_name == "": return
	
	var entry = {"name": player_name, "score": score, "time": round_time}
	rankings_score.append(entry)
	rankings_score.sort_custom(func(a, b): 
		if a["score"] == b["score"]: return a["time"] > b["time"]
		return a["score"] > b["score"]
	)
	if rankings_score.size() > 5: rankings_score.resize(5)
	
	rankings_time.append(entry)
	rankings_time.sort_custom(func(a, b):
		if a["time"] == b["time"]: return a["score"] > b["score"]
		return a["time"] > b["time"]
	)
	if rankings_time.size() > 5: rankings_time.resize(5)
	
	_save_rankings()
	
	var name_inp = get_node_or_null("EndScreen/Panel/NameInput")
	var btn_res = get_node_or_null("EndScreen/Panel/RestartButton")
	if name_inp: name_inp.visible = false
	if btn_res: btn_res.visible = true
	
	var t = "[center][b]-- TOP 5 PUNTOS --[/b]\n"
	for r in rankings_score:
		t += "%s - %d pts (⏱%02d:%02d)\n" % [r["name"], r["score"], int(r["time"])/60, int(r["time"])%60]
	score_final_label.text = t + "[/center]"

func _on_start_pressed() -> void:
	_start_match()

func _on_restart_pressed() -> void:
	_start_match()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_pause_pressed() -> void:
	if not _is_playing or get_tree().paused:
		return
	get_tree().paused = true
	_show_panel_animated(pause_screen, $PauseScreen/Panel)

func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_screen.visible = false

func _on_pizza_launched() -> void:
	if not _is_playing:
		return
	_turn_active = true
	_turn_caught = false

func _on_pizza_landed_idle() -> void:
	if _is_playing and _turn_active and not _turn_caught:
		_show_feedback("No has cogido nada", Color(0.88, 0.88, 0.88, 1))
	combo = 1
	_refresh_hud()
	_turn_active = false

func _show_feedback(text: String, color: Color = Color.WHITE) -> void:
	if feedback_timer.time_left > 1.8 and feedback_label.text != "" and feedback_label.text != text:
		feedback_label.text += "\n" + text
	else:
		feedback_label.text = text
	feedback_label.modulate = color
	feedback_timer.start()

func _on_feedback_timeout() -> void:
	feedback_label.text = ""

func _show_panel_animated(screen: CanvasLayer, panel: Control) -> void:
	screen.visible = true
	var target_y = 370.0 if screen == start_screen else 390.0
	panel.position.y = -600.0
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "position:y", target_y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _spawn_floating_text(text: String, pos: Vector2, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.global_position = pos - Vector2(25, 10)
	lbl.modulate = color
	lbl.z_index = 100
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 6)
	var font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	if font: lbl.add_theme_font_override("font", font)
	
	add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 60.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

func _process(delta: float) -> void:
	if _is_playing:
		round_time += delta
		var m = int(round_time) / 60
		var s = int(round_time) % 60
		score_label.text = "[right]⏱ %02d:%02d | %d [color=#AAA]x%d[/color][/right]" % [m, s, score, combo]
		
	if _camera_shake_time > 0.0:
		var real_delta = delta * (1.0 / Engine.time_scale) if Engine.time_scale > 0.001 else 0.016
		_camera_shake_time -= real_delta
		if has_node("Camera2D"):
			if _camera_shake_time > 0.0:
				$Camera2D.offset = Vector2(randf_range(-14, 14), randf_range(-14, 14))
			else:
				$Camera2D.offset = Vector2.ZERO

	if danger_overlay == null: return
	if not _is_playing:
		if danger_overlay.modulate.a > 0.0:
			danger_overlay.modulate.a = lerpf(danger_overlay.modulate.a, 0.0, delta * 3.0)
		return
		
	var rat_count = 0
	for c in spawner.get_children():
		if c.get("kind") == "rat":
			rat_count += 1
			
	var target_alpha = clampf(float(rat_count) * 0.12, 0.0, 0.35)
	var pulse = sin(Time.get_ticks_msec() / 150.0) * 0.08 if rat_count > 0 else 0.0
	danger_overlay.modulate.a = lerpf(danger_overlay.modulate.a, target_alpha + pulse, delta * 5.0)

func _sync_pizza_toppings() -> void:
	if is_instance_valid(_pizza) and _pizza.has_method("sync_toppings"):
		_pizza.sync_toppings(progress)

func _load_rankings() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file_str = FileAccess.get_file_as_string(SAVE_PATH)
		var data = JSON.parse_string(file_str)
		if typeof(data) == TYPE_DICTIONARY:
			if data.has("scores"): rankings_score = data["scores"]
			if data.has("times"): rankings_time = data["times"]

func _save_rankings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"scores": rankings_score, "times": rankings_time}))

func _on_bg_selected(index: int) -> void:
	if index == 0:
		bg_checker.visible = true
		bg_image.visible = false
	elif index == 1:
		bg_checker.visible = false
		bg_image.visible = true
		bg_image.texture = load("res://img/fondo_rosa.png")
	elif index == 2:
		bg_checker.visible = false
		bg_image.visible = true
		bg_image.texture = load("res://img/fondo_verde.png")
