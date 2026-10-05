class_name BridgeDirectionIndicator
extends Control

const PANEL_SIZE := Vector2(210.0, 180.0)
const SHIP_CENTER := Vector2(91.0, 99.0)
const PITCH_LIMIT := 60.0

var bridge_view: Node3D = null

func _ready() -> void:
	custom_minimum_size = PANEL_SIZE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 24.0
	offset_top = -204.0
	offset_right = 234.0
	offset_bottom = -24.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func set_bridge_view(view: Node3D) -> void:
	bridge_view = view

func _process(_delta: float) -> void:
	var active := bridge_view != null and bool(bridge_view.get("is_active"))
	if visible != active:
		visible = active
	if active:
		queue_redraw()

func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, PANEL_SIZE)
	draw_rect(panel, Color(0.015, 0.025, 0.045, 0.90), true)
	draw_rect(panel, Color(0.25, 0.75, 1.0, 0.85), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 20.0),
		"VIEWSCREEN VIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color(0.55, 0.9, 1.0))

	var angles: Vector2 = bridge_view.call("get_viewscreen_look_angles")
	var yaw := deg_to_rad(angles.x)
	var heading := Vector2(sin(yaw), -cos(yaw))
	var right := Vector2(-heading.y, heading.x)

	for radius in [24.0, 48.0, 70.0]:
		draw_arc(SHIP_CENTER, radius, 0.0, TAU, 48,
			Color(0.12, 0.35, 0.5, 0.45), 1.0)

	var nose := SHIP_CENTER + heading * 22.0
	var tail := SHIP_CENTER - heading * 18.0
	var ship_shape := PackedVector2Array([
		nose,
		SHIP_CENTER + right * 7.0 + heading * 4.0,
		SHIP_CENTER + right * 22.0 - heading * 12.0,
		SHIP_CENTER + right * 6.0 - heading * 10.0,
		tail,
		SHIP_CENTER - right * 6.0 - heading * 10.0,
		SHIP_CENTER - right * 22.0 - heading * 12.0,
		SHIP_CENTER - right * 7.0 + heading * 4.0,
	])
	draw_colored_polygon(ship_shape, Color(0.24, 0.65, 0.88, 0.95))
	draw_polyline(ship_shape, Color(0.7, 0.95, 1.0), 1.2)
	draw_line(SHIP_CENTER - right * 30.0, SHIP_CENTER + right * 30.0,
		Color(0.55, 0.9, 1.0, 0.75), 1.0)

	var view_tip := SHIP_CENTER + heading * 62.0
	draw_line(SHIP_CENTER, view_tip, Color(1.0, 0.8, 0.25), 2.0)
	draw_circle(view_tip, 4.0, Color(1.0, 0.8, 0.25))
	draw_string(ThemeDB.fallback_font, view_tip + Vector2(6.0, 4.0),
		"VIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.85, 0.35))

	var pitch_top := 54.0
	var pitch_bottom := 130.0
	var pitch_y: float = lerp(pitch_top, pitch_bottom,
		clamp(angles.y / PITCH_LIMIT * 0.5 + 0.5, 0.0, 1.0))
	draw_line(Vector2(185.0, pitch_top), Vector2(185.0, pitch_bottom),
		Color(0.2, 0.5, 0.65, 0.8), 2.0)
	draw_line(Vector2(179.0, 92.0), Vector2(191.0, 92.0),
		Color(0.5, 0.8, 0.9, 0.7), 1.0)
	draw_circle(Vector2(185.0, pitch_y), 4.0, Color(1.0, 0.8, 0.25))
	draw_string(ThemeDB.fallback_font, Vector2(174.0, 148.0),
		"PITCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.8, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 168.0),
		"YAW %03d  PITCH %03d" % [int(fmod(angles.x + 360.0, 360.0)), int(angles.y)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.8, 0.9))
