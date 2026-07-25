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
