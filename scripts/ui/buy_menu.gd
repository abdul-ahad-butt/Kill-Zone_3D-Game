extends Control

var items = {
	"Pistol": {"cost": 200, "type": "secondary", "resource": "res://resources/weapons/pistol.tres"},
	"AK-47": {"cost": 2700, "type": "primary", "resource": "res://resources/weapons/ak47.tres"},
	"M4A1": {"cost": 3100, "type": "primary", "resource": "res://resources/weapons/m4a1.tres"},
	"AWP": {"cost": 4750, "type": "primary", "resource": "res://resources/weapons/awp.tres"},
	"Kevlar + Helmet": {"cost": 1000, "type": "gear", "id": "kevlar"},
	"Defuse Kit": {"cost": 400, "type": "gear", "id": "defuse_kit"},
	"Frag Grenade": {"cost": 300, "type": "utility", "id": "grenade"}
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
		for item_name in items.keys():
			var btn = Button.new()
			btn.text = item_name + " ($" + str(items[item_name]["cost"]) + ")"
			btn.pressed.connect(_on_buy_pressed.bind(item_name))
			grid.add_child(btn)

func open_menu():
	if MatchManager.current_state != MatchManager.MatchState.ROUND_START and MatchManager.current_state != MatchManager.MatchState.WARMUP:
		return # Cannot buy outside buy time
		
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

func _on_buy_pressed(item_name: String):
	rpc_id(1, "request_buy", item_name)

@rpc("any_peer", "call_local", "reliable")
func request_buy(item_name: String):
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	
	if not items.has(item_name): return
	var item_data = items[item_name]
	var cost = item_data["cost"]
	
	var current_money = MatchManager.player_money.get(sender, 0)
	if current_money >= cost:
		MatchManager.add_money(sender, -cost)
		rpc_id(sender, "grant_item", item_name)

@rpc("authority", "call_local", "reliable")
func grant_item(item_name: String):
	var item_data = items[item_name]
	var player = get_parent().get_parent() 
	
	if item_data["type"] == "primary":
		var wpn = load(item_data["resource"])
		if wpn:
			player.primary_weapon = wpn
			player.equip_weapon(wpn)
	elif item_data["type"] == "secondary":
		var wpn = load(item_data["resource"])
		if wpn:
			player.secondary_weapon = wpn
			player.equip_weapon(wpn)
	elif item_data["type"] == "utility" and item_data["id"] == "grenade":
		player.grenades_count += 1
	elif item_data["type"] == "gear" and item_data["id"] == "kevlar":
		player.armor = 100
	elif item_data["type"] == "gear" and item_data["id"] == "defuse_kit":
		player.has_defuse_kit = true
		
	var am = get_node_or_null("/root/AudioManager")
	if am: am.play_2d(am.reload_sound)
