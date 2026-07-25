extends CanvasLayer

@onready var round_timer_label = $VBoxContainer/RoundTimer
@onready var score_label = $VBoxContainer/Score
@onready var banner_label = $Banner
@onready var bomb_timer_label = $VBoxContainer/BombTimer

@onready var top_info_container = $TopInfo
@onready var match_timer_label = $TopInfo/MatchTimer
@onready var match_info_label = $TopInfo/MatchInfo

var _round_tween: Tween
var _bomb_tween: Tween
var _banner_tween: Tween

var _graphics_ui: CanvasLayer = null
var _settings_btn: Button = null

func _ready() -> void:
	MatchManager.round_timer_updated.connect(_on_round_timer_updated)
	MatchManager.bomb_timer_updated.connect(_on_bomb_timer_updated)
	MatchManager.total_timer_updated.connect(_on_total_timer_updated)
	MatchManager.score_updated.connect(_on_score_updated)
	MatchManager.round_state_changed.connect(_on_state_changed)
	MatchManager.round_ended.connect(_on_round_ended)
	
	var m_size_str = "Solo" if MatchManager.match_size == MatchManager.MatchSize.SOLO else "5v5"
	var active_sites = "A, B" if MatchManager.match_size == MatchManager.MatchSize.SOLO else "A, B, C, D"
	match_info_label.text = "Mode: %s | Active Sites: %s" % [m_size_str, active_sites]

	banner_label.hide()
	bomb_timer_label.hide()

	# Make sure pivot is centered for scaling
	round_timer_label.pivot_offset = round_timer_label.size / 2.0
	bomb_timer_label.pivot_offset = bomb_timer_label.size / 2.0
	banner_label.pivot_offset = banner_label.size / 2.0

	# ── Graphics settings gear button (top-right corner) ───────────────────
	_settings_btn = Button.new()
	_settings_btn.name = "GraphicsBtn"
	_settings_btn.text = "⚙"
	_settings_btn.tooltip_text = "Graphics Quality"
	_settings_btn.custom_minimum_size = Vector2(38, 38)
	_settings_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_settings_btn.position = Vector2(-50, 8)

	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.10, 0.13, 0.80)
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = Color(0.30, 0.32, 0.40)
	_settings_btn.add_theme_stylebox_override("normal", s)
	_settings_btn.add_theme_font_size_override("font_size", 18)
	_settings_btn.pressed.connect(_on_settings_btn_pressed)
	add_child(_settings_btn)

	# ── Graphics settings panel (hidden by default in-game) ────────────────
	_graphics_ui = load("res://scripts/ui/graphics_settings_ui.gd").new()
	_graphics_ui.name = "GraphicsSettingsUI"
	add_child(_graphics_ui)
	_graphics_ui.hide_panel()

func _on_settings_btn_pressed() -> void:
	if _graphics_ui:
		_graphics_ui.toggle_panel()

func _on_round_timer_updated(time_left: int) -> void:
	var m := time_left / 60
	var s := time_left % 60
	round_timer_label.text = "%02d:%02d" % [m, s]
	
	if time_left <= 10 and time_left > 0:
		round_timer_label.modulate = Color.RED
		_pulse_label(round_timer_label, "_round_tween")
	else:
		round_timer_label.modulate = Color.WHITE
		round_timer_label.scale = Vector2.ONE

func _on_total_timer_updated(time_left: int) -> void:
	var m := time_left / 60
	var s := time_left % 60
	match_timer_label.text = "Match Ends: %02d:%02d" % [m, s]

func _on_bomb_timer_updated(time_left: int) -> void:
	round_timer_label.hide()
	bomb_timer_label.show()

	var m := time_left / 60
	var s := time_left % 60
	bomb_timer_label.text = "💣 BOMB: %02d:%02d" % [m, s]

	if time_left <= 10 and time_left > 0:
		bomb_timer_label.modulate = Color.RED
		_pulse_label(bomb_timer_label, "_bomb_tween")
	else:
		bomb_timer_label.modulate = Color.ORANGE
		bomb_timer_label.scale = Vector2.ONE

func _pulse_label(label: Label, tween_name: String) -> void:
	var existing_tween = get(tween_name)
	if existing_tween and existing_tween.is_running():
		return

	var tween := create_tween()
	set(tween_name, tween)

	label.scale = Vector2(1.3, 1.3)
	tween.tween_property(label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_score_updated(police: int, terrorist: int) -> void:
	score_label.text = "POLICE %d - %d TERRORIST" % [police, terrorist]

func _on_state_changed(new_state) -> void:
	if new_state == MatchManager.MatchState.ROUND_START:
		_show_banner("ROUND STARTING...")
		bomb_timer_label.hide()
		round_timer_label.show()
	elif new_state == MatchManager.MatchState.LIVE:
		banner_label.hide()

func _on_round_ended(winner: int, reason: String) -> void:
	var winner_str := "POLICE" if winner == Team.TeamId.POLICE else "TERRORISTS"
	var color := Color.BLUE if winner == Team.TeamId.POLICE else Color.RED
	_show_banner("%s WIN\n%s" % [winner_str, reason], color)

func _show_banner(text: String, color: Color = Color.WHITE) -> void:
	banner_label.text = text
	banner_label.modulate = color
	banner_label.show()

	if _banner_tween and _banner_tween.is_running():
		_banner_tween.kill()

	_banner_tween = create_tween()
	banner_label.scale = Vector2(0.5, 0.5)
	banner_label.modulate.a = 0.0

	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(banner_label, "modulate:a", 1.0, 0.3)
