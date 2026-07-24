extends Area3D

var is_player_inside: bool = false
var planting_player = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.has_method("die") and body.has_bomb:
		is_player_inside = true
		planting_player = body
		print("Bomb carrier entered Bomb Site.")

func _on_body_exited(body):
	if body == planting_player:
		is_player_inside = false
		planting_player = null
		print("Bomb carrier left Bomb Site.")
