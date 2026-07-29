extends CharacterBody3D
class_name BaseCharacter

enum Faction {
	POLICE,
	TERRORIST,
	NONE
}

@export var faction: Faction = Faction.NONE

var team: int = 0:
	set(value):
		team = value
		# Map Team.TeamId to Faction
		if value == 1: # POLICE
			faction = Faction.POLICE
		elif value == 2: # TERRORIST
			faction = Faction.TERRORIST
		else:
			faction = Faction.NONE
@export var max_health: int = 100
var current_health: int = 100

signal health_changed(new_health, amount)
signal died(attacker_id, weapon_name)

func _ready():
	current_health = max_health

func take_damage(amount: int, attacker_faction: Faction, attacker_id: int = 1, weapon_name: String = "Weapon"):
	if current_health <= 0:
		return
		
	# Check friendly fire if needed
	if attacker_faction == faction and attacker_faction != Faction.NONE:
		return 
		
	current_health -= amount
	health_changed.emit(current_health, -amount)
	
	if current_health <= 0:
		die(attacker_id, weapon_name)

func die(attacker_id: int, weapon_name: String):
	died.emit(attacker_id, weapon_name)
	queue_free()
