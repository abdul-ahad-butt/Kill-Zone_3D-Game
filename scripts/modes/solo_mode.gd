extends Node

class_name SoloMode

var ai_scene = preload("res://player.tscn") # Placeholder, should be an AI specific scene or the player scene configured for AI
var spawns_police = []
var spawns_terrorist = []

func _ready():
	# Gather spawn points from the world
	var world = get_node_or_null("/root/World")
	if world:
		var sp = world.get_node_or_null("Spawns/Police")
		if sp: spawns_police = sp.get_children()
		
		var st = world.get_node_or_null("Spawns/Terrorist")
		if st: spawns_terrorist = st.get_children()

func start_match(player_faction: int):
	# Spawn player
	var player = ai_scene.instantiate()
	player.name = str(multiplayer.get_unique_id())
	player.faction = player_faction
	
	var world = get_node_or_null("/root/World")
	if not world: return
	
	world.add_child(player)
	
	# Assign spawn point
	var p_spawns = spawns_police if player_faction == BaseCharacter.Faction.POLICE else spawns_terrorist
	if p_spawns.size() > 0:
		player.global_position = p_spawns[0].global_position
		
	# Spawn opposing AI
	var ai_faction = BaseCharacter.Faction.TERRORIST if player_faction == BaseCharacter.Faction.POLICE else BaseCharacter.Faction.POLICE
	var ai_spawns = spawns_terrorist if ai_faction == BaseCharacter.Faction.TERRORIST else spawns_police
	
	for i in range(min(5, ai_spawns.size())):
		var ai = ai_scene.instantiate()
		ai.name = "AI_" + str(i)
		ai.faction = ai_faction
		world.add_child(ai)
		ai.global_position = ai_spawns[i].global_position
		# Ideally set ai.is_ai = true or swap out the controller
		var player_controller = ai.get_node_or_null("PlayerController")
		if player_controller: player_controller.queue_free() # Remove player input
		if not ai.has_node("AIController"):
			var ai_ctrl = AIController.new()
			ai_ctrl.name = "AIController"
			ai.add_child(ai_ctrl)
