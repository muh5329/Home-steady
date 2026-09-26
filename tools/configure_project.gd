extends SceneTree
## Writes project settings (input map, autoloads, layers, rendering) into
## project.godot. Re-run after editing this file:
##     godot --headless --path . -s res://tools/configure_project.gd
## Keeping the canonical input map in code makes bindings reviewable in diffs.

const AUTOLOADS := [
	["EventBus", "res://core/events/event_bus.gd"],
	["DataRegistry", "res://core/data/data_registry.gd"],
	["SaveManager", "res://core/save/save_manager.gd"],
	["DebugOverlay", "res://core/utilities/debug_overlay.gd"],
	["GameManager", "res://core/game_manager.gd"],
]

const PHYSICS_LAYERS := {
	1: "world",
	2: "characters",
	3: "hurtboxes",
	4: "interactables",
	5: "props",
	6: "footprints",
}

# action -> [events]; events are ["key", KEY_*] / ["mouse", MOUSE_BUTTON_*] /
# ["joy_button", JOY_BUTTON_*] / ["joy_axis", JOY_AXIS_*, direction]
var ACTIONS := {
	"move_forward": [["key", KEY_W], ["key", KEY_UP], ["joy_axis", JOY_AXIS_LEFT_Y, -1.0]],
	"move_back": [["key", KEY_S], ["key", KEY_DOWN], ["joy_axis", JOY_AXIS_LEFT_Y, 1.0]],
	"move_left": [["key", KEY_A], ["key", KEY_LEFT], ["joy_axis", JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [["key", KEY_D], ["key", KEY_RIGHT], ["joy_axis", JOY_AXIS_LEFT_X, 1.0]],
	"look_left": [["joy_axis", JOY_AXIS_RIGHT_X, -1.0]],
	"look_right": [["joy_axis", JOY_AXIS_RIGHT_X, 1.0]],
	"look_up": [["joy_axis", JOY_AXIS_RIGHT_Y, -1.0]],
	"look_down": [["joy_axis", JOY_AXIS_RIGHT_Y, 1.0]],
	"sprint": [["key", KEY_SHIFT], ["joy_button", JOY_BUTTON_LEFT_STICK]],
	"walk": [["key", KEY_ALT]],
	"jump": [["key", KEY_SPACE], ["joy_button", JOY_BUTTON_A]],
	"dodge": [["key", KEY_CTRL], ["key", KEY_C], ["joy_button", JOY_BUTTON_B]],
	"interact": [["key", KEY_E], ["joy_button", JOY_BUTTON_X]],
	"drop": [["key", KEY_G], ["joy_button", JOY_BUTTON_Y]],
	"ability_1": [["key", KEY_Q], ["joy_button", JOY_BUTTON_RIGHT_STICK]],
	"attack_light": [["mouse", MOUSE_BUTTON_LEFT], ["joy_button", JOY_BUTTON_RIGHT_SHOULDER]],
	"attack_heavy": [["key", KEY_F], ["joy_axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"block": [["mouse", MOUSE_BUTTON_RIGHT], ["joy_button", JOY_BUTTON_LEFT_SHOULDER]],
	"pause": [["key", KEY_ESCAPE], ["joy_button", JOY_BUTTON_START]],
	"build_menu": [["key", KEY_B], ["joy_button", JOY_BUTTON_DPAD_UP]],
	"rotate_building": [["key", KEY_R], ["joy_button", JOY_BUTTON_DPAD_RIGHT]],
	"demolish": [["key", KEY_X], ["joy_button", JOY_BUTTON_DPAD_DOWN]],
	"quick_save": [["key", KEY_F5]],
	"quick_load": [["key", KEY_F9]],
	"debug_toggle": [["key", KEY_F3]],
}


func _initialize() -> void:
	for pair in AUTOLOADS:
		ProjectSettings.set_setting("autoload/" + pair[0], "*" + pair[1])

	for action in ACTIONS:
		var events: Array = []
		for spec in ACTIONS[action]:
			events.append(_make_event(spec))
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.25, "events": events})

	for index in PHYSICS_LAYERS:
		ProjectSettings.set_setting("layer_names/3d_physics/layer_%d" % index, PHYSICS_LAYERS[index])

	var s := {
		"application/config/name": "Home Steady",
		"application/config/description": "Medieval fantasy settlement-building action RPG.",
		"application/run/main_scene": "res://main.tscn",
		"display/window/size/viewport_width": 1600,
		"display/window/size/viewport_height": 900,
		"display/window/stretch/mode": "canvas_items",
		"display/window/stretch/aspect": "expand",
		"physics/3d/physics_engine": "Jolt Physics",
		"physics/common/physics_ticks_per_second": 60,
		"rendering/anti_aliasing/quality/msaa_3d": 2,
		"rendering/lights_and_shadows/directional_shadow/size": 4096,
		"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality": 3,
		"rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality": 3,
		"rendering/environment/volumetric_fog/volume_size": 96,
		"rendering/textures/default_filters/anisotropic_filtering_level": 3,
		"debug/gdscript/warnings/untyped_declaration": 0,
	}
	for key in s:
		ProjectSettings.set_setting(key, s[key])

	var err := ProjectSettings.save()
	print("configure_project: ", error_string(err))
	quit(0 if err == OK else 1)


func _make_event(spec: Array) -> InputEvent:
	var e := _make_raw_event(spec)
	e.device = -1  # any device
	return e


func _make_raw_event(spec: Array) -> InputEvent:
	match spec[0]:
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = spec[1]
			return e
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = spec[1]
			return e
		"joy_button":
			var e := InputEventJoypadButton.new()
			e.button_index = spec[1]
			return e
		"joy_axis":
			var e := InputEventJoypadMotion.new()
			e.axis = spec[1]
			e.axis_value = spec[2]
			return e
	push_error("bad input spec %s" % [spec])
	return null
