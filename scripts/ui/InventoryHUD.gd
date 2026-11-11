class_name InventoryHUD
extends Control
const REFRESH_INTERVAL := 0.25
var _label: Label; var _timer: float = 0.0
func _ready() -> void:
	anchor_right = 1.0; anchor_bottom = 1.0; mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.anchor_left  = 1.0; _label.anchor_right  = 1.0
	_label.anchor_top   = 0.0; _label.anchor_bottom = 0.0
	var top := 100.0 if TouchControls.should_show() else 10.0
	_label.offset_left  = -220.0; _label.offset_right  = -10.0
	_label.offset_top   = top;    _label.offset_bottom = top + 72.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override("font_color", Color(0.75, 0.93, 1.0, 0.95))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	_refresh()
	Locale.language_changed.connect(func(_lang: String) -> void: _refresh())
func _process(delta: float) -> void:
	_timer += delta
	if _timer >= REFRESH_INTERVAL: _timer = 0.0; _refresh()
func _refresh() -> void:
	_label.text = Locale.t("hud.inventory", {
		"minerals":   GameDatabase.get_resource("minerals"),
		"hydrogen":   GameDatabase.get_resource("hydrogen"),
		"deuterium":  GameDatabase.get_resource("deuterium"),
		"tritium":    GameDatabase.get_resource("tritium"),
		"antimatter": GameDatabase.get_resource("antimatter"),
		"durasteel":  GameDatabase.get_resource("durasteel"),
	})
