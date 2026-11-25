class_name CourseRadar
extends Control

const RADAR_RANGE := 1600.0
const RADAR_CENTER := Vector2(90.0, 79.0)
const RADAR_SCALE := 42.0

var ship: Node3D
var target: Node3D
var target_name := ""
var target_world_position := Vector3.ZERO
var has_course := false
var _refresh_timer := 0.0
var _course_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(180.0, 164.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_course_label = Label.new()
	_course_label.position = Vector2(5.0, 137.0)
	_course_label.size = Vector2(170.0, 24.0)
	_course_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_course_label.add_theme_font_size_override("font_size", 11)
	_course_label.add_theme_color_override("font_color", Color(0.75, 0.93, 1.0))
	_course_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_course_label.add_theme_constant_override("shadow_offset_x", 1)
	_course_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_course_label)
	_update_course_label()

func set_course_target(node: Node3D) -> void:
	target = node
	has_course = node != null
	target_name = _get_target_name(node) if node != null else ""
	_update_course_label()
	queue_redraw()

func set_course_position(name: String, world_position: Vector3) -> void:
	target = null
	target_name = name
	target_world_position = world_position
	has_course = true
	_update_course_label()
	queue_redraw()

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < 0.1:
		return
	_refresh_timer = 0.0
	if target != null and not is_instance_valid(target):
		target = null
		has_course = false
	_update_course_label()
	queue_redraw()

func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color(0.015, 0.035, 0.055, 0.84), true)
	draw_rect(panel, Color(0.22, 0.58, 0.72, 0.9), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(8.0, 17.0), Locale.t("hud.radar"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.86, 1.0))

	for corner_bits in range(8):
		var corner := Vector3(
			1.0 if (corner_bits & 1) != 0 else -1.0,
			1.0 if (corner_bits & 2) != 0 else -1.0,
			1.0 if (corner_bits & 4) != 0 else -1.0
		)
		for axis in range(3):
			var neighbor_bits := corner_bits ^ (1 << axis)
			if neighbor_bits <= corner_bits:
				continue
			var neighbor := Vector3(
				1.0 if (neighbor_bits & 1) != 0 else -1.0,
				1.0 if (neighbor_bits & 2) != 0 else -1.0,
				1.0 if (neighbor_bits & 4) != 0 else -1.0
			)
			draw_line(_project_radar_point(corner), _project_radar_point(neighbor),
				Color(0.16, 0.42, 0.54, 0.72), 1.0)

	draw_line(_project_radar_point(Vector3(-1, 0, 0)), _project_radar_point(Vector3(1, 0, 0)),
		Color(0.22, 0.46, 0.54, 0.5), 1.0)
	draw_line(_project_radar_point(Vector3(0, -1, 0)), _project_radar_point(Vector3(0, 1, 0)),
		Color(0.22, 0.46, 0.54, 0.5), 1.0)
	draw_line(_project_radar_point(Vector3(0, 0, -1)), _project_radar_point(Vector3(0, 0, 1)),
		Color(0.22, 0.46, 0.54, 0.5), 1.0)
	draw_circle(RADAR_CENTER, 3.0, Color(1.0, 0.82, 0.25))

	if ship == null or not is_instance_valid(ship):
		return
	for contact in _get_contacts():
		if contact == ship or not is_instance_valid(contact):
			continue
		var local_position := _to_ship_local(contact.global_position - ship.global_position)
		if local_position.length() > RADAR_RANGE:
			continue
		var point := _project_radar_point(local_position / RADAR_RANGE)
		var color := _contact_color(contact)
		if contact == target:
			color = Color(0.25, 1.0, 0.95)
			draw_circle(point, 5.5, Color(0.25, 1.0, 0.95, 0.18))
			draw_arc(point, 5.5, 0.0, TAU, 24, color, 1.5)
		else:
			draw_circle(point, 2.5, color)

	if has_course:
		var target_position := _get_course_position()
		var target_local := _to_ship_local(target_position - ship.global_position)
		var radar_position := target_local / RADAR_RANGE
		radar_position = Vector3(
			clampf(radar_position.x, -1.0, 1.0),
			clampf(radar_position.y, -1.0, 1.0),
			clampf(radar_position.z, -1.0, 1.0)
		)
		var target_point := _project_radar_point(radar_position)
		if target_local.length() > RADAR_RANGE:
			draw_line(RADAR_CENTER, target_point, Color(0.25, 1.0, 0.95, 0.55), 1.0)
		draw_circle(target_point, 5.5, Color(0.25, 1.0, 0.95, 0.18))
		draw_arc(target_point, 5.5, 0.0, TAU, 24, Color(0.25, 1.0, 0.95), 1.5)

func _project_radar_point(point: Vector3) -> Vector2:
	var x := (point.x - point.z) * RADAR_SCALE * 0.5
	var y := (point.x + point.z) * RADAR_SCALE * 0.25 - point.y * RADAR_SCALE * 0.5
	return RADAR_CENTER + Vector2(x, y)

func _get_course_position() -> Vector3:
	if target != null and is_instance_valid(target):
		return target.global_position
	return WorldCoordinates.to_local_position(target_world_position)

func _to_ship_local(world_offset: Vector3) -> Vector3:
	var basis: Basis = ship.global_transform.basis
	return Vector3(world_offset.dot(basis.x), world_offset.dot(basis.y), world_offset.dot(basis.z))

func _get_contacts() -> Array[Node3D]:
	var contacts: Array[Node3D] = []
	var seen: Dictionary = {}
	for group in ["planets", "moons", "stars", "stations"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Node3D or seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			contacts.append(node as Node3D)
	return contacts

func _contact_color(node: Node3D) -> Color:
	if node.is_in_group("stars"):
		return Color(1.0, 0.72, 0.28)
	if node.is_in_group("planets"):
		return Color(0.3, 0.75, 1.0)
	if node.is_in_group("moons"):
		return Color(0.65, 0.78, 0.88)
	return Color(0.42, 1.0, 0.56)

func _update_course_label() -> void:
	if _course_label == null:
		return
	if not has_course or ship == null or not is_instance_valid(ship):
		_course_label.text = Locale.t("hud.radar_no_course")
		return
	_course_label.text = "%s  %.0f" % [
		target_name,
		ship.global_position.distance_to(_get_course_position())
	]

func _get_target_name(node: Node3D) -> String:
	var result := node.name
	if node is Planet:
		result = str((node as Planet).planet_data.get("name", node.name))
	elif node is Moon:
		result = (node as Moon).moon_display_name
	elif node is Star:
		result = (node as Star).system_name
	elif node.is_in_group("main_station_parts"):
		result = Locale.t("part.main_station")
	elif node is DurasteelRefinery:
		result = Locale.t("part.refinery")
	elif node is FusionCore:
		result = Locale.t("part.fusion_core")
	elif node is AntimatterFactoryBig:
		result = Locale.t("part.am_factory_big")
	elif node is AntimatterFactorySmall:
		result = Locale.t("part.am_factory_small")
	elif node is StorageContainer:
		result = Locale.t("part.storage_container")
	elif node is MiningDrill:
		result = Locale.t("part.mining_drill")
	return result
