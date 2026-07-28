extends Node
class_name ModeManager

enum GameMode {
	SOLO,
	TEAM,
	PVP
}

var current_mode: GameMode = GameMode.SOLO

# Faction selection for the local player
var player_faction: BaseCharacter.Faction = BaseCharacter.Faction.POLICE

func _ready():
	# Mode specific setup would go here
	pass

func start_game(mode: GameMode, faction: BaseCharacter.Faction):
	current_mode = mode
	player_faction = faction
	
	if current_mode == GameMode.SOLO:
		_setup_solo_mode()
	elif current_mode == GameMode.TEAM:
		_setup_team_mode()
	elif current_mode == GameMode.PVP:
		_setup_pvp_mode()
		
func _setup_solo_mode():
	# Spawn opposing faction AI
	print("Starting Solo Mode")
	pass
	
func _setup_team_mode():
	# Spawn player squad + enemy squad
	print("Starting Team Mode")
	pass
	
func _setup_pvp_mode():
	# Initialize ENet multiplayer lobby
	print("Starting PvP Mode")
	pass
