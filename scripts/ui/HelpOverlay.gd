class_name HelpOverlay
extends Control

var _label: Label
var _help_panel: PanelContainer
var _help_button: Button
var _ai_button: Button
var _station_button: Button
var _crew_system: CrewSystem
var _station_management: StationManagement

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_action_buttons()
	_build_help_panel()
	_refresh_text()
	Locale.language_changed.connect(func(_lang: String) -> void:
		_refresh_text()
		_update_button_text()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_language"): Locale.cycle_language()
	if event.is_action_pressed("toggle_help"):
		_toggle_help()
		get_viewport().set_input_as_handled()

func setup(crew_system: CrewSystem, station_management: StationManagement) -> void:
	_crew_system = crew_system
	_station_management = station_management
	if not _crew_system.emergency_ai_engaged.is_connected(_update_button_text):
		_crew_system.emergency_ai_engaged.connect(_update_button_text)
	if not _crew_system.emergency_ai_disengaged.is_connected(_update_button_text):
		_crew_system.emergency_ai_disengaged.connect(_update_button_text)
	if is_node_ready():
		_update_button_text()

func _build_action_buttons() -> void:
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(12.0, 12.0)
	buttons.add_theme_constant_override("separation", 8)
	buttons.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(buttons)

	_help_button = Button.new()
	_help_button.custom_minimum_size = Vector2(118.0, 42.0)
	_help_button.pressed.connect(_toggle_help)
	buttons.add_child(_help_button)

	_ai_button = Button.new()
	_ai_button.custom_minimum_size = Vector2(150.0, 42.0)
	_ai_button.pressed.connect(_toggle_emergency_ai)
	buttons.add_child(_ai_button)

	_station_button = Button.new()
	_station_button.custom_minimum_size = Vector2(168.0, 42.0)
	_station_button.pressed.connect(_toggle_station_management)
	buttons.add_child(_station_button)

func _build_help_panel() -> void:
	_help_panel = PanelContainer.new()
	_help_panel.position = Vector2(12.0, 62.0)
	_help_panel.custom_minimum_size = Vector2(390.0, 0.0)
	_help_panel.visible = false
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.045, 0.88)
	style.border_color = Color(0.24, 0.42, 0.58, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_help_panel.add_theme_stylebox_override("panel", style)
	add_child(_help_panel)

	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.add_child(_label)

func _toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible
	_update_button_text()

func _toggle_emergency_ai() -> void:
	if _crew_system != null:
		_crew_system.toggle_emergency_ai()

func _toggle_station_management() -> void:
	if _station_management != null:
		_station_management.toggle_panel()

func _update_button_text() -> void:
	if _help_button == null: return
	_help_button.text = Locale.t("hud.help_button")
	_ai_button.text = Locale.t("hud.emergency_ai")
	if _crew_system != null and _crew_system.emergency_ai_active:
		_ai_button.text = Locale.t("hud.emergency_ai_active")
	_station_button.text = Locale.t("hud.station_management")

func _refresh_text() -> void: _label.text = _help_text()

func _help_text() -> String:
	# ACHTUNG: Die Anzahl der Einträge unten MUSS exakt mit den \n%s übereinstimmen!
	return "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s" % [
		Locale.t("help.title"),
		Locale.t("help.move"),
		Locale.t("help.pitch_yaw"),
		Locale.t("help.roll"),
		Locale.t("help.vertical"),
		Locale.t("help.bridge"),
		Locale.t("help.editor"),
		Locale.t("help.place"),
		Locale.t("help.management"),
		Locale.t("help.build_mine"),
		Locale.t("help.free_cam"),
		Locale.t("help.map"),
		Locale.t("help.warp"),
		Locale.t("help.weapons"),
		Locale.t("shield.system"),
		Locale.t("help.dock"),
		Locale.t("help.ship_reactor"),
		Locale.t("help.quit"),
		Locale.t("help.language", {"lang": Locale.current_language}),
	]