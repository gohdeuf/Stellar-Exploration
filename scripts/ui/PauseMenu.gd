class_name PauseMenu
extends Control

signal quit_requested
signal main_menu_requested

var _menu_panel: PanelContainer
var _license_panel: PanelContainer
var _title: Label
var _license_title: Label
var _resume_button: Button
var _main_menu_button: Button
var _licenses_button: Button
var _quit_button: Button
var _license_back_button: Button
var _license_text: TextEdit
var _gameplay_menu_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_menu()
	_build_license_panel()
	_update_text()
	Locale.language_changed.connect(func(_language: String) -> void: _update_text())

func _input(event: InputEvent) -> void:
	if not _gameplay_menu_active or not event.is_action_pressed("quit_game"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		_open_menu()
	elif _license_panel.visible:
		_show_menu_panel()
	else:
		_close_menu()

func _build_menu() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.005, 0.01, 0.025, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_menu_panel = _make_panel(Vector2(-230.0, -190.0), Vector2(230.0, 190.0))
	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	_menu_panel.add_child(menu_box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	menu_box.add_child(_title)
	_resume_button = _make_button(menu_box, _on_resume_pressed)
	_main_menu_button = _make_button(menu_box, func() -> void: main_menu_requested.emit())
	_licenses_button = _make_button(menu_box, _on_licenses_pressed)
	_quit_button = _make_button(menu_box, func() -> void: quit_requested.emit())

func _build_license_panel() -> void:
	_license_panel = _make_panel(Vector2(-500.0, -340.0), Vector2(500.0, 340.0))
	_license_panel.visible = false
	var license_box := VBoxContainer.new()
	license_box.add_theme_constant_override("separation", 10)
	_license_panel.add_child(license_box)
	_license_title = Label.new()
	_license_title.add_theme_font_size_override("font_size", 24)
	license_box.add_child(_license_title)
	_license_text = TextEdit.new()
	_license_text.editable = false
	_license_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_license_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_license_text.custom_minimum_size = Vector2(0.0, 500.0)
	license_box.add_child(_license_text)
	_license_back_button = _make_button(license_box, _show_menu_panel)

func _make_panel(offset_min: Vector2, offset_max: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = offset_min.x
	panel.offset_top = offset_min.y
	panel.offset_right = offset_max.x
	panel.offset_bottom = offset_max.y
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)
	return panel

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
	_title.text = Locale.t("pause.title")
	_resume_button.text = Locale.t("pause.resume")
	_main_menu_button.text = Locale.t("pause.main_menu")
	_licenses_button.text = Locale.t("pause.licenses")
	_quit_button.text = Locale.t("pause.quit")
	_license_title.text = Locale.t("pause.licenses")
	_license_back_button.text = Locale.t("pause.back")

func _open_menu() -> void:
	visible = true
	get_tree().paused = true
	_show_menu_panel()
	_resume_button.grab_focus()

func _close_menu() -> void:
	visible = false
	get_tree().paused = false

func set_gameplay_menu_active(active: bool) -> void:
	_gameplay_menu_active = active

func show_menu() -> void:
	visible = true
	get_tree().paused = true
	_show_menu_panel()
	_resume_button.grab_focus()

func hide_menu() -> void:
	visible = false

func _show_menu_panel() -> void:
	_menu_panel.visible = true
	_license_panel.visible = false

func _on_resume_pressed() -> void:
	_close_menu()

func _on_licenses_pressed() -> void:
	_license_text.text = _get_license_text()
	_menu_panel.visible = false
	_license_panel.visible = true
	_license_back_button.grab_focus()

func _get_license_text() -> String:
	var lines: Array[String] = [
		Locale.t("pause.godot_notice"),
		"",
		Engine.get_license_text(),
		"",
		Locale.t("pause.third_party"),
	]
	for component in Engine.get_copyright_info():
		lines.append("")
		lines.append(str(component.get("name", "")))
		for part in component.get("parts", []):
			lines.append("  %s" % str(part.get("copyright", "")))
			lines.append("  License: %s" % str(part.get("license", "")))

	var license_info: Dictionary = Engine.get_license_info()
	for license_name in license_info:
		lines.append("\n%s\n%s" % [str(license_name), str(license_info[license_name])])
	return "\n".join(lines)
