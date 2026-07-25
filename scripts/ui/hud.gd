extends CanvasLayer

@onready var round_timer_label = $VBoxContainer/RoundTimer
@onready var score_label = $VBoxContainer/Score
@onready var banner_label = $Banner
@onready var bomb_timer_label = $VBoxContainer/BombTimer

var _round_tween: Tween
var _bomb_tween: Tween
var _banner_tween: Tween

func _ready():
	MatchManager.round_timer_updated.connect(_on_round_timer_updated)
	MatchManager.bomb_timer_updated.connect(_on_bomb_timer_updated)
	MatchManager.score_updated.connect(_on_score_updated)
	MatchManager.round_state_changed.connect(_on_state_changed)
	MatchManager.round_ended.connect(_on_round_ended)
	
	banner_label.hide()
	bomb_timer_label.hide()
	
	# Make sure pivot is centered for scaling
	round_timer_label.pivot_offset = round_timer_label.size / 2.0
	bomb_timer_label.pivot_offset = bomb_timer_label.size / 2.0
	banner_label.pivot_offset = banner_label.size / 2.0

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
