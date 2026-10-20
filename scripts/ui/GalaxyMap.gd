class_name GalaxyMap
extends Control

const MAP_SCALE := 0.05
const DEFAULT_CAMERA_DISTANCE := 260.0
const GRID_SPACING := 25.0
const GRID_HALF_SIZE := 250.0

enum DragMode { NONE, ORBIT, PAN }

@export var refresh_interval: float = 5.0

@onready var _subviewport: SubViewport = $ViewportContainer/SubViewport
@onready var _map_world: Node3D = $ViewportContainer/SubViewport/MapWorld
@onready var _camera: Camera3D = $ViewportContainer/SubViewport/MapWorld/Camera3D

var player: Node3D
var _systems: Array = []
var _systems_by_id: Dictionary = {}
var _systems_revision: String = ""
var _zoom: float = 1.0
var _camera_target: Vector3 = Vector3.ZERO
var _camera_yaw: float = deg_to_rad(35.0)
var _camera_pitch: float = deg_to_rad(28.0)
var _drag_mode: int = DragMode.NONE
var _refresh_timer: float = 0.0
var _planet_refresh_timer: float = 0.0
var _last_height_reference: float = INF
var _last_planet_cache_position: Vector3 = Vector3.ZERO

var _map_content: Node3D
var _system_root: Node3D
var _station_root: Node3D
var _planet_root: Node3D
var _reference_grid: MeshInstance3D
var _axis_root: Node3D
var _height_guides: MeshInstance3D
var _player_marker: Node3D
var _planet_markers: Array = []
var _station_markers: Array = []
var _readout: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	_subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_map_content = Node3D.new()
	_map_content.name = "MapContent"
	_map_world.add_child(_map_content)
	_system_root = Node3D.new(); _system_root.name = "Systems"
	_station_root = Node3D.new(); _station_root.name = "Stations"
	_planet_root = Node3D.new(); _planet_root.name = "Planets"
	_map_content.add_child(_system_root)
	_map_content.add_child(_station_root)
	_map_content.add_child(_planet_root)
	_build_reference_grid()
	_build_axes()
	_build_player_marker()
	_camera.fov = 55.0
	_camera.near = 0.1
	_camera.far = 100000.0
	_create_hud()
	resized.connect(_sync_viewport_size)
	_sync_viewport_size()
	SectorGenerator.system_updated.connect(_on_system_updated)
	_refresh_systems(true)
	_update_camera()

func set_player(node: Node3D) -> void:
	player = node
	_update_map_origin()
	_rebuild_station_markers()
	_rebuild_planet_markers()
	_rebuild_height_guides()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		visible = not visible
		get_viewport().set_input_as_handled()
		if visible: _refresh_systems()
		return
	if not visible: return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_drag_mode = DragMode.ORBIT if mouse_event.pressed else DragMode.NONE
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT or mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_drag_mode = DragMode.PAN if mouse_event.pressed else DragMode.NONE
			if not mouse_event.pressed: _rebuild_planet_markers()
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.12, 0.1, 20.0)
			_rebuild_planet_markers()
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.12, 0.1, 20.0)
			_rebuild_planet_markers()
		_update_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _drag_mode == DragMode.ORBIT:
			_camera_yaw -= motion.relative.x * 0.005
			_camera_pitch = clampf(_camera_pitch - motion.relative.y * 0.005, deg_to_rad(-78.0), deg_to_rad(78.0))
			_update_camera()
		elif _drag_mode == DragMode.PAN:
			var drag_scale: float = _camera_distance() * 0.002
			_camera_target += (-_camera.global_transform.basis.x * motion.relative.x \
				+ _camera.global_transform.basis.y * motion.relative.y) * drag_scale
			_update_camera()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_HOME:
			_camera_target = Vector3.ZERO
			_camera_yaw = deg_to_rad(35.0)
			_camera_pitch = deg_to_rad(28.0)
			_zoom = 1.0
			_rebuild_planet_markers()
			_update_camera()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible: return
	_sync_viewport_size()
	_update_map_origin()
	_update_camera()
	_update_station_positions()
	_update_planet_positions()
	_update_readout()
	_refresh_timer += delta
	_planet_refresh_timer += delta
	if _refresh_timer >= refresh_interval:
		_refresh_timer = 0.0
		_refresh_systems()
		_rebuild_station_markers()
		_rebuild_height_guides()
	if player != null and absf(player.global_position.y - _last_height_reference) > 100.0:
		_rebuild_height_guides()
	if _planet_refresh_timer >= 0.75:
		_planet_refresh_timer = 0.0
		if player != null and player.global_position.distance_to(_last_planet_cache_position) > 100.0:
			_rebuild_planet_markers()

func _refresh_systems(force: bool = false) -> void:
	var revision: String = GameDatabase.get_system_revision()
	if not force and revision == _systems_revision: return
	_systems_revision = revision
	_systems_by_id.clear()
	for system_data in GameDatabase.get_all_systems():
		_systems_by_id[system_data["system_id"]] = system_data
	_systems = _systems_by_id.values()
	_rebuild_system_markers()
	_rebuild_planet_markers()
	_rebuild_station_markers()
	_rebuild_height_guides()

func _on_system_updated(system_data: Dictionary) -> void:
	var system_id: String = system_data.get("system_id", "")
	if system_id.is_empty(): return
	_systems_by_id[system_id] = system_data
	_systems = _systems_by_id.values()
	_systems_revision = GameDatabase.get_system_revision()
	_rebuild_system_markers()
	_rebuild_planet_markers()
	_rebuild_height_guides()

func _rebuild_system_markers() -> void:
	_clear_children(_system_root)
	for system_data in _systems:
		var system_position: Vector3 = system_data["position"]
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.75; sphere.height = 1.5
		sphere.radial_segments = 16; sphere.rings = 8
		marker.mesh = sphere
		marker.position = system_position * MAP_SCALE
		marker.material_override = _make_emissive_material(Color(1.0, 0.72, 0.28), 1.5)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_system_root.add_child(marker)
		var label := _make_label(str(system_data.get("name", "")), Color(1.0, 0.86, 0.62), 40, 0.055)
		label.position = Vector3(0.0, 1.8, 0.0)
		marker.add_child(label)

func _rebuild_station_markers() -> void:
	_clear_children(_station_root)
	_station_markers.clear()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45; sphere.height = 0.9
	sphere.radial_segments = 12; sphere.rings = 6
	var station_material := _make_emissive_material(Color(0.2, 0.88, 0.88), 1.2)
	for station in get_tree().get_nodes_in_group("stations"):
		if not station is Node3D: continue
		var marker := MeshInstance3D.new()
		marker.mesh = sphere
		marker.material_override = station_material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_station_root.add_child(marker)
		_station_markers.append({"node": marker, "station": station})

func _update_station_positions() -> void:
	for entry in _station_markers:
		var station: Node3D = entry["station"]
		var marker: MeshInstance3D = entry["node"]
		if is_instance_valid(station) and is_instance_valid(marker):
			marker.position = station.global_position * MAP_SCALE

func _rebuild_planet_markers() -> void:
	_clear_children(_planet_root)
	_planet_markers.clear()
	_planet_root.visible = _zoom > 4.0
	if not _planet_root.visible or player == null: return
	var player_map_position: Vector3 = player.global_position * MAP_SCALE
	var visible_radius: float = _camera_distance() * 2.5
	var sphere := SphereMesh.new()
	sphere.radius = 0.34; sphere.height = 0.68
	sphere.radial_segments = 12; sphere.rings = 6
	var planet_material := _make_emissive_material(Color(0.45, 0.8, 1.0), 1.0)
	for system_data in _systems:
		var system_position: Vector3 = system_data["position"]
		if (system_position * MAP_SCALE - player_map_position).distance_to(_camera_target) > visible_radius:
			continue
		for planet_data in system_data.get("planets", []):
			var marker := MeshInstance3D.new()
			marker.mesh = sphere
			marker.material_override = planet_material
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_planet_root.add_child(marker)
			var label := _make_label(str(planet_data.get("name", "")), Color(0.72, 0.88, 1.0), 28, 0.045)
			label.position = Vector3(0.0, 0.8, 0.0)
			marker.add_child(label)
			_planet_markers.append({
				"node": marker,
				"system_position": system_position,
				"planet_data": planet_data,
			})
	_last_planet_cache_position = player.global_position

func _update_planet_positions() -> void:
	for entry in _planet_markers:
		var marker: MeshInstance3D = entry["node"]
		if not is_instance_valid(marker): continue
		var planet_world_position: Vector3 = SectorGenerator.get_planet_position(entry["system_position"], entry["planet_data"])
		marker.position = planet_world_position * MAP_SCALE

func _rebuild_height_guides() -> void:
	if player == null or _height_guides == null: return
	if _systems.is_empty():
		_height_guides.mesh = null
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var reference_y: float = player.global_position.y * MAP_SCALE
	for system_data in _systems:
		var system_map_position: Vector3 = system_data["position"] * MAP_SCALE
		if absf(system_map_position.y - reference_y) < 0.05: continue
		mesh.surface_add_vertex(Vector3(system_map_position.x, reference_y, system_map_position.z))
		mesh.surface_add_vertex(system_map_position)
	mesh.surface_end()
	_height_guides.mesh = mesh
	_last_height_reference = player.global_position.y

func _build_reference_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var steps: int = int(GRID_HALF_SIZE / GRID_SPACING)
	for index in range(-steps, steps + 1):
		var offset: float = float(index) * GRID_SPACING
		mesh.surface_add_vertex(Vector3(offset, 0.0, -GRID_HALF_SIZE))
		mesh.surface_add_vertex(Vector3(offset, 0.0, GRID_HALF_SIZE))
		mesh.surface_add_vertex(Vector3(-GRID_HALF_SIZE, 0.0, offset))
		mesh.surface_add_vertex(Vector3(GRID_HALF_SIZE, 0.0, offset))
	mesh.surface_end()
	_reference_grid = MeshInstance3D.new()
	_reference_grid.mesh = mesh
	_reference_grid.material_override = _make_unshaded_material(Color(0.22, 0.36, 0.42, 0.32))
	_map_content.add_child(_reference_grid)
	_height_guides = MeshInstance3D.new()
	_height_guides.name = "SystemHeightGuides"
	_height_guides.material_override = _make_unshaded_material(Color(0.35, 0.72, 0.9, 0.42))
	_map_content.add_child(_height_guides)

func _build_axes() -> void:
	_axis_root = Node3D.new()
	_axis_root.name = "Axes"
	_map_content.add_child(_axis_root)
	_add_axis_line(Vector3.ZERO, Vector3(45.0, 0.0, 0.0), Color(1.0, 0.32, 0.26))
	_add_axis_line(Vector3.ZERO, Vector3(0.0, 45.0, 0.0), Color(0.35, 0.95, 0.58))
	_add_axis_line(Vector3.ZERO, Vector3(0.0, 0.0, 45.0), Color(0.32, 0.68, 1.0))
	for axis in ["X", "Y", "Z"]:
		var label := _make_label(axis, Color(0.88, 0.95, 1.0), 32, 0.07)
		match axis:
			"X": label.position = Vector3(48.0, 0.0, 0.0)
			"Y": label.position = Vector3(0.0, 48.0, 0.0)
			"Z": label.position = Vector3(0.0, 0.0, 48.0)
		_axis_root.add_child(label)

func _add_axis_line(start: Vector3, finish: Vector3, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(finish)
	mesh.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.material_override = _make_unshaded_material(color)
	_axis_root.add_child(line)

func _build_player_marker() -> void:
	_player_marker = Node3D.new()
	_player_marker.name = "PlayerMarker"
	_map_content.add_child(_player_marker)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.bottom_radius = 0.52; cone.height = 1.6
	arrow.mesh = cone
	arrow.rotation_degrees.x = -90.0
	arrow.material_override = _make_emissive_material(Color(0.3, 1.0, 0.55), 1.6)
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player_marker.add_child(arrow)
	var label := _make_label("YOU", Color(0.55, 1.0, 0.72), 34, 0.06)
	label.position = Vector3(0.0, 1.3, 0.0)
	_player_marker.add_child(label)

func _create_hud() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1
	add_child(overlay)
	_readout = Label.new()
	_readout.add_theme_color_override("font_color", Color(0.82, 0.91, 0.94))
	_readout.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_readout.add_theme_constant_override("shadow_offset_x", 1)
	_readout.add_theme_constant_override("shadow_offset_y", 1)
	_readout.size = Vector2(900.0, 32.0)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_readout)

func _make_label(text: String, color: Color, font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color(0.015, 0.025, 0.04, 0.92)
	return label

func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var created_material := StandardMaterial3D.new()
	created_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	created_material.albedo_color = color
	created_material.emission_enabled = true
	created_material.emission = color
	created_material.emission_energy_multiplier = energy
	return created_material

func _make_unshaded_material(color: Color) -> StandardMaterial3D:
	var created_material := StandardMaterial3D.new()
	created_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	created_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	created_material.albedo_color = color
	return created_material

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _sync_viewport_size() -> void:
	if _subviewport == null: return
	var viewport_size := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if _subviewport.size != viewport_size:
		_subviewport.size = viewport_size

func _update_map_origin() -> void:
	if player == null or _map_content == null: return
	var scaled_position: Vector3 = player.global_position * MAP_SCALE
	_map_content.position = -scaled_position
	_reference_grid.position = scaled_position
	_axis_root.position = scaled_position
	_player_marker.position = scaled_position
	_player_marker.basis = player.global_transform.basis.orthonormalized()

func _update_camera() -> void:
	if _camera == null: return
	var horizontal: float = cos(_camera_pitch)
	var camera_offset := Vector3(
		sin(_camera_yaw) * horizontal,
		sin(_camera_pitch),
		cos(_camera_yaw) * horizontal
	) * _camera_distance()
	_camera.position = _camera_target + camera_offset
	_camera.look_at(_camera_target, Vector3.UP)

func _camera_distance() -> float:
	return DEFAULT_CAMERA_DISTANCE / _zoom

func _update_readout() -> void:
	if player == null or _readout == null: return
	_readout.position = Vector2(14.0, size.y - 42.0)
	_readout.text = Locale.t("map.info", {
		"x": "%.0f" % player.global_position.x,
		"y": "%.0f" % player.global_position.y,
		"z": "%.0f" % player.global_position.z,
		"zoom": "%.1f" % _zoom,
		"count": _systems.size()
	})