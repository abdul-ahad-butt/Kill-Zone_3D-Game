extends Node

enum MatchState {
	WARMUP,
	ROUND_START,
	LIVE,
	ROUND_END,
	MATCH_END
}

var current_state: MatchState = MatchState.WARMUP

var score_police: int = 0
var score_terrorist: int = 0
var current_round: int = 1
var max_rounds: int = 9
var is_bomb_planted: bool = false

enum MatchSize {
	SOLO,
	FIVE_V_FIVE
}

var is_offline_solo: bool = false
var match_size: MatchSize = MatchSize.SOLO
var solo_faction: Team.TeamId = Team.TeamId.NONE
var solo_primary_weapon: Resource

var bot_difficulty: int = 1 # 0: Easy, 1: Normal, 2: Hard
var starting_money: int = 800

var freeze_time: float = 5.0
var round_time: float = 120.0
var bomb_time: float = 40.0
var round_end_delay: float = 5.0

var match_timer_total: float = 600.0 # 10 minutes

var _timer: float = 0.0

var police_players: Array = []
var terrorist_players: Array = []

signal round_state_changed(new_state: MatchState)
signal round_timer_updated(time_left: int)
signal bomb_timer_updated(time_left: int)
signal total_timer_updated(time_left: int)
signal score_updated(police: int, terrorist: int)
signal round_ended(winning_team: int, reason: String)
signal match_ended(winning_team: int)
signal bomb_planted()
signal bomb_defused()

func start_match() -> void:
	if not multiplayer.is_server():
		return
	score_police = 0
	score_terrorist = 0
	current_round = 1
	match_timer_total = 600.0
	_change_state(MatchState.ROUND_START)

func _process(delta: float) -> void:
	if is_offline_solo:
		_process_timers(delta)
		return
		
	# Only the server runs the match timer logic
	if not multiplayer.is_server():
		return
		
	_process_timers(delta)
	
func _process_timers(delta: float) -> void:
	if current_state != MatchState.WARMUP and current_state != MatchState.MATCH_END:
		match_timer_total -= delta
		if not is_offline_solo:
			rpc("sync_total_timer", int(ceil(match_timer_total)))
		else:
			emit_signal("total_timer_updated", int(ceil(match_timer_total)))
			
		if match_timer_total <= 0:
			match_timer_total = 0
			var winner = Team.TeamId.POLICE if score_police > score_terrorist else (Team.TeamId.TERRORIST if score_terrorist > score_police else Team.TeamId.NONE)
			if not is_offline_solo:
				rpc("sync_match_ended", winner)
			else:
				emit_signal("match_ended", winner)
			_change_state(MatchState.MATCH_END)
			return
			
	if current_state == MatchState.ROUND_START:
		_timer -= delta
		rpc("sync_timers", int(ceil(_timer)), -1)
		if _timer <= 0:
			_change_state(MatchState.LIVE)
			
	elif current_state == MatchState.LIVE:
		if is_bomb_planted:
			_timer -= delta
			rpc("sync_timers", -1, int(ceil(_timer)))
			if _timer <= 0:
				end_round(Team.TeamId.TERRORIST, "Bomb Exploded")
		else:
			_timer -= delta
			rpc("sync_timers", int(ceil(_timer)), -1)
			if _timer <= 0:
				end_round(Team.TeamId.POLICE, "Time Expired")
				
	elif current_state == MatchState.ROUND_END:
		_timer -= delta
		if _timer <= 0:
			if score_police >= ceili(max_rounds / 2.0) or score_terrorist >= ceili(max_rounds / 2.0):
				_change_state(MatchState.MATCH_END)
			else:
				if current_round == ceili(max_rounds / 2.0):
					_swap_sides()
				current_round += 1
				_change_state(MatchState.ROUND_START)

func _swap_sides() -> void:
	if not multiplayer.is_server(): return
	var temp_score = score_police
	score_police = score_terrorist
	score_terrorist = temp_score
	
	var temp_players = police_players
	police_players = terrorist_players
	terrorist_players = temp_players
	
	# Update team assignments in PlayerStats and tell players to swap
	for id in police_players:
		PlayerStats.register_player(id, PlayerStats.stats[id]["name"], Team.TeamId.POLICE)
	for id in terrorist_players:
		PlayerStats.register_player(id, PlayerStats.stats[id]["name"], Team.TeamId.TERRORIST)
	
	rpc("sync_state", current_state, score_police, score_terrorist, is_bomb_planted)
	print("Halftime! Sides swapped.")

func get_auto_balanced_team(peer_id: int) -> Team.TeamId:
	if not multiplayer.is_server(): return Team.TeamId.NONE
	
	if police_players.size() < 5 and police_players.size() <= terrorist_players.size():
		police_players.append(peer_id)
		return Team.TeamId.POLICE
	elif terrorist_players.size() < 5:
		terrorist_players.append(peer_id)
		return Team.TeamId.TERRORIST
	
	return Team.TeamId.NONE

func remove_player(peer_id: int):
	police_players.erase(peer_id)
	terrorist_players.erase(peer_id)

func _change_state(new_state: MatchState) -> void:
	if not multiplayer.is_server(): return
	
	current_state = new_state
	
	if current_state == MatchState.ROUND_START:
		_timer = freeze_time
		is_bomb_planted = false
		if active_bomb_model and is_instance_valid(active_bomb_model):
			if active_bomb_model.get_parent():
				active_bomb_model.get_parent().remove_child(active_bomb_model)
		
	elif current_state == MatchState.LIVE:
		_timer = round_time
		
	rpc("sync_state", current_state, score_police, score_terrorist, is_bomb_planted)
	
	if current_state == MatchState.MATCH_END:
		var winner = Team.TeamId.POLICE if score_police > score_terrorist else Team.TeamId.TERRORIST
		rpc("sync_match_ended", winner)

@rpc("authority", "call_local", "reliable")
func sync_state(state: MatchState, police_score: int, terrorist_score: int, bomb_planted: bool):
	current_state = state
	score_police = police_score
	score_terrorist = terrorist_score
	is_bomb_planted = bomb_planted
	
	emit_signal("score_updated", score_police, score_terrorist)
	emit_signal("round_state_changed", current_state)

@rpc("authority", "call_local", "unreliable")
func sync_timers(round_t: int, bomb_t: int):
	if round_t >= 0:
		emit_signal("round_timer_updated", round_t)
	if bomb_t >= 0:
		emit_signal("bomb_timer_updated", bomb_t)

@rpc("authority", "call_local", "unreliable")
func sync_total_timer(total_t: int):
	emit_signal("total_timer_updated", total_t)

@rpc("authority", "call_local", "reliable")
func sync_round_ended(winner: int, reason: String):
	emit_signal("round_ended", winner, reason)

@rpc("authority", "call_local", "reliable")
func sync_match_ended(winner: int):
	emit_signal("match_ended", winner)
	get_tree().change_scene_to_file("res://main_menu.tscn")
	
var active_bomb_model: MeshInstance3D

func plant_bomb(site_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_offline_solo and not multiplayer.is_server(): return
	if current_state != MatchState.LIVE or is_bomb_planted: return
	
	is_bomb_planted = true
	_timer = bomb_time
	rpc("sync_bomb_event", true, site_pos)

func defuse_bomb() -> void:
	if not multiplayer.is_server(): return
	if current_state != MatchState.LIVE or not is_bomb_planted: return
	
	rpc("sync_bomb_event", false, Vector3.ZERO)
	end_round(Team.TeamId.POLICE, "Bomb Defused")

@rpc("authority", "call_local", "reliable")
func sync_bomb_event(is_plant: bool, site_pos: Vector3):
	if is_plant:
		emit_signal("bomb_planted")
		
		# Spawn physical bomb
		if not active_bomb_model:
			active_bomb_model = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			mesh.size = Vector3(0.4, 0.2, 0.3)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color.RED
			mat.emission_enabled = true
			mat.emission = Color.RED
			mat.emission_energy_multiplier = 2.0
			mesh.surface_set_material(0, mat)
			active_bomb_model.mesh = mesh
			
			# Blinking tween
			var t = active_bomb_model.create_tween().set_loops()
			t.tween_property(mat, "emission_energy_multiplier", 0.0, 0.5)
			t.tween_property(mat, "emission_energy_multiplier", 2.0, 0.5)
			
		get_tree().root.add_child(active_bomb_model)
		active_bomb_model.global_position = site_pos
	else:
		emit_signal("bomb_defused")
		if active_bomb_model and is_instance_valid(active_bomb_model):
			active_bomb_model.get_parent().remove_child(active_bomb_model)

func end_round(winner: Team.TeamId, reason: String) -> void:
	if not multiplayer.is_server() or current_state != MatchState.LIVE: return
		
	if winner == Team.TeamId.POLICE:
		score_police += 1
		_award_money(police_players, 3250)
		_award_money(terrorist_players, 1400)
	elif winner == Team.TeamId.TERRORIST:
		score_terrorist += 1
		_award_money(terrorist_players, 3250)
		_award_money(police_players, 1400)
	else:
		_award_money(police_players, 1400)
		_award_money(terrorist_players, 1400)
		
	rpc("sync_round_ended", winner, reason)
	
	_timer = round_end_delay
	_change_state(MatchState.ROUND_END)

func _award_money(players: Array, amount: int):
	for id in players:
		PlayerStats.add_money(id, amount)

func check_elimination(alive_police: int, alive_terrorists: int) -> void:
	if not multiplayer.is_server() or current_state != MatchState.LIVE: return
		
	if alive_police == 0 and alive_terrorists == 0:
		end_round(Team.TeamId.POLICE, "Draw - Time Expired")
	elif alive_police == 0:
		end_round(Team.TeamId.TERRORIST, "Police Eliminated")
	elif alive_terrorists == 0 and not is_bomb_planted:
		end_round(Team.TeamId.POLICE, "Terrorists Eliminated")
