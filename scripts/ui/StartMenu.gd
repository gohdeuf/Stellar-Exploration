class_name StartMenu
extends Control

signal singleplayer_requested
signal quit_requested

var _panel: PanelContainer
var _title: Label
var _notice: Label
var _singleplayer_button: Button
var _vr_button: Button
var _mods_button: Button
var _multiplayer_button: Button
var _quit_button: Button
var _vr_enabled: bool = false
var _notice_key: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vr_enabled = get_viewport().use_xr
	if not _vr_enabled:
		var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
		if xr_interface != null and xr_interface.is_initialized():
			xr_interface.uninitialize()
	_build_menu()
	_update_text()
	Locale.language_changed.connect(func(_language: String) -> void: _update_text())
	_singleplayer_button.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("quit_game"):
		get_viewport().set_input_as_handled()

func show_menu() -> void:
	visible = true
	_notice_key = ""
	_notice.text = ""
	_singleplayer_button.grab_focus()

func hide_menu() -> void:
	visible = false

func _build_menu() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.005, 0.01, 0.025, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -240.0
	_panel.offset_top = -245.0
	_panel.offset_right = 240.0
	_panel.offset_bottom = 245.0
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel)

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	_panel.add_child(menu_box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	menu_box.add_child(_title)

	_singleplayer_button = _make_button(menu_box, func() -> void: singleplayer_requested.emit())
	_vr_button = _make_button(menu_box, _toggle_vr)
	_mods_button = _make_button(menu_box, func() -> void: _show_notice("start_menu.mods_coming"))
	_multiplayer_button = _make_button(menu_box, func() -> void: _show_notice("start_menu.multiplayer_coming"))

	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD
	_notice.custom_minimum_size = Vector2(0.0, 52.0)
	menu_box.add_child(_notice)

	_quit_button = _make_button(menu_box, func() -> void: quit_requested.emit())

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.075, 0.98)
	style.border_color = Color(0.25, 0.52, 0.72, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	return style

func _make_button(parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _update_text() -> void:
	if _title == null:
		return
	_title.text = Locale.t("start_menu.title")
	_singleplayer_button.text = Locale.t("start_menu.singleplayer")
	_vr_button.text = Locale.t("start_menu.vr_on" if _vr_enabled else "start_menu.vr_off")
	_mods_button.text = Locale.t("start_menu.mods")
	_multiplayer_button.text = Locale.t("start_menu.multiplayer")
	_quit_button.text = Locale.t("pause.quit")
	_notice.text = Locale.t(_notice_key) if not _notice_key.is_empty() else ""

func _toggle_vr() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		_show_notice("start_menu.vr_unavailable")
		return

	if _vr_enabled:
		get_viewport().use_xr = false
		if xr_interface.is_initialized():
			xr_interface.uninitialize()
		_vr_enabled = false
	else:
		if not xr_interface.is_initialized() and not xr_interface.initialize():
			_show_notice("start_menu.vr_unavailable")
			return
		get_viewport().use_xr = true
		_vr_enabled = true

	_notice_key = ""
	_notice.text = ""
	_update_text()

func _show_notice(message_key: String) -> void:
	_notice_key = message_key
	_notice.text = Locale.t(_notice_key)
