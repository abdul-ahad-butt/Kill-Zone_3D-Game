extends Node

class_name TeamMode

var ai_scene = preload("res://player.tscn")
var spawns_police = []
var spawns_terrorist = []

func _ready():
	var world = get_node_or_null("/root/World")
	if world:
		var sp = world.get_node_or_null("Spawns/Police")
		if sp: spawns_police = sp.get_children()
		
		var st = world.get_node_or_null("Spawns/Terrorist")
		if st: spawns_terrorist = st.get_children()

func start_match(player_faction: int):
	var player = ai_scene.instantiate()
	player.name = str(multiplayer.get_unique_id())
	player.faction = player_faction
	
	var world = get_node_or_null("/root/World")
	if not world: return
	
	world.add_child(player)
	
	var p_spawns = spawns_police if player_faction == BaseCharacter.Faction.POLICE else spawns_terrorist
	if p_spawns.size() > 0:
		player.global_position = p_spawns[0].global_position
		
	# Spawn teammates
	for i in range(1, min(5, p_spawns.size())):
		var ai = ai_scene.instantiate()
		ai.name = "Teammate_" + str(i)
		ai.faction = player_faction
		world.add_child(ai)
		ai.global_position = p_spawns[i].global_position
		_setup_ai(ai)

	# Spawn opposing AI
	var ai_faction = BaseCharacter.Faction.TERRORIST if player_faction == BaseCharacter.Faction.POLICE else BaseCharacter.Faction.POLICE
	var ai_spawns = spawns_terrorist if ai_faction == BaseCharacter.Faction.TERRORIST else spawns_police
	
	for i in range(min(5, ai_spawns.size())):
		var ai = ai_scene.instantiate()
		ai.name = "EnemyAI_" + str(i)
		ai.faction = ai_faction
		world.add_child(ai)
		ai.global_position = ai_spawns[i].global_position
		_setup_ai(ai)

func _setup_ai(ai_node):
	var player_controller = ai_node.get_node_or_null("PlayerController")
	if player_controller: player_controller.queue_free()
	if not ai_node.has_node("AIController"):
		var ai_ctrl = AIController.new()
		ai_ctrl.name = "AIController"
		ai_node.add_child(ai_ctrl)
