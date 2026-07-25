## GraphicsSettingsUI
## A self-contained CanvasLayer that shows Low / Medium / High preset buttons.
## Can be instanced inside the main menu, pause menu, or standalone.
##
## Expected scene tree:
##   GraphicsSettingsUI (CanvasLayer)
##   └─ Panel
##      └─ VBoxContainer
##         ├─ TitleLabel         (Label)
##         ├─ HBoxContainer      (holds the three preset buttons)
##         │  ├─ BtnLow          (Button)
##         │  ├─ BtnMedium       (Button)
##         │  └─ BtnHigh         (Button)
##         └─ StatusLabel        (Label)

extends CanvasLayer

# ── Node references (set via @onready or create_ui()) ───────────────────────
var _btn_low:    Button
var _btn_medium: Button
var _btn_high:   Button
var _status_lbl: Label
var _panel:      Panel

# ── Button style colours ─────────────────────────────────────────────────────
const CLR_ACTIVE   := Color(0.18, 0.72, 0.42)   # Green — selected preset
const CLR_INACTIVE := Color(0.20, 0.22, 0.28)   # Dark slate — unselected
const CLR_HOVER    := Color(0.28, 0.30, 0.40)

# ── Labels shown next to the status line ────────────────────────────────────
const STATUS_TEXT := {
	GraphicsManager.Quality.LOW:    "⚡ Low — Best for mobile & slow devices",
	GraphicsManager.Quality.MEDIUM: "🎮 Medium — Balanced performance",
	GraphicsManager.Quality.HIGH:   "✨ High — Best visuals, powerful GPU needed",
}

# ── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	_refresh_buttons(GraphicsManager.get_quality())
	GraphicsManager.quality_changed.connect(_on_quality_changed)

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Root panel
	_panel = Panel.new()
	_panel.name = "Panel"

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.09, 0.10, 0.13, 0.95)
	style.border_color        = Color(0.25, 0.27, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left   = 16.0
	style.content_margin_right  = 16.0
	style.content_margin_top    = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)

	add_child(_panel)

	# Root VBox
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "⚙  Graphics Quality"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.25, 0.27, 0.35))
	vbox.add_child(sep)

	# Button row
	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	_btn_low    = _make_preset_button("Low",    GraphicsManager.Quality.LOW)
	_btn_medium = _make_preset_button("Medium", GraphicsManager.Quality.MEDIUM)
	_btn_high   = _make_preset_button("High",   GraphicsManager.Quality.HIGH)

	hbox.add_child(_btn_low)
	hbox.add_child(_btn_medium)
	hbox.add_child(_btn_high)

	# Status line
	_status_lbl = Label.new()
	_status_lbl.name = "StatusLabel"
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.60, 0.63, 0.70))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_lbl)

	# Size and position (bottom-left corner)
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.position = Vector2(12, -160)
	_panel.size     = Vector2(340, 150)

func _make_preset_button(label: String, quality: GraphicsManager.Quality) -> Button:
	var btn := Button.new()
	btn.name     = "Btn" + label
	btn.text     = label
	btn.custom_minimum_size = Vector2(90, 36)
	btn.focus_mode = Control.FOCUS_ALL

	# Normal style
	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color = CLR_INACTIVE
	s_normal.set_corner_radius_all(6)
	s_normal.content_margin_left  = 10.0
	s_normal.content_margin_right = 10.0
	btn.add_theme_stylebox_override("normal",   s_normal)

	# Hover style
	var s_hover := StyleBoxFlat.new()
	s_hover.bg_color = CLR_HOVER
	s_hover.set_corner_radius_all(6)
	s_hover.content_margin_left  = 10.0
	s_hover.content_margin_right = 10.0
	btn.add_theme_stylebox_override("hover",    s_hover)
	btn.add_theme_stylebox_override("focus",    s_hover)

	# Active style (stored — applied when selected)
	var s_active := StyleBoxFlat.new()
	s_active.bg_color = CLR_ACTIVE
	s_active.set_corner_radius_all(6)
	s_active.content_margin_left  = 10.0
	s_active.content_margin_right = 10.0
	btn.set_meta("style_active",   s_active)
	btn.set_meta("style_inactive", s_normal)

	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color.WHITE)

	btn.pressed.connect(func(): GraphicsManager.set_quality(quality))

	return btn

# ── Callbacks ─────────────────────────────────────────────────────────────────
func _on_quality_changed(q: GraphicsManager.Quality) -> void:
	_refresh_buttons(q)

func _refresh_buttons(q: GraphicsManager.Quality) -> void:
	var btns := {
		GraphicsManager.Quality.LOW:    _btn_low,
		GraphicsManager.Quality.MEDIUM: _btn_medium,
		GraphicsManager.Quality.HIGH:   _btn_high,
	}

	for quality in btns:
		var btn: Button = btns[quality]
		if btn == null:
			continue
		if quality == q:
			btn.add_theme_stylebox_override("normal",
				btn.get_meta("style_active"))
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			btn.add_theme_stylebox_override("normal",
				btn.get_meta("style_inactive"))
			btn.add_theme_color_override("font_color", Color(0.65, 0.67, 0.75))

	if _status_lbl:
		_status_lbl.text = STATUS_TEXT.get(q, "")

# ── Show / Hide helpers (callable from pause menu etc.) ─────────────────────
func show_panel() -> void:
	_panel.show()

func hide_panel() -> void:
	_panel.hide()

func toggle_panel() -> void:
	if _panel.visible:
		hide_panel()
	else:
		show_panel()
