extends CanvasLayer

@onready var round_timer_label = $VBoxContainer/RoundTimer
@onready var score_label = $VBoxContainer/Score
@onready var banner_label = $Banner
@onready var bomb_timer_label = $VBoxContainer/BombTimer

func _ready():
	MatchManager.round_timer_updated.connect(_on_round_timer_updated)
	MatchManager.bomb_timer_updated.connect(_on_bomb_timer_updated)
	MatchManager.score_updated.connect(_on_score_updated)
	MatchManager.round_state_changed.connect(_on_state_changed)
	MatchManager.round_ended.connect(_on_round_ended)
	
	banner_label.hide()
	bomb_timer_label.hide()

func _on_round_timer_updated(time_left: int):
	var m = time_left / 60
	var s = time_left % 60
	round_timer_label.text = "%02d:%02d" % [m, s]

func _on_bomb_timer_updated(time_left: int):
	bomb_timer_label.show()
	var m = time_left / 60
	var s = time_left % 60
	bomb_timer_label.text = "BOMB: %02d:%02d" % [m, s]
	bomb_timer_label.modulate = Color.RED

func _on_score_updated(police: int, terrorist: int):
	score_label.text = "POLICE %d - %d TERRORIST" % [police, terrorist]

func _on_state_changed(new_state):
	if new_state == MatchManager.MatchState.ROUND_START:
		banner_label.show()
		banner_label.text = "ROUND STARTING..."
		bomb_timer_label.hide()
	elif new_state == MatchManager.MatchState.LIVE:
		banner_label.hide()

func _on_round_ended(winner: int, reason: String):
	banner_label.show()
	var winner_str = "POLICE" if winner == Team.TeamId.POLICE else "TERRORISTS"
	banner_label.text = "%s WIN\n%s" % [winner_str, reason]
