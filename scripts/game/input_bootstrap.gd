class_name InputBootstrap
extends RefCounted

const KEY_BINDINGS := {
	&"move_forward": KEY_W,
	&"move_back": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"jump": KEY_SPACE,
	&"reload": KEY_R,
	&"weapon_1": KEY_1,
	&"weapon_2": KEY_2,
	&"weapon_3": KEY_3,
	&"dash": KEY_SHIFT,
	&"pause_game": KEY_ESCAPE,
}

static func ensure_defaults() -> void:
	for action in KEY_BINDINGS:
		_ensure_key(action, int(KEY_BINDINGS[action]))
	_ensure_fire()

static func _ensure_key(action: StringName, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

static func _ensure_fire() -> void:
	var action := &"fire"
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_get_events(action).is_empty():
		return
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(action, mouse)
