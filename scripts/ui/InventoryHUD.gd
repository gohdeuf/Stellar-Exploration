class_name InventoryHUD
extends Control
const REFRESH_INTERVAL := 0.25
var _label: Label; var _timer: float = 0.0
var _ship: Node3D
var _camera: Camera3D
var _radar: CourseRadar

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
	_radar = CourseRadar.new()
	_radar.anchor_left = 1.0; _radar.anchor_right = 1.0
	_radar.anchor_top = 0.0; _radar.anchor_bottom = 0.0
	_radar.offset_left = -410.0; _radar.offset_right = -230.0
	_radar.offset_top = top; _radar.offset_bottom = top + 164.0
	add_child(_radar)
	_refresh()
	Locale.language_changed.connect(func(_lang: String) -> void: _refresh())

func setup_course_radar(ship: Node3D, camera: Camera3D) -> void:
	_ship = ship
	_camera = camera
	_radar.ship = ship

func set_course_position(target_name: String, world_position: Vector3) -> void:
	_radar.set_course_position(target_name, world_position)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_MIDDLE or not mouse_event.pressed:
		return
	if _camera == null or not is_instance_valid(_camera) or _ship == null or not is_instance_valid(_ship):
		return
	if StationEditor.is_editor_open:
		return
	var map := get_tree().get_first_node_in_group("galaxy_map")
	if map != null and map.visible:
		return
	var target := _find_target_at(mouse_event.position)
	_radar.set_course_target(target)
	get_viewport().set_input_as_handled()

func _find_target_at(screen_position: Vector2) -> Node3D:
	var ray_origin := _camera.project_ray_origin(screen_position)
	var ray_direction := _camera.project_ray_normal(screen_position)
	var closest_distance := INF
	var closest_target: Node3D
	var candidates: Array[Node3D] = []
	var seen: Dictionary = {}
	for group in ["planets", "moons", "stars", "stations"]:
		for node in get_tree().get_nodes_in_group(group):
			if not node is Node3D or seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			candidates.append(node as Node3D)

	for candidate in candidates:
		if candidate == _ship:
			continue
		var radius := _target_radius(candidate)
		var offset := candidate.global_position - ray_origin
		var along_ray := offset.dot(ray_direction)
		if along_ray <= 0.0:
			continue
		var perpendicular_squared := offset.length_squared() - along_ray * along_ray
		if perpendicular_squared > radius * radius:
			continue
		var hit_distance := along_ray - sqrt(radius * radius - perpendicular_squared)
		if hit_distance < closest_distance:
			closest_distance = hit_distance
			closest_target = candidate
	return closest_target

func _target_radius(node: Node3D) -> float:
	if node is Planet:
		return float((node as Planet).planet_data.get("radius", 5.0)) * 1.06
	if node is Moon:
		return (node as Moon).moon_radius
	if node.is_in_group("stars"):
		return 10.2
	if node.is_in_group("main_station_parts"):
		return 0.12
	if node.is_in_group("stations"):
		return 0.09
	return 6.0

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
