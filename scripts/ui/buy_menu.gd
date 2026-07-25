extends Control

var weapons = {
	"Assault Rifle": {"cost": 2700, "type": "primary", "resource": "res://resources/weapons/assault_rifle.tres"},
	"Sniper Rifle": {"cost": 4750, "type": "primary", "resource": "res://resources/weapons/sniper_rifle.tres"},
	"Frag Grenade": {"cost": 300, "type": "utility", "resource": "grenade"}
}

@onready var grid = $Panel/VBoxContainer/GridContainer
@onready var money_label = $Panel/VBoxContainer/MoneyLabel
@onready var close_btn = $Panel/VBoxContainer/CloseButton

func _ready():
	visible = false
	MatchManager.money_updated.connect(_on_money_updated)
	if close_btn:
		close_btn.pressed.connect(close_menu)
	
	if grid:
		for w_name in weapons.keys():
			var btn = Button.new()
			btn.text = w_name + " ($" + str(weapons[w_name]["cost"]) + ")"
			btn.pressed.connect(_on_buy_pressed.bind(w_name))
			grid.add_child(btn)

func open_menu():
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var my_id = multiplayer.get_unique_id()
	_update_money(MatchManager.player_money.get(my_id, 0))

func close_menu():
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_money_updated(id: int, amount: int):
	if id == multiplayer.get_unique_id():
		_update_money(amount)

func _update_money(amount: int):
	if money_label:
		money_label.text = "Cash: $" + str(amount)

func _on_buy_pressed(w_name: String):
	rpc_id(1, "request_buy", w_name)

@rpc("any_peer", "call_local", "reliable")
func request_buy(w_name: String):
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	
	if not weapons.has(w_name): return
	var w_data = weapons[w_name]
	var cost = w_data["cost"]
	
	var current_money = MatchManager.player_money.get(sender, 0)
	if current_money >= cost:
		MatchManager.add_money(sender, -cost)
		rpc_id(sender, "grant_item", w_name)

@rpc("authority", "call_local", "reliable")
func grant_item(w_name: String):
	var w_data = weapons[w_name]
	
	# Try to find the player node. Since this menu is under Camera3D, we go up two levels.
	var player = get_parent().get_parent() 
	
	if w_data["type"] == "primary":
		player.primary_weapon = load(w_data["resource"])
		player.equip_weapon(player.primary_weapon)
	elif w_data["type"] == "utility" and w_name == "Frag Grenade":
		player.grenades_count += 1
		
	# Play a buy sound
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_2d(am.reload_sound)
