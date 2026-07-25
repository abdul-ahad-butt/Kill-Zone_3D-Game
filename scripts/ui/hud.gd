extends CanvasLayer

@onready var round_timer_label = $VBoxContainer/RoundTimer
@onready var score_label = $VBoxContainer/Score
@onready var banner_label = $Banner
@onready var bomb_timer_label = $VBoxContainer/BombTimer

@onready var health_label = $PlayerStatus/HealthLabel
@onready var ammo_label = $PlayerStatus/AmmoLabel
@onready var interact_progress = $InteractProgress
@onready var hit_marker = $HitMarker
@onready var kill_feed = $KillFeed

@onready var crosshair = $Crosshair
@onready var ch_top = $Crosshair/Top
@onready var ch_bottom = $Crosshair/Bottom
@onready var ch_left = $Crosshair/Left
@onready var ch_right = $Crosshair/Right

var current_spread: float = 0.0

var _round_tween: Tween
var _bomb_tween: Tween
var _banner_tween: Tween

func _ready():
	add_to_group("hud")
	MatchManager.round_timer_updated.connect(_on_round_timer_updated)
	MatchManager.bomb_timer_updated.connect(_on_bomb_timer_updated)
	MatchManager.score_updated.connect(_on_score_updated)
	MatchManager.round_state_changed.connect(_on_state_changed)
	MatchManager.round_ended.connect(_on_round_ended)
	PlayerStats.player_killed.connect(_on_player_killed)
	MatchManager.bomb_planted.connect(func(): add_kill_feed("BOMB PLANTED"))
	MatchManager.bomb_defused.connect(func(): add_kill_feed("BOMB DEFUSED"))
	
	banner_label.hide()
	bomb_timer_label.hide()
	interact_progress.hide()
	
	# Make sure pivot is centered for scaling
	round_timer_label.pivot_offset = round_timer_label.size / 2.0
	bomb_timer_label.pivot_offset = bomb_timer_label.size / 2.0
	banner_label.pivot_offset = banner_label.size / 2.0
	
	_apply_hud_styling()
	_setup_mobile_ui()

func _process(_delta):
	var spread = clamp(current_spread, 2.0, 100.0)
	if ch_top: ch_top.position.y = -spread - ch_top.size.y
	if ch_bottom: ch_bottom.position.y = spread
	if ch_left: ch_left.position.x = -spread - ch_left.size.x
	if ch_right: ch_right.position.x = spread

func _apply_hud_styling():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.5)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 5
	panel_style.content_margin_bottom = 5
	
	score_label.add_theme_stylebox_override("normal", panel_style)
	
	var status_style = panel_style.duplicate()
	status_style.content_margin_top = 10
	status_style.content_margin_bottom = 10
	health_label.add_theme_stylebox_override("normal", status_style)
	ammo_label.add_theme_stylebox_override("normal", status_style)

func update_health(health: int):
	if health_label: health_label.text = "HP: " + str(health)

func update_ammo(current: int, reserve: int):
	if ammo_label: ammo_label.text = str(current) + " / " + (str(reserve) if reserve >= 0 else "∞")

func show_interact_progress(progress: float, text: String):
	if interact_progress:
		interact_progress.show()
		interact_progress.value = progress * 100
		var lbl = interact_progress.get_node_or_null("Label")
		if lbl: lbl.text = text

func hide_interact_progress():
	if interact_progress: interact_progress.hide()

func show_hit_marker():
	if hit_marker:
		hit_marker.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(hit_marker, "modulate:a", 0.0, 0.3)

func add_kill_feed(text: String):
	if kill_feed:
		var lbl = Label.new()
		lbl.text = text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.add_theme_font_size_override("font_size", 18)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0,0,0,0.4)
		style.content_margin_left = 5
		style.content_margin_right = 5
		lbl.add_theme_stylebox_override("normal", style)
		kill_feed.add_child(lbl)
		var tween = create_tween()
		tween.tween_interval(5.0)
		tween.tween_property(lbl, "modulate:a", 0.0, 1.0)
		tween.tween_callback(lbl.queue_free)

func _on_player_killed(killer: String, victim: String, weapon: String):
	add_kill_feed(killer + " [" + weapon + "] " + victim)

func show_scope(show: bool):
	var scope = get_node_or_null("ScopeOverlay")
	if scope:
		scope.visible = show

func _setup_mobile_ui():
	if not DisplayServer.is_touchscreen_available() and not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"):
		return
		
	var joystick_scene = load("res://scenes/ui/virtual_joystick.tscn")
	if joystick_scene:
		add_child(joystick_scene.instantiate())
		
	var minimap_scene = load("res://scenes/ui/minimap.tscn")
	if minimap_scene:
		add_child(minimap_scene.instantiate())
		
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0.4)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
		
	var jump_btn = Button.new()
	jump_btn.text = "JUMP"
	jump_btn.custom_minimum_size = Vector2(100, 100)
	jump_btn.position = Vector2(get_viewport().size.x - 120, get_viewport().size.y - 300)
	jump_btn.add_theme_stylebox_override("normal", btn_style)
	jump_btn.button_down.connect(func(): Input.action_press("jump"))
	jump_btn.button_up.connect(func(): Input.action_release("jump"))
	add_child(jump_btn)
	
	var reload_btn = Button.new()
	reload_btn.text = "RELOAD"
	reload_btn.custom_minimum_size = Vector2(100, 100)
	reload_btn.position = Vector2(get_viewport().size.x - 240, get_viewport().size.y - 120)
	reload_btn.add_theme_stylebox_override("normal", btn_style)
	reload_btn.button_down.connect(func(): Input.action_press("reload"))
	reload_btn.button_up.connect(func(): Input.action_release("reload"))
	add_child(reload_btn)
	
	var interact_btn = Button.new()
	interact_btn.text = "PLANT/DEFUSE"
	interact_btn.custom_minimum_size = Vector2(120, 80)
	interact_btn.position = Vector2(get_viewport().size.x - 380, get_viewport().size.y - 100)
	interact_btn.add_theme_stylebox_override("normal", btn_style)
	interact_btn.button_down.connect(func(): Input.action_press("interact"))
	interact_btn.button_up.connect(func(): Input.action_release("interact"))
	add_child(interact_btn)

func _on_round_timer_updated(time_left: int):
	var m = time_left / 60
	var s = time_left % 60
	round_timer_label.text = "%02d:%02d" % [m, s]
	
	if time_left <= 10 and time_left > 0:
		round_timer_label.modulate = Color.RED
		_pulse_label(round_timer_label, "_round_tween")
	else:
		round_timer_label.modulate = Color.WHITE
		round_timer_label.scale = Vector2.ONE

func _on_bomb_timer_updated(time_left: int):
	round_timer_label.hide()
	bomb_timer_label.show()
	
	var m = time_left / 60
	var s = time_left % 60
	bomb_timer_label.text = "💣 BOMB: %02d:%02d" % [m, s]
	
	if time_left <= 10 and time_left > 0:
		bomb_timer_label.modulate = Color.RED
		_pulse_label(bomb_timer_label, "_bomb_tween")
	else:
		bomb_timer_label.modulate = Color.ORANGE
		bomb_timer_label.scale = Vector2.ONE

func _pulse_label(label: Label, tween_name: String):
	var existing_tween = get(tween_name)
	if existing_tween and existing_tween.is_running():
		return
		
	var tween = create_tween()
	set(tween_name, tween)
	
	label.scale = Vector2(1.3, 1.3)
	tween.tween_property(label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_score_updated(police: int, terrorist: int):
	score_label.text = "POLICE %d - %d TERRORIST" % [police, terrorist]

func _on_state_changed(new_state):
	if new_state == MatchManager.MatchState.ROUND_START:
		_show_banner("ROUND STARTING...")
		bomb_timer_label.hide()
		round_timer_label.show()
	elif new_state == MatchManager.MatchState.LIVE:
		banner_label.hide()

func _on_round_ended(winner: int, reason: String):
	var winner_str = "POLICE" if winner == Team.TeamId.POLICE else "TERRORISTS"
	var color = Color.BLUE if winner == Team.TeamId.POLICE else Color.RED
	_show_banner("%s WIN\n%s" % [winner_str, reason], color)

func _show_banner(text: String, color: Color = Color.WHITE):
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
