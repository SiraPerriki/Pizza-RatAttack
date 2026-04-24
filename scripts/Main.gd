extends Node2D

var mute_btn: Button
var bg_music: AudioStreamPlayer
var is_muted := false
var sfx_sys: Node
var stats_boxes := {}
var stats_container: HBoxContainer
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
@onready var rankings_button: Button = $StartScreen/Panel/RankingsButton
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
@onready var rankings_screen: CanvasLayer = $RankingsScreen
@onready var rankings_title: RichTextLabel = $RankingsScreen/Panel/Title
@onready var rankings_text: RichTextLabel = $RankingsScreen/Panel/RankingsText
@onready var close_rankings_button: Button = $RankingsScreen/Panel/CloseRankingsBtn

var score := 0
var combo := 1
var lives := 3
var round_time := 0.0

const MODE_EASY := "easy"
const MODE_EXPERT := "expert"
const SAVE_PATH := "user://pizza_rankings.json"
const GAME_AREA_SIZE := Vector2(720, 1280)
const CELEBRATION_PIZZA_TEXTURE := "res://img/masa.png"
const PIXEL_FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const EXPERT_SPEED_STEP := 0.10
const EXPERT_RAT_STEP := 0.10
const EXPERT_EXTRA_COMPLETED_POINTS := 1

var current_mode := MODE_EASY
var rankings_by_mode := {
	MODE_EASY: {"scores": [], "times": []},
	MODE_EXPERT: {"scores": [], "times": []},
}
var rankings_score := []
var rankings_time := []
var expert_button: Button

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
var completed_pizzas := 0
var _game_over_invasion_active := false
var _is_celebrating := false

func _ready() -> void:
	randomize()
	_assign_scenes()
	_apply_pixel_theme()

	if spawner.has_signal("pickup_spawned"):
		spawner.pickup_spawned.connect(_on_pickup_spawned)
	feedback_timer.timeout.connect(_on_feedback_timeout)
	start_button.pressed.connect(_on_start_pressed)
	rankings_button.pressed.connect(_on_rankings_pressed)
	quit_button_start.pressed.connect(_on_quit_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button_end.pressed.connect(_on_quit_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button_pause.pressed.connect(_on_quit_pressed)
	close_rankings_button.pressed.connect(_on_close_rankings_pressed)

	_load_rankings()
	_set_mode(MODE_EASY)
	bg_option.add_item("Fondo Mantel", 0)
	bg_option.add_item("Fondo Rosa", 1)
	bg_option.add_item("Fondo Verde", 2)
	bg_option.add_item("Clásico", 3)
	bg_option.add_item("Restaurante", 4)
	bg_option.add_item("Restaurante 2", 5)
	
	bg_option.item_selected.connect(_on_bg_selected)
	bg_option.selected = 3
	_on_bg_selected(3)

	var name_inp = get_node_or_null("EndScreen/Panel/NameInput")
	if name_inp:
		name_inp.text_submitted.connect(_on_name_submitted)
	
	# Sistema de Audio
	bg_music = AudioStreamPlayer.new()
	bg_music.volume_db = -12.0 # Bajar volumen para los sfx
	var stream = load("res://sounds/audio_rat.mp3")
	if stream is AudioStreamMP3:
		stream.loop = true
	bg_music.stream = stream
	add_child(bg_music)
	bg_music.play()
	
	# Restaurar Efectos de Sonido
	sfx_sys = load("res://scripts/SFXSystem.gd").new()
	add_child(sfx_sys)
	
	# Mute Button en HUD
	mute_btn = Button.new()
	mute_btn.text = "🔊"
	mute_btn.position = Vector2(650, 1145)
	mute_btn.size = Vector2(50, 40)
	mute_btn.pressed.connect(_on_mute_toggled)
	if has_node("HUD"): get_node("HUD").add_child(mute_btn)
	
	# Reposicionar componentes del HUD a la zona inferior
	if has_node("HUD/Panel"): 
		var pnl = get_node("HUD/Panel")
		pnl.position = Vector2(0, 1070)
		pnl.size = Vector2(720, 210) # 210px para extra aire
	if has_node("HUD/PauseButton"): get_node("HUD/PauseButton").position = Vector2(650, 1085)
	mute_btn.position = Vector2(590, 1085)
	var btn_st = StyleBoxFlat.new()
	btn_st.bg_color = Color(0.18, 0.18, 0.22, 0.95)
	btn_st.corner_radius_top_left = 6
	btn_st.corner_radius_top_right = 6
	btn_st.corner_radius_bottom_left = 6
	btn_st.corner_radius_bottom_right = 6
	mute_btn.add_theme_stylebox_override("normal", btn_st)
	var btn_hov = btn_st.duplicate()
	btn_hov.bg_color = Color(0.28, 0.28, 0.32, 0.95)
	mute_btn.add_theme_stylebox_override("hover", btn_hov)
	
	if has_node("HUD/LivesLabel"): 
		get_node("HUD/LivesLabel").visible = false
	if has_node("HUD/LivesContainer"): get_node("HUD/LivesContainer").position = Vector2(20, 1085)
	
	if has_node("HUD/ScoreLabel"): 
		var s_lbl = get_node("HUD/ScoreLabel")
		s_lbl.position = Vector2(20, 1130)
		s_lbl.size = Vector2(680, 120)
	
	# Reformar stats
	if is_instance_valid(phase_label):
		phase_label.queue_free()
	if is_instance_valid(goals_label):
		var p = goals_label.get_parent()
		stats_container = HBoxContainer.new()
		stats_container.position = Vector2(20, 1195)
		stats_container.size = Vector2(680, 50)
		stats_container.add_theme_constant_override("separation", 10)
		p.add_child(stats_container)
		
		var emojis = {
			Globals.ING_CHEESE: "🧀",
			Globals.ING_MUSHROOM: "🍄",
			Globals.ING_PEPPERONI: "🌶",
			Globals.ING_OLIVE: "🫒",
			Globals.ING_ANCHOVY: "🐟"
		}
		var colors = {
			Globals.ING_CHEESE: Color("#FFE55A"),
			Globals.ING_MUSHROOM: Color("#E5D1BF"),
			Globals.ING_PEPPERONI: Color("#FF6D6D"),
			Globals.ING_OLIVE: Color("#7BE07B"),
			Globals.ING_ANCHOVY: Color("#8BC5FF")
		}
		
		var t = Theme.new()
		var font = load("res://assets/fonts/PressStart2P-Regular.ttf")
		if font: t.default_font = font
		
		for k in emojis.keys():
			var l = RichTextLabel.new()
			l.bbcode_enabled = true
			l.custom_minimum_size = Vector2(100, 30)
			l.scroll_active = false
			l.theme = t
			l.add_theme_font_size_override("normal_font_size", 16)
			l.pivot_offset = Vector2(50, 15)
			stats_boxes[k] = {"node": l, "emoji": emojis[k], "color": colors[k]}
			stats_container.add_child(l)
			
		goals_label.queue_free()
	
	if has_node("HUD/ScoreLabel"):
		score_label.pivot_offset = Vector2(340, 30)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.border_width_bottom = 4
		style.border_color = Color(0.9, 0.9, 0.9, 0.1)
		score_label.add_theme_stylebox_override("normal", style)

	# Añadir Bumpers Top
	var bumper_tex = load("res://img/bumper_top.png")
	if bumper_tex:
		var bumper_script = load("res://scripts/Bumper.gd")
		for x_pos in [120, 600]:
			var b = Area2D.new()
			b.set_script(bumper_script)
			b.is_top = true
			b.top_bounce_speed = 1200.0
			b.position = Vector2(x_pos, 30)
			b.z_index = 5
			
			var spr = Sprite2D.new()
			spr.texture = bumper_tex
			b.add_child(spr)
			
			var shape = CollisionShape2D.new()
			var caps = CapsuleShape2D.new()
			caps.height = 120.0
			caps.radius = 30.0
			shape.shape = caps
			shape.rotation_degrees = 90
			b.add_child(shape)
			
			add_child(b)

	name_inp = get_node_or_null("EndScreen/Panel/NameInput")
	if name_inp:
		var btn_ok = Button.new()
		btn_ok.text = "OK"
		btn_ok.position = name_inp.position + Vector2(name_inp.size.x + 10, 0)
		btn_ok.size = Vector2(80, name_inp.size.y)
		var font_ok = load("res://assets/fonts/PressStart2P-Regular.ttf")
		if font_ok: btn_ok.add_theme_font_override("font", font_ok)
		btn_ok.add_theme_font_size_override("font_size", 18)
		btn_ok.pressed.connect(func(): _on_name_submitted(name_inp.text))
		btn_ok.name = "BtnOk"
		btn_ok.visible = false
		name_inp.get_parent().add_child(btn_ok)
		
	# Modales Temáticos (Estilo RPG / Arcade)
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = Color(0.08, 0.08, 0.12, 1)
	base_style.border_width_left = 6
	base_style.border_width_top = 6
	base_style.border_width_right = 6
	base_style.border_width_bottom = 6
	base_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	base_style.shadow_size = 16
	base_style.shadow_offset = Vector2(0, 8)
	
	if has_node("StartScreen/Panel"):
		var st_pnl = get_node("StartScreen/Panel")
		var st_style = base_style.duplicate()
		st_style.border_color = Color("#FFE55A") # Queso
		st_pnl.add_theme_stylebox_override("panel", st_style)
		st_pnl.position = Vector2(30, 180)
		st_pnl.size = Vector2(660, 720)
		get_node("StartScreen/Panel/Title").position = Vector2(20, 40)
		get_node("StartScreen/Panel/Title").size = Vector2(620, 140)
		get_node("StartScreen/Panel/Subtitle").position = Vector2(20, 160)
		get_node("StartScreen/Panel/Subtitle").size = Vector2(620, 120)
		get_node("StartScreen/Panel/BgOption").position = Vector2(150, 300)
		get_node("StartScreen/Panel/BgOption").size = Vector2(360, 50)
		get_node("StartScreen/Panel/StartButton").position = Vector2(60, 390)
		get_node("StartScreen/Panel/StartButton").size = Vector2(540, 86)
		get_node("StartScreen/Panel/StartButton").text = "MODO FACIL"
		if has_node("StartScreen/Panel/RankingsButton"):
			get_node("StartScreen/Panel/RankingsButton").position = Vector2(60, 600)
			get_node("StartScreen/Panel/RankingsButton").size = Vector2(540, 72)
		get_node("StartScreen/Panel/QuitButton").position = Vector2(60, 690)
		get_node("StartScreen/Panel/QuitButton").size = Vector2(540, 72)
		
		# Añadir botón de test para textos flotantes
		expert_button = Button.new()
		expert_button.name = "ExpertButton"
		expert_button.text = "MODO EXPERTO"
		expert_button.position = Vector2(60, 495)
		expert_button.size = Vector2(540, 86)
		expert_button.pressed.connect(_on_expert_pressed)
		expert_button.add_theme_stylebox_override("normal", start_button.get_theme_stylebox("normal"))
		expert_button.add_theme_stylebox_override("hover", start_button.get_theme_stylebox("hover"))
		expert_button.add_theme_stylebox_override("pressed", start_button.get_theme_stylebox("pressed"))
		expert_button.add_theme_stylebox_override("focus", start_button.get_theme_stylebox("focus"))
		expert_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var expert_font = load(PIXEL_FONT_PATH)
		if expert_font:
			expert_button.add_theme_font_override("font", expert_font)
		expert_button.add_theme_font_size_override("font_size", 24)
		st_pnl.add_child(expert_button)
		
	if has_node("PauseScreen/Panel"):
		var pa_pnl = get_node("PauseScreen/Panel")
		var pa_style = base_style.duplicate()
		pa_style.border_color = Color("#7BE07B") # Aceituna
		pa_pnl.add_theme_stylebox_override("panel", pa_style)
		pa_pnl.position = Vector2(40, 360)
		pa_pnl.size = Vector2(640, 400)
		get_node("PauseScreen/Panel/Title").position = Vector2(20, 60)
		get_node("PauseScreen/Panel/Title").size = Vector2(600, 100)
		get_node("PauseScreen/Panel/ResumeButton").position = Vector2(100, 180)
		get_node("PauseScreen/Panel/ResumeButton").size = Vector2(440, 80)
		get_node("PauseScreen/Panel/QuitButton").position = Vector2(100, 280)
		get_node("PauseScreen/Panel/QuitButton").size = Vector2(440, 70)
		
	if has_node("EndScreen/Panel"):
		var en_pnl = get_node("EndScreen/Panel")
		var en_style = base_style.duplicate()
		en_style.border_color = Color("#FF6D6D") # Pepperoni
		en_pnl.add_theme_stylebox_override("panel", en_style)
		en_pnl.position = Vector2(30, 100)
		en_pnl.size = Vector2(660, 920)
		get_node("EndScreen/Panel/Title").position = Vector2(20, 40)
		get_node("EndScreen/Panel/Title").size = Vector2(620, 100)
		get_node("EndScreen/Panel/ScoreFinalLabel").position = Vector2(20, 140)
		get_node("EndScreen/Panel/ScoreFinalLabel").size = Vector2(620, 560)
		
		get_node("EndScreen/Panel/RestartButton").position = Vector2(110, 720)
		get_node("EndScreen/Panel/RestartButton").size = Vector2(440, 80)
		get_node("EndScreen/Panel/QuitButton").position = Vector2(110, 810)
		get_node("EndScreen/Panel/QuitButton").size = Vector2(440, 70)
		
		get_node("EndScreen/Panel/NameInput").position = Vector2(70, 630)
		get_node("EndScreen/Panel/NameInput").size = Vector2(380, 70)
		get_node("EndScreen/Panel/NameInput").add_theme_font_size_override("font_size", 34)
		if has_node("BtnOk"):
			var b = get_node("BtnOk")
			b.position = Vector2(470, 630)
			b.size = Vector2(120, 70)

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
		
		$StartScreen/Panel/Title.add_theme_font_size_override("normal_font_size", 42)
		$StartScreen/Panel/Subtitle.add_theme_font_size_override("normal_font_size", 22)
		end_title.add_theme_font_size_override("normal_font_size", 54)
		start_button.add_theme_font_size_override("font_size", 24)
		if is_instance_valid(expert_button):
			expert_button.theme = t
			expert_button.add_theme_font_size_override("font_size", 24)
		quit_button_start.add_theme_font_size_override("font_size", 22)
		restart_button.add_theme_font_size_override("font_size", 28)
		quit_button_end.add_theme_font_size_override("font_size", 22)
		if has_node("StartScreen/Panel/RankingsButton"):
			get_node("StartScreen/Panel/RankingsButton").add_theme_font_size_override("font_size", 24)
		
		# Mutear botones fosforitos
		var green_btn_style = start_button.get_theme_stylebox("normal")
		if green_btn_style is StyleBoxFlat:
			green_btn_style.bg_color = Color(0.1, 0.6, 0.2, 1)
		var green_btn_hov = start_button.get_theme_stylebox("hover")
		if green_btn_hov is StyleBoxFlat:
			green_btn_hov.bg_color = Color(0.2, 0.7, 0.3, 1)
		
		$PauseScreen/Panel/Title.add_theme_font_size_override("normal_font_size", 54)
		pause_button.add_theme_font_size_override("font_size", 22)
		resume_button.add_theme_font_size_override("font_size", 30)
		quit_button_pause.add_theme_font_size_override("font_size", 24)

func _mode_label(mode: String) -> String:
	return "FACIL" if mode == MODE_EASY else "EXPERTO"

func _set_mode(mode: String) -> void:
	current_mode = mode
	_apply_rankings_from_mode()
	if spawner != null and spawner.has_method("configure_mode"):
		spawner.configure_mode(current_mode)
	if rankings_button != null:
		rankings_button.text = "RECORDS " + _mode_label(current_mode)

func _apply_rankings_from_mode() -> void:
	var mode_data: Dictionary = rankings_by_mode.get(current_mode, {"scores": [], "times": []})
	rankings_score = mode_data.get("scores", [])
	rankings_time = mode_data.get("times", [])

func _store_rankings_for_current_mode() -> void:
	rankings_by_mode[current_mode] = {
		"scores": rankings_score.duplicate(true),
		"times": rankings_time.duplicate(true),
	}

func _expert_level() -> int:
	return completed_pizzas if current_mode == MODE_EXPERT else 0

func _points_for_ingredient(kind: String) -> int:
	var current_amount: int = int(progress.get(kind, 0))
	var required_amount: int = int(requirements.get(kind, 0))
	var is_extra: bool = progress.has(kind) and current_amount >= required_amount
	if current_mode == MODE_EXPERT and kind != Globals.ING_CHEESE and is_extra:
		return EXPERT_EXTRA_COMPLETED_POINTS
	return 10 * combo

func _update_mode_button_states() -> void:
	var easy_active := current_mode == MODE_EASY
	if start_button != null:
		start_button.modulate = Color(1, 1, 1, 1) if easy_active else Color(0.82, 0.82, 0.82, 1)
	if is_instance_valid(expert_button):
		expert_button.modulate = Color(1, 1, 1, 1) if not easy_active else Color(0.82, 0.82, 0.82, 1)

func _apply_current_mode_to_run() -> void:
	_set_mode(current_mode)
	if spawner != null and spawner.has_method("set_difficulty_level"):
		spawner.set_difficulty_level(_expert_level())
	_update_mode_button_states()

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
		_pizza.set_deferred("freeze", true)
		_pizza.collision_layer = 0
		_pizza.collision_mask = 0
		_pizza.hide()
		_pizza.queue_free()
	
	# Crear nueva pizza con animación suave
	_pizza = pizza_scene.instantiate() as RigidBody2D
	_pizza.global_position = pizza_spawn.global_position
	_pizza.scale = Vector2(0.1, 0.1)  # Empezar pequeña
	_pizza.modulate = Color(1, 1, 1, 0)  # Empezar invisible
	
	if _pizza.has_signal("launched"):
		_pizza.launched.connect(_on_pizza_launched)
	if _pizza.has_signal("landed_idle"):
		_pizza.landed_idle.connect(_on_pizza_landed_idle)
	add_child(_pizza)
	
	# Animación suave de aparición
	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(_pizza, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spawn_tween.parallel().tween_property(_pizza, "modulate:a", 1.0, 0.3)
	
	if _pizza.has_method("force_idle"):
		_pizza.force_idle()
	if _pizza.has_method("reset_toppings"):
		_pizza.reset_toppings()
	if _pizza.has_method("set_controls_enabled"):
		_pizza.set_controls_enabled(_is_playing)

func _resume_after_pizza_completion() -> void:
	_spawn_pizza()
	_set_play_state(true)
	_sync_spawner()
	_refresh_hud()

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
		
		if is_instance_valid(sfx_sys): sfx_sys.play_rat()
		
		combo = 1
		lives -= 1
		_spawn_floating_text("-1 VIDA!", pos, Color(1, 0.2, 0.2))
		_show_feedback("!Mordisco de rata!", Color(1, 0.34, 0.34, 1))
		_refresh_hud() # Update heart visuals immediately
		
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
		if is_instance_valid(sfx_sys): sfx_sys.play_pickup()
		_spawn_floating_text("+1 VIDA!", pos, Color(1, 0.4, 0.8))
		_refresh_hud()
		if is_instance_valid(node_ref) and node_ref.has_method("queue_free"):
			node_ref.queue_free()
		return

	var pts := _points_for_ingredient(kind)
	score += pts
	_spawn_floating_text("+%d" % pts, pos, Color(0.4, 1, 0.4))
	
	var tw = create_tween()
	tw.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.05).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(score_label, "modulate", Color(0.2, 1.0, 0.8), 0.05)
	tw.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.15)
	tw.parallel().tween_property(score_label, "modulate", Color(1, 1, 1), 0.15)
	
	if combo > 1:
		if is_instance_valid(sfx_sys): sfx_sys.play_combo()
		_spawn_floating_text("Combo x%d!" % combo, pos + Vector2(0, 30), Color(1, 0.9, 0.2), true)
	else:
		if is_instance_valid(sfx_sys): sfx_sys.play_pickup()
	
	combo += 1

	if is_instance_valid(node_ref) and node_ref.has_method("queue_free"):
		node_ref.queue_free()

	if progress.has(kind):
		if progress[kind] < requirements.get(kind, 0):
			progress[kind] += 1
			_animate_stat(kind)
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
			if current_mode == MODE_EXPERT and kind != Globals.ING_CHEESE:
				_show_feedback("Ingrediente repetido: solo suma 1 punto", Color(0.9, 0.9, 0.9, 1))
			else:
				_show_feedback("Ese ingrediente ya esta completo", Color(0.9, 0.9, 0.9, 1))

	_sync_spawner()
	_sync_pizza_toppings()
	_refresh_hud()
	if _is_completed():
		completed_pizzas += 1
		if spawner != null and spawner.has_method("set_difficulty_level"):
			spawner.set_difficulty_level(_expert_level())
		score += 500
		_spawn_floating_text("+500 PIZZA!", pizza_spawn.global_position, Color(1, 1, 0))
		for k in progress.keys():
			progress[k] = 0
		_turn_active = false
		_turn_caught = false
		
		# Celebración de pizza completada
		await _celebrate_pizza_completion()
		for c in spawner.get_children():
			c.queue_free()
		
		call_deferred("_resume_after_pizza_completion")

func _trigger_hitstop(is_fatal: bool) -> void:
	Engine.time_scale = 0.05
	_camera_shake_time = 0.4
	
	# Usamos un timer ignorando el time_scale para que cuente tiempo real 0.4s
	await get_tree().create_timer(0.4, true, false, true).timeout
	Engine.time_scale = 1.0
	
	if is_fatal:
		await get_tree().create_timer(1.0, true, false, true).timeout
		_trigger_game_over_sequence()
	else:
		_refresh_hud()

func _trigger_game_over_sequence() -> void:
	_set_play_state(false)
	_game_over_invasion_active = true
		
	var go_label = Label.new()
	go_label.text = "GAME OVER"
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	go_label.position = Vector2(0, 500)
	go_label.size = Vector2(720, 200)
	go_label.add_theme_font_size_override("font_size", 60)
	go_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	var font = load("res://assets/fonts/PressStart2P-Regular.ttf")
	if font: go_label.add_theme_font_override("font", font)
	go_label.z_index = 200
	add_child(go_label)
	
	var tw = create_tween()
	tw.set_loops()
	tw.tween_property(go_label, "modulate:a", 0.0, 0.15)
	tw.tween_property(go_label, "modulate:a", 1.0, 0.15)
	
	await get_tree().create_timer(5.0, true, false, true).timeout
	if is_instance_valid(go_label): go_label.queue_free()
	_game_over_invasion_active = false
	_end_match(false)

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
	if spawner != null and spawner.has_method("configure_mode"):
		spawner.configure_mode(current_mode)
	if spawner != null and spawner.has_method("set_difficulty_level"):
		spawner.set_difficulty_level(_expert_level())
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
	score_label.text = "[center][font_size=18]⏳ %02d:%02d[/font_size]  |  🍕 %d  |  🌟 %d   [color=#FF9900]🔥x%d[/color][/center]" % [m, s, completed_pizzas, score, combo]

	for k in stats_boxes.keys():
		var box = stats_boxes[k]
		var c_hex = box["color"].to_html(false)
		box["node"].text = "[center][b][color=#" + c_hex + "]" + box["emoji"] + " %d/%d[/color][/b][/center]" % [progress[k], requirements[k]]


func _update_lives_container() -> void:
	for child in lives_container.get_children():
		child.queue_free()
		
	var to_draw = max(0, min(lives, 7))
	for i in range(to_draw):
		var t = TextureRect.new()
		t.texture = load("res://img/vida.png")
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(36, 36)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lives_container.add_child(t)
		
	if lives > 7:
		var lbl = Label.new()
		lbl.text = "+" + str(lives - 7)
		var font = load("res://assets/fonts/PressStart2P-Regular.ttf")
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.8))
		lives_container.add_child(lbl)
		lbl.position.y += 8

func _reset_round_data() -> void:
	lives = 3
	score = 0
	combo = 1
	round_time = 0.0
	completed_pizzas = 0
	_game_over_invasion_active = false
	_is_invulnerable = false
	_turn_active = false
	_turn_caught = false
	for k in progress.keys():
		progress[k] = 0
	for c in spawner.get_children():
		c.queue_free()
	feedback_label.text = ""
	feedback_timer.stop()
	_apply_current_mode_to_run()
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
	if rankings_screen: rankings_screen.visible = false
	_set_play_state(false)
	_reset_round_data()
	_spawn_pizza()
	_show_panel_animated(start_screen, $StartScreen/Panel)
	end_screen.visible = false
	_update_mode_button_states()
	if not is_instance_valid(phase_label):
		return
	phase_label.text = "[right]¡Pulsa Iniciar![/right]"

func _start_match() -> void:
	_reset_round_data()
	_spawn_pizza()
	start_screen.visible = false
	if rankings_screen:
		rankings_screen.visible = false
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
	var btn_ok = get_node_or_null("EndScreen/Panel/BtnOk") as Button
	if is_rec and name_inp:
		score_final_label.text += "\n[color=#FFD700]¡NUEVO RÉCORD! Escribe tu nombre:[/color][/center]"
		name_inp.visible = true
		if btn_ok: btn_ok.visible = true
		name_inp.text = ""
		name_inp.grab_focus()
		if btn_res: btn_res.visible = false
	else:
		score_final_label.text += "\n[color=#999]No has superado ningún récord.[/color]\n"
		var t = "\n[color=#FFE0B2][b]-- TOP 5 --[/b]\n"
		for r in rankings_score:
			var p = r.get("pizzas", 0)
			t += "%s : 🍕%d - %d pts (⏱%02d:%02d)\n" % [r["name"], p, r["score"], int(r["time"])/60, int(r["time"])%60]
		score_final_label.text += t + "[/color][/center]"
		if name_inp: name_inp.visible = false
		if btn_ok: btn_ok.visible = false
		if btn_res: btn_res.visible = true
		
	_show_panel_animated(end_screen, $EndScreen/Panel)

func _is_record() -> bool:
	if score > 0:
		if rankings_score.size() < 5: return true
		var worst_idx = rankings_score.size() - 1
		var worst_r = rankings_score[worst_idx]
		var wr_p = worst_r.get("pizzas", 0)
		if completed_pizzas > wr_p: return true
		if completed_pizzas == wr_p and score > worst_r["score"]: return true
	if round_time > 0.0:
		if rankings_time.size() < 5: return true
		var worst_time = rankings_time[rankings_time.size()-1]
		if round_time > worst_time["time"]: return true
	return false

func _on_name_submitted(new_text: String) -> void:
	var player_name = new_text.strip_edges()
	if player_name == "": return
	
	var entry = {"name": player_name, "score": score, "time": round_time, "pizzas": completed_pizzas}
	rankings_score.append(entry)
	rankings_score.sort_custom(func(a, b): 
		var pa = a.get("pizzas", 0)
		var pb = b.get("pizzas", 0)
		if pa != pb: return pa > pb
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
	var btn_ok = get_node_or_null("EndScreen/Panel/BtnOk")
	if name_inp: name_inp.visible = false
	if btn_ok: btn_ok.visible = false
	if btn_res: btn_res.visible = true
	
	var t = "[center][b]-- TOP 5 --[/b]\n"
	for r in rankings_score:
		var p = r.get("pizzas", 0)
		t += "%s : 🍕%d - %d pts (⏱%02d:%02d)\n" % [r["name"], p, r["score"], int(r["time"])/60, int(r["time"])%60]
	score_final_label.text = t + "[/center]"

func _on_start_pressed() -> void:
	_set_mode(MODE_EASY)
	_start_match()

func _on_expert_pressed() -> void:
	_set_mode(MODE_EXPERT)
	_start_match()

func _on_restart_pressed() -> void:
	_start_match()

func _on_rankings_pressed() -> void:
	_refresh_rankings_screen()
	start_screen.visible = false
	rankings_screen.visible = true
	_show_panel_animated(rankings_screen, $RankingsScreen/Panel)

func _on_close_rankings_pressed() -> void:
	rankings_screen.visible = false
	start_screen.visible = true
	_show_panel_animated(start_screen, $StartScreen/Panel)

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

func _on_test_button_pressed() -> void:
	return
	# Test de diferentes tipos de mensajes flotantes para verificar centrado
	var center_y = _get_game_area_rect().get_center().y
	
	_spawn_floating_text("+10 PUNTOS", Vector2(0, center_y), Color(0.4, 1, 0.4))
	
	await get_tree().create_timer(3.0, true, false, true).timeout
	_spawn_floating_text("Combo x2!", Vector2(0, center_y + 50), Color(1, 0.9, 0.2), true)
	
	await get_tree().create_timer(3.0, true, false, true).timeout
	_spawn_floating_text("+1 VIDA!", Vector2(0, center_y + 100), Color(1, 0.4, 0.8))
	
	await get_tree().create_timer(3.0, true, false, true).timeout
	_spawn_floating_text("¡PIZZA +1!", Vector2(0, center_y + 150), Color(1, 0.8, 0.2))
	
	await get_tree().create_timer(3.0, true, false, true).timeout
	# Test de celebración con texto permanente para captura
	_test_celebration_permanente()

func _test_celebration_permanente() -> void:
	# Celebración simple y funcional
	return

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

func _on_mute_toggled() -> void:
	is_muted = not is_muted
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, is_muted)
	if is_muted:
		mute_btn.text = "🔇"
	else:
		mute_btn.text = "🔊"

func _animate_stat(kind: String) -> void:
	if stats_boxes.has(kind):
		var node = stats_boxes[kind]["node"]
		var tw = create_tween()
		tw.set_trans(Tween.TRANS_ELASTIC)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", Vector2(1.8, 1.8), 0.1)
		tw.parallel().tween_property(node, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.6)
		tw.parallel().tween_property(node, "modulate", Color(1, 1, 1), 0.6)

func _show_panel_animated(screen: CanvasLayer, panel: Control) -> void:
	screen.visible = true
	var target_y = 280.0
	if screen == start_screen:
		target_y = 235.0
	elif screen == end_screen:
		target_y = 75.0
	elif screen == pause_screen:
		target_y = 280.0
		
	panel.position.y = -600.0
	var tw = create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "position:y", target_y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _get_game_area_rect() -> Rect2:
	return Rect2(Vector2.ZERO, GAME_AREA_SIZE)

func _ensure_fx_layer() -> CanvasLayer:
	var layer = get_node_or_null("FXLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "FXLayer"
		layer.layer = 50
		add_child(layer)
	return layer

func _spawn_floating_text(text: String, pos: Vector2, color: Color, is_combo: bool = false) -> void:
	var lbl = Label.new()
	lbl.text = text
	
	# Usar coordenadas relativas al viewport para que funcione en cualquier resolución
	var game_rect = _get_game_area_rect()
	
	# Calcular posición centrada relativa
	lbl.position = Vector2(game_rect.position.x, pos.y)
	lbl.size = Vector2(game_rect.size.x, 48)
	lbl.pivot_offset = lbl.size * 0.5
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate = color
	lbl.z_index = 100
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 6)
	var font = load(PIXEL_FONT_PATH)
	if font: lbl.add_theme_font_override("font", font)
	
	_ensure_fx_layer().add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	
	# Animación de escala especial para combos
	if is_combo:
		tw.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.9).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.1)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_delay(0.2)
	else:
		tw.tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.9).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_OUT).set_delay(0.2)
	
	tw.chain().tween_callback(lbl.queue_free)

func _celebrate_pizza_completion() -> void:
	_is_celebrating = true
	_is_playing = false
	
	# Pausar spawner durante celebración
	if spawner:
		spawner.set_process(false)
	
	# Crear sprite de pizza para celebración
	var pizza_sprite = Sprite2D.new()
	pizza_sprite.texture = load(CELEBRATION_PIZZA_TEXTURE)
	pizza_sprite.position = Vector2(360, 640)  # Centro fijo del área de juego
	pizza_sprite.scale = Vector2(0.1, 0.1)
	pizza_sprite.modulate = Color(1, 1, 1, 1)
	pizza_sprite.z_index = 200
	_ensure_fx_layer().add_child(pizza_sprite)
	
	# Crear texto "Pizza +1" simple y visible
	var pizza_text = Label.new()
	pizza_text.text = "¡PIZZA +1!"
	pizza_text.position = Vector2(0, 740)  # Debajo del sprite, centrado en el area de juego
	pizza_text.size = Vector2(GAME_AREA_SIZE.x, 60)
	pizza_text.pivot_offset = pizza_text.size * 0.5
	pizza_text.scale = Vector2(0.5, 0.5)  # Tamaño visible
	pizza_text.modulate = Color(1, 0.8, 0.2, 1)
	pizza_text.z_index = 201
	pizza_text.add_theme_font_size_override("font_size", 36)
	pizza_text.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	pizza_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	pizza_text.add_theme_constant_override("outline_size", 6)
	pizza_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pizza_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font = load(PIXEL_FONT_PATH)
	if font: pizza_text.add_theme_font_override("font", font)
	_ensure_fx_layer().add_child(pizza_text)
	
	# Animación simple (2 segundos)
	var tw = create_tween()
	tw.set_parallel(true)
	
	# Zoom de pizza con rotación
	tw.tween_property(pizza_sprite, "scale", Vector2(2.0, 2.0), 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pizza_sprite, "rotation", TAU * 2.0, 2.2).from(0.0)
	tw.tween_property(pizza_sprite, "modulate:a", 0.0, 0.8).set_delay(2.2)
	
	# Zoom de texto
	tw.tween_property(pizza_text, "scale", Vector2(0.8, 0.8), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pizza_text, "modulate:a", 0.0, 0.8).set_delay(2.2)
	
	# Esperar 2 segundos y limpiar
	await get_tree().create_timer(3.0, true, false, true).timeout
	
	pizza_sprite.queue_free()
	pizza_text.queue_free()
	
	# Restaurar estado del juego
	_is_celebrating = false
	if spawner:
		spawner.set_process(true)

func _process(delta: float) -> void:
	if _is_playing:
		round_time += delta
		var m = int(round_time) / 60
		var s = int(round_time) % 60
		score_label.text = "[right]⏳ %02d:%02d  |  🍕 %d  |  🌟 %d   [color=#FF9900]🔥x%d[/color][/right]" % [m, s, completed_pizzas, score, combo]
		
	if _game_over_invasion_active:
		if randf() < 0.35 and is_instance_valid(spawner) and spawner.get("rat_scene") != null:
			var rat = spawner.get("rat_scene").instantiate() as Node2D
			var w = get_viewport_rect().size.x
			var h = get_viewport_rect().size.y
			
			# Origen aleatorio en los bordes
			var edge_spawn = randi() % 4
			match edge_spawn:
				0: rat.global_position = Vector2(-40, randf_range(100, h - 100)) # Izquierda
				1: rat.global_position = Vector2(w + 40, randf_range(100, h - 100)) # Derecha
				2: rat.global_position = Vector2(randf_range(100, w - 100), -40) # Arriba
				3: rat.global_position = Vector2(randf_range(100, w - 100), h + 40) # Abajo
				
			add_child(rat)
			if rat.has_method("start_panic_mode"):
				rat.start_panic_mode()

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

func _refresh_rankings_screen() -> void:
	var sections: Array[String] = []
	for mode in [MODE_EASY, MODE_EXPERT]:
		var data: Dictionary = rankings_by_mode.get(mode, {"scores": [], "times": []})
		var lines: Array[String] = []
		lines.append("[b]%s[/b]" % _mode_label(mode))
		if data.get("scores", []).is_empty():
			lines.append("[color=#999]Sin records todavia[/color]")
		else:
			var idx := 1
			for entry in data.get("scores", []):
				lines.append("%d. %s  Pizza:%d  Pts:%d  Tiempo:%02d:%02d" % [
					idx,
					entry.get("name", "---"),
					entry.get("pizzas", 0),
					entry.get("score", 0),
					int(entry.get("time", 0.0)) / 60,
					int(entry.get("time", 0.0)) % 60
				])
				idx += 1
		sections.append("[center]%s[/center]" % "\n".join(lines))
	rankings_title.text = "[center][b]RECORDS FACIL Y EXPERTO[/b][/center]"
	rankings_text.text = "\n\n".join(sections)

func _load_rankings() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file_str = FileAccess.get_file_as_string(SAVE_PATH)
		var data = JSON.parse_string(file_str)
		if typeof(data) == TYPE_DICTIONARY:
			if data.has(MODE_EASY) or data.has(MODE_EXPERT):
				rankings_by_mode[MODE_EASY] = data.get(MODE_EASY, {"scores": [], "times": []})
				rankings_by_mode[MODE_EXPERT] = data.get(MODE_EXPERT, {"scores": [], "times": []})
			else:
				rankings_by_mode[MODE_EASY] = {
					"scores": data.get("scores", []),
					"times": data.get("times", []),
				}
				rankings_by_mode[MODE_EXPERT] = {"scores": [], "times": []}
	_apply_rankings_from_mode()

func _save_rankings() -> void:
	_store_rankings_for_current_mode()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(rankings_by_mode))

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
	elif index == 3:
		bg_checker.visible = false
		bg_image.visible = true
		bg_image.texture = load("res://img/fondo_clasico.png")
	elif index == 4:
		bg_checker.visible = false
		bg_image.visible = true
		bg_image.texture = load("res://img/fondo_restaurante.png")
	elif index == 5:
		bg_checker.visible = false
		bg_image.visible = true
		bg_image.texture = load("res://img/fondo_restaurante_2.png")
