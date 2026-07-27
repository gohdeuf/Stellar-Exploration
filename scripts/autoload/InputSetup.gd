extends Node
func _ready() -> void:
	_add("move_forward",KEY_W);      _add("move_back",KEY_S)
	_add("move_left",KEY_A);         _add("move_right",KEY_D)
	_add("pitch_up",KEY_UP);         _add("pitch_down",KEY_DOWN)
	_add("yaw_left",KEY_LEFT);       _add("yaw_right",KEY_RIGHT)
	_add("roll_left",KEY_Q);         _add("roll_right",KEY_E)
	_add("move_up",KEY_SPACE);       _add("move_down",KEY_CTRL)
	_add("toggle_free_cam",KEY_F10); _add("toggle_map",KEY_TAB)
	_add("quit_game",KEY_ESCAPE);    _add("boost",KEY_SHIFT)
	_add("build_station",KEY_B);     _add("mine_resource",KEY_M)
	_add("place_module",KEY_E);      _add("station_management",KEY_H)
	_add("deposit_resources",KEY_D); _add("withdraw_resources",KEY_W)
	_add("fire_primary",KEY_F);      _add("fire_torpedo",KEY_T)
	_add("next_weapon",KEY_X);       _add("toggle_warp",KEY_J)
	_add("dock_station",KEY_K);      _add("emergency_ai_toggle",KEY_N)
	_add("toggle_ship_am",KEY_P);    _add("toggle_bridge",KEY_C)
	_add("toggle_vscreen",KEY_V);    _add("look_reset",KEY_R)
	_add_shift("cycle_language",KEY_L)

func _add_shift(n: String, k: Key) -> void:
	if InputMap.has_action(n): return
	InputMap.add_action(n); var ev := InputEventKey.new()
	ev.physical_keycode = k; ev.shift_pressed = true; InputMap.action_add_event(n, ev)
func _add(n: String, k: Key) -> void:
	if InputMap.has_action(n): return
	InputMap.add_action(n); var ev := InputEventKey.new()
	ev.physical_keycode = k; InputMap.action_add_event(n, ev)