class_name HelpOverlay
extends Control

var _label: Label

func _ready() -> void:
	_label = Label.new(); _label.position = Vector2(10, 10)
	_label.add_theme_color_override("font_color", Color(1,1,1,0.85)); add_child(_label)
	_refresh_text()
	Locale.language_changed.connect(func(_lang: String) -> void: _refresh_text())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_language"): Locale.cycle_language()

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