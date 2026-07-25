extends CanvasLayer

@onready var mode_select = $ModeSelect
@onready var faction_select = $FactionSelect
@onready var start_btn = $StartButton

var selected_mode: MatchManager.MatchSize = MatchManager.MatchSize.SOLO
var selected_faction: Team.TeamId = Team.TeamId.NONE

func _ready():
	mode_select.show()
	faction_select.hide()
	start_btn.hide()
	
	$ModeSelect/SoloBtn.pressed.connect(func(): _on_mode_selected(MatchManager.MatchSize.SOLO))
	$ModeSelect/TeamBtn.pressed.connect(func(): _on_mode_selected(MatchManager.MatchSize.FIVE_V_FIVE))
	
	$FactionSelect/PoliceBtn.pressed.connect(func(): _on_faction_selected(Team.TeamId.POLICE))
	$FactionSelect/TerroristBtn.pressed.connect(func(): _on_faction_selected(Team.TeamId.TERRORIST))
	
	start_btn.pressed.connect(_on_start_pressed)
	
	$SettingsBtn.pressed.connect(func(): $SettingsPanel.show())
	$SettingsPanel/VBox/CloseBtn.pressed.connect(func(): $SettingsPanel.hide())
	
	$SettingsPanel/VBox/TimeSlider.value_changed.connect(_on_time_changed)
	$SettingsPanel/VBox/MoneySlider.value_changed.connect(_on_money_changed)
	$SettingsPanel/VBox/DiffOption.item_selected.connect(_on_diff_selected)
	
	_on_time_changed($SettingsPanel/VBox/TimeSlider.value)
	_on_money_changed($SettingsPanel/VBox/MoneySlider.value)
	_on_diff_selected($SettingsPanel/VBox/DiffOption.selected)

func _on_time_changed(val: float):
	MatchManager.round_time = val
	$SettingsPanel/VBox/TimeLabel.text = "Round Time: " + str(val) + "s"

func _on_money_changed(val: float):
	MatchManager.starting_money = int(val)
	$SettingsPanel/VBox/MoneyLabel.text = "Starting Money: $" + str(val)

func _on_diff_selected(idx: int):
	MatchManager.bot_difficulty = idx

func _on_mode_selected(mode: MatchManager.MatchSize):
	selected_mode = mode
	mode_select.hide()
	faction_select.show()

func _on_faction_selected(faction: Team.TeamId):
	selected_faction = faction
	
	$FactionSelect/PoliceBtn.modulate = Color.GREEN if faction == Team.TeamId.POLICE else Color.WHITE
	$FactionSelect/TerroristBtn.modulate = Color.GREEN if faction == Team.TeamId.TERRORIST else Color.WHITE
	
	start_btn.show()

func _on_start_pressed():
	hide()
	
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	# Disable the overview camera
	var overview = get_tree().current_scene.get_node_or_null("OverviewCamera")
	if overview:
		overview.current = false
		
	# Call the level script to start the game
	var level = get_tree().current_scene
	if level and level.has_method("start_game"):
		level.start_game(selected_mode, selected_faction)
