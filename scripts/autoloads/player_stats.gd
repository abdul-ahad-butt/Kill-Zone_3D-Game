extends Node

# Dictionary structure:
# {
#   peer_id: { "name": String, "team": int, "kills": int, "deaths": int }
# }
var stats: Dictionary = {}

signal stats_updated()
signal player_killed(killer_name: String, victim_name: String, weapon_name: String)

func register_player(peer_id: int, player_name: String, team: Team.TeamId, weapon_path: String = ""):
	if not multiplayer.is_server(): return
	
	if not stats.has(peer_id):
		stats[peer_id] = {
			"name": player_name,
			"team": team,
			"weapon_path": weapon_path,
			"kills": 0,
			"deaths": 0
		}
	else:
		stats[peer_id]["team"] = team
		if weapon_path != "":
			stats[peer_id]["weapon_path"] = weapon_path
		
	sync_all_stats()

func remove_player(peer_id: int):
	if not multiplayer.is_server(): return
	if stats.has(peer_id):
		stats.erase(peer_id)
		sync_all_stats()

func add_kill(killer_id: int):
	if not multiplayer.is_server(): return
	if stats.has(killer_id):
		stats[killer_id]["kills"] += 1
		sync_all_stats()

func add_death(victim_id: int):
	if not multiplayer.is_server(): return
	if stats.has(victim_id):
		stats[victim_id]["deaths"] += 1
		sync_all_stats()

func record_kill_event(killer_id: int, victim_id: int, weapon_name: String):
	if not multiplayer.is_server(): return
	
	add_kill(killer_id)
	add_death(victim_id)
	
	var k_name = stats[killer_id]["name"] if stats.has(killer_id) else "Unknown"
	var v_name = stats[victim_id]["name"] if stats.has(victim_id) else "Unknown"
	
	rpc("sync_kill_feed", k_name, v_name, weapon_name)

func sync_all_stats():
	if not multiplayer.is_server(): return
	rpc("receive_stats", stats)

@rpc("authority", "call_local", "reliable")
func receive_stats(new_stats: Dictionary):
	stats = new_stats
	emit_signal("stats_updated")

@rpc("authority", "call_local", "reliable")
func sync_kill_feed(killer: String, victim: String, weapon: String):
	emit_signal("player_killed", killer, victim, weapon)
