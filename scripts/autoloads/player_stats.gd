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
			"money": MatchManager.starting_money,
			"has_armor": false,
			"has_defuse_kit": false,
			"grenade_count": 1,
			"smoke_count": 0,
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
		add_money(killer_id, 300)
		sync_all_stats()

func add_death(victim_id: int):
	if not multiplayer.is_server(): return
	if stats.has(victim_id):
		stats[victim_id]["deaths"] += 1
		sync_all_stats()

func add_money(peer_id: int, amount: int):
	if not multiplayer.is_server(): return
	if stats.has(peer_id):
		stats[peer_id]["money"] = clampi(stats[peer_id]["money"] + amount, 0, 16000)
		sync_all_stats()

func request_buy(peer_id: int, cost: int, item_path: String) -> bool:
	if not multiplayer.is_server(): return false
	if stats.has(peer_id):
		if stats[peer_id]["money"] >= cost:
			if item_path == "item_armor":
				if stats[peer_id].get("has_armor", false): return false
				stats[peer_id]["has_armor"] = true
			elif item_path == "item_defuse_kit":
				if stats[peer_id].get("has_defuse_kit", false): return false
				if stats[peer_id]["team"] != Team.TeamId.POLICE: return false
				stats[peer_id]["has_defuse_kit"] = true
			elif item_path == "item_frag":
				if stats[peer_id].get("grenade_count", 0) >= 2: return false
				stats[peer_id]["grenade_count"] = stats[peer_id].get("grenade_count", 0) + 1
			elif item_path == "item_smoke":
				if stats[peer_id].get("smoke_count", 0) >= 1: return false
				stats[peer_id]["smoke_count"] = stats[peer_id].get("smoke_count", 0) + 1
			else:
				stats[peer_id]["weapon_path"] = item_path
				
			stats[peer_id]["money"] -= cost
			sync_all_stats()
			return true
	return false

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

func reset_grenades_for_round():
	if not multiplayer.is_server(): return
	for id in stats.keys():
		stats[id]["grenade_count"] = 1
		stats[id]["smoke_count"] = 0
	sync_all_stats()

@rpc("authority", "call_local", "reliable")
func sync_kill_feed(killer: String, victim: String, weapon: String):
	emit_signal("player_killed", killer, victim, weapon)
