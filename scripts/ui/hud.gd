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
	MatchManager.bomb_planted.connect(_on_bomb_planted)
	
	_setup_scoreboard()
	_setup_killfeed()
	_setup_hitmarker()
	_setup_bomb_alert()
	_setup_radar()
	_setup_crosshair()
	_setup_buy_menu()
	
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

# --- SCOREBOARD AND KILL FEED ---

var scoreboard_panel: PanelContainer
var scoreboard_list: VBoxContainer
var killfeed_box: VBoxContainer

func _setup_scoreboard():
	scoreboard_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	scoreboard_panel.add_theme_stylebox_override("panel", style)
	scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard_panel.custom_minimum_size = Vector2(400, 300)
	scoreboard_panel.hide()
	
	scoreboard_list = VBoxContainer.new()
	scoreboard_panel.add_child(scoreboard_list)
	add_child(scoreboard_panel)
	
	PlayerStats.stats_updated.connect(_update_scoreboard)

func _update_scoreboard():
	for child in scoreboard_list.get_children():
		child.queue_free()
		
	var header = Label.new()
	header.text = "SCOREBOARD"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_list.add_child(header)
	
	for peer_id in PlayerStats.stats:
		var p = PlayerStats.stats[peer_id]
		var team_name = "POLICE" if p.team == Team.TeamId.POLICE else "TERRORIST"
		var color = Color.AQUA if p.team == Team.TeamId.POLICE else Color.RED
		
		var lbl = Label.new()
		lbl.text = "%s [%s] - K: %d / D: %d" % [p.name, team_name, p.kills, p.deaths]
		lbl.add_theme_color_override("font_color", color)
		scoreboard_list.add_child(lbl)

func _process(_delta):
	if scoreboard_panel:
		if Input.is_key_pressed(KEY_TAB):
			if not scoreboard_panel.visible:
				_update_scoreboard()
				scoreboard_panel.show()
		else:
			scoreboard_panel.hide()
			
	_process_radar()
	_process_crosshair()
	_process_money()

func _input(event):
	if event.is_action_pressed("buy_menu") or (event is InputEventKey and event.keycode == KEY_B and event.pressed and not event.echo):
		if MatchManager.current_state == MatchManager.MatchState.ROUND_START and MatchManager.match_size == MatchManager.MatchSize.FIVE_V_FIVE:
			_toggle_buy_menu()

func _setup_killfeed():
	killfeed_box = VBoxContainer.new()
	killfeed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	killfeed_box.position = Vector2(-250, 60)
	killfeed_box.custom_minimum_size = Vector2(240, 300)
	add_child(killfeed_box)
	
	PlayerStats.player_killed.connect(_on_player_killed)
	
func _on_player_killed(killer: String, victim: String, weapon: String):
	var lbl = Label.new()
	lbl.text = "%s [%s] %s" % [killer, weapon, victim]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", 14)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0.5)
	var pc = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style)
	pc.add_child(lbl)
	
	killfeed_box.add_child(pc)
	
	var t = create_tween()
	t.tween_property(pc, "modulate:a", 0.0, 3.0).set_delay(3.0)
	t.tween_callback(pc.queue_free)

# --- HITMARKER ---
var hitmarker_texture: TextureRect
var _hitmarker_tween: Tween

func _setup_hitmarker():
	# Simple crosshair X by creating a custom texture or just using a label
	hitmarker_texture = TextureRect.new()
	var label = Label.new()
	label.text = "X"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	hitmarker_texture.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker_texture.add_child(label)
	# Center the label relative to the screen center
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-8, -14) # Offset slightly to center the X
	
	add_child(hitmarker_texture)
	hitmarker_texture.modulate.a = 0.0
	
func show_hitmarker():
	if _hitmarker_tween and _hitmarker_tween.is_running():
		_hitmarker_tween.kill()
		
	hitmarker_texture.modulate.a = 1.0
	hitmarker_texture.scale = Vector2(0.5, 0.5)
	
	_hitmarker_tween = create_tween()
	_hitmarker_tween.set_parallel(true)
	_hitmarker_tween.tween_property(hitmarker_texture, "scale", Vector2.ONE, 0.1)
	_hitmarker_tween.chain().tween_property(hitmarker_texture, "modulate:a", 0.0, 0.2)

# --- BOMB ALERT ---
var bomb_alert_label: Label
var _bomb_alert_tween: Tween

func _setup_bomb_alert():
	bomb_alert_label = Label.new()
	bomb_alert_label.text = "BOMB PLANTED!"
	bomb_alert_label.add_theme_font_size_override("font_size", 48)
	bomb_alert_label.add_theme_color_override("font_color", Color.RED)
	bomb_alert_label.add_theme_color_override("font_outline_color", Color.BLACK)
	bomb_alert_label.add_theme_constant_override("outline_size", 4)
	bomb_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bomb_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	bomb_alert_label.set_anchors_preset(Control.PRESET_CENTER)
	bomb_alert_label.position = Vector2(-200, -100) # Offset to center-topish
	
	add_child(bomb_alert_label)
	bomb_alert_label.hide()

func _on_bomb_planted():
	bomb_alert_label.show()
	bomb_alert_label.modulate.a = 1.0
	if _bomb_alert_tween and _bomb_alert_tween.is_running():
		_bomb_alert_tween.kill()
		
	_bomb_alert_tween = create_tween().set_loops(6)
	_bomb_alert_tween.tween_property(bomb_alert_label, "modulate:a", 0.2, 0.25)
	_bomb_alert_tween.tween_property(bomb_alert_label, "modulate:a", 1.0, 0.25)
	
	
	var hide_tween = create_tween()
	hide_tween.tween_interval(3.0)
	hide_tween.tween_callback(bomb_alert_label.hide)

# --- RADAR ---
var radar_container: SubViewportContainer
var radar_viewport: SubViewport
var radar_camera: Camera3D

func _setup_radar():
	radar_container = SubViewportContainer.new()
	radar_container.custom_minimum_size = Vector2(200, 200)
	radar_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	radar_container.position = Vector2(20, 20)
	
	radar_viewport = SubViewport.new()
	radar_viewport.size = Vector2i(200, 200)
	radar_viewport.transparent_bg = true
	radar_container.add_child(radar_viewport)
	
	radar_camera = Camera3D.new()
	radar_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	radar_camera.size = 60.0
	radar_camera.rotation_degrees.x = -90
	radar_camera.position.y = 50.0
	radar_viewport.add_child(radar_camera)
	
	add_child(radar_container)
	
	# Wait one frame to ensure get_viewport().world_3d is valid
	await get_tree().process_frame
	radar_viewport.world_3d = get_viewport().world_3d

func _process_radar():
	if is_instance_valid(radar_camera) and is_instance_valid(local_player):
		radar_camera.global_position.x = local_player.global_position.x
		radar_camera.global_position.z = local_player.global_position.z
		
func _process_crosshair():
	if is_instance_valid(local_player) and local_player.current_weapon:
		var spread = local_player.current_spread
		var spread_mult = 0.5 if local_player.is_crouching else 1.0
		var current_spread_px = 5.0 + (spread * spread_mult * 500.0)
		
		# Top
		crosshair_lines[0].size = Vector2(2, 12)
		crosshair_lines[0].position = Vector2(-1, -current_spread_px - 12)
		# Bottom
		crosshair_lines[1].size = Vector2(2, 12)
		crosshair_lines[1].position = Vector2(-1, current_spread_px)
		# Left
		crosshair_lines[2].size = Vector2(12, 2)
		crosshair_lines[2].position = Vector2(-current_spread_px - 12, -1)
		# Right
		crosshair_lines[3].size = Vector2(12, 2)
		crosshair_lines[3].position = Vector2(current_spread_px, -1)

# --- BUY MENU & MONEY ---
var buy_menu_panel: PanelContainer
var money_label: Label

func _setup_buy_menu():
	# Money Label (Bottom Left)
	money_label = Label.new()
	money_label.text = "$800"
	money_label.add_theme_font_size_override("font_size", 32)
	money_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) # Green
	money_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	money_label.position = Vector2(20, -60)
	add_child(money_label)
	
	# Buy Menu UI
	buy_menu_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.set_corner_radius_all(8)
	buy_menu_panel.add_theme_stylebox_override("panel", style)
	buy_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	buy_menu_panel.custom_minimum_size = Vector2(400, 300)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	buy_menu_panel.add_child(vbox)
	
	var header = Label.new()
	header.text = "BUY MENU"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	vbox.add_child(header)
	
	var weapons = [
		{"name": "SMG", "cost": 1500, "path": "res://resources/weapon_data/SMG.tres"},
		{"name": "Shotgun", "cost": 1200, "path": "res://resources/weapon_data/Shotgun.tres"},
		{"name": "Assault Rifle", "cost": 2700, "path": "res://resources/weapon_data/Rifle.tres"},
		{"name": "Sniper Rifle", "cost": 4750, "path": "res://resources/weapon_data/Sniper.tres"}
	]
	
	for w in weapons:
		var btn = Button.new()
		btn.text = "%s - $%d" % [w.name, w.cost]
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(func(): _on_buy_requested(w.cost, w.path))
		vbox.add_child(btn)
		
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_toggle_buy_menu)
	vbox.add_child(close_btn)
	
	add_child(buy_menu_panel)
	buy_menu_panel.hide()

func _toggle_buy_menu():
	if buy_menu_panel.visible:
		buy_menu_panel.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		buy_menu_panel.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_buy_requested(cost: int, path: String):
	if not multiplayer.is_server() and not MatchManager.is_offline_solo:
		rpc_id(1, "request_buy_server", multiplayer.get_unique_id(), cost, path)
	else:
		_process_buy(multiplayer.get_unique_id(), cost, path)

@rpc("any_peer", "call_remote", "reliable")
func request_buy_server(peer_id: int, cost: int, path: String):
	if multiplayer.is_server():
		_process_buy(peer_id, cost, path)

func _process_buy(peer_id: int, cost: int, path: String):
	if PlayerStats.request_buy(peer_id, cost, path):
		print("Player ", peer_id, " bought ", path)
		# Update player weapon immediately if they exist
		if get_tree().root.has_node("Level/PlayersContainer/" + str(peer_id)):
			var p = get_tree().root.get_node("Level/PlayersContainer/" + str(peer_id))
			if ResourceLoader.exists(path):
				p.primary_weapon = load(path)
				p.equip_weapon(p.primary_weapon)

func _process_money():
	if not multiplayer.has_multiplayer_peer(): return
	var id = multiplayer.get_unique_id()
	if PlayerStats.stats.has(id):
		var m = PlayerStats.stats[id].get("money", 800)
		money_label.text = "$%d" % m


# --- CROSSHAIR ---
var crosshair_lines: Array[ColorRect] = []

func _setup_crosshair():
	var center = Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	add_child(center)
	
	for i in range(4):
		var line = ColorRect.new()
		line.color = Color(0.0, 1.0, 0.0, 0.8) # Green crosshair
		center.add_child(line)
		crosshair_lines.append(line)
