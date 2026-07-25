## GraphicsManager — Autoload singleton
## Manages Low / Medium / High graphics presets for mobile and web targets.
## Persists the chosen quality level via ConfigFile so it survives restarts.

extends Node

# ── Quality levels ──────────────────────────────────────────────────────────
enum Quality { LOW = 0, MEDIUM = 1, HIGH = 2 }

const QUALITY_NAMES := ["Low", "Medium", "High"]
const SAVE_PATH    := "user://graphics_settings.cfg"
const SECTION      := "graphics"
const KEY_QUALITY  := "quality"

var current_quality: Quality = Quality.MEDIUM

signal quality_changed(new_quality: Quality)

# ── Preset tables ────────────────────────────────────────────────────────────
# Each entry: { viewport_scale, shadow_quality, msaa, use_glow, use_ssao,
#               use_fog, texture_filter, fxaa }
var PRESETS := {
	Quality.LOW: {
		"viewport_scale":  0.65,   # Render at 65 % resolution
		"shadow_quality":  RenderingServer.SHADOW_QUALITY_HARD,
		"msaa":            Viewport.MSAA_DISABLED,
		"fxaa":            false,
		"use_glow":        false,
		"use_ssao":        false,
		"use_fog":         false,
		"max_fps":         60,
	},
	Quality.MEDIUM: {
		"viewport_scale":  0.85,   # Render at 85 % resolution
		"shadow_quality":  RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"msaa":            Viewport.MSAA_2X,
		"fxaa":            true,
		"use_glow":        false,
		"use_ssao":        false,
		"use_fog":         true,
		"max_fps":         60,
	},
	Quality.HIGH: {
		"viewport_scale":  1.0,    # Native resolution
		"shadow_quality":  RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		"msaa":            Viewport.MSAA_4X,
		"fxaa":            true,
		"use_glow":        true,
		"use_ssao":        true,
		"use_fog":         true,
		"max_fps":         0,      # Uncapped
	},
}

# ── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_settings()
	# Defer so the scene tree (and WorldEnvironment) is fully loaded first
	call_deferred("apply_quality", current_quality)

# ── Public API ───────────────────────────────────────────────────────────────
func set_quality(q: Quality) -> void:
	if q == current_quality:
		return
	current_quality = q
	apply_quality(q)
	_save_settings()
	emit_signal("quality_changed", q)

func get_quality() -> Quality:
	return current_quality

func get_quality_name(q: Quality = current_quality) -> String:
	return QUALITY_NAMES[q]

# ── Core application ─────────────────────────────────────────────────────────
func apply_quality(q: Quality) -> void:
	var p: Dictionary = PRESETS[q]

	# 1. Viewport scaling (3D render scale)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale  = p["viewport_scale"]
		vp.msaa_3d           = p["msaa"]
		if OS.has_feature("web"):
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		else:
			vp.screen_space_aa   = (Viewport.SCREEN_SPACE_AA_FXAA
									if p["fxaa"] else
									Viewport.SCREEN_SPACE_AA_DISABLED)

	# 2. Shadow quality (global)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["shadow_quality"])

	# 3. WorldEnvironment tweaks (glow, SSAO, fog)
	_apply_environment(p)

	# 4. FPS cap
	Engine.max_fps = p["max_fps"]

	print("[GraphicsManager] Applied preset: ", QUALITY_NAMES[q])

# ── Environment helpers ───────────────────────────────────────────────────────
func _apply_environment(p: Dictionary) -> void:
	# Find the WorldEnvironment anywhere in the current scene tree
	var env_node := _find_world_environment(get_tree().root)
	if env_node == null:
		# No WorldEnvironment yet — try again after the next frame
		await get_tree().process_frame
		env_node = _find_world_environment(get_tree().root)
		if env_node == null:
			return

	var env: Environment = env_node.environment
	if env == null:
		return

	# Glow
	env.glow_enabled = p["use_glow"]

	# SSAO
	env.ssao_enabled = p["use_ssao"]

	# Fog
	env.fog_enabled = p["use_fog"]

func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node as WorldEnvironment
	for child in node.get_children():
		var found := _find_world_environment(child)
		if found:
			return found
	return null

# ── Persistence ───────────────────────────────────────────────────────────────
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_QUALITY, int(current_quality))
	cfg.save(SAVE_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved: int = cfg.get_value(SECTION, KEY_QUALITY, Quality.MEDIUM)
		current_quality = clamp(saved, Quality.LOW, Quality.HIGH) as Quality
	else:
		# Auto-detect a sensible default for web / mobile
		current_quality = _detect_default_quality()

func _detect_default_quality() -> Quality:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return Quality.HIGH
	return Quality.HIGH
