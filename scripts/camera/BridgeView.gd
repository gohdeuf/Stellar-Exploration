class_name BridgeView
extends Node3D

const BRIDGE_GLB := "res://assets/ship/bridge.glb"
const GLB_SCALE  := 0.01
const S: float = 0.03
const CAMERA_ROLL_CORRECTION_DEG := 181.0
const BRIDGE_FOV := 70.0
const BRIDGE_WALK_SPEED := 0.035
const BRIDGE_WALK_BOUNDS := Vector3(0.045, 0.018, 0.06)

enum VScreenMode { VIEWER, TACTICAL }

const VIEWSCREEN_DIRECTIONS := [
	{"name":"front",       "yaw":0.0,   "pitch":0.0},
	{"name":"front_right", "yaw":45.0,  "pitch":0.0},
	{"name":"right",       "yaw":90.0,  "pitch":0.0},
	{"name":"back_right",  "yaw":135.0, "pitch":0.0},
	{"name":"back",        "yaw":180.0, "pitch":0.0},
	{"name":"back_left",   "yaw":225.0, "pitch":0.0},
	{"name":"left",        "yaw":270.0, "pitch":0.0},
	{"name":"front_left",  "yaw":315.0, "pitch":0.0},
	{"name":"up",          "yaw":0.0,   "pitch":-90.0},
	{"name":"front_up",    "yaw":0.0,   "pitch":-45.0},
	{"name":"down",        "yaw":0.0,   "pitch":90.0},
	{"name":"front_down",  "yaw":0.0,   "pitch":45.0},
]

signal viewscreen_direction_changed(direction_index: int, direction_name: String)

var bridge_cam:   Camera3D  = null
var is_active:    bool      = false
var _base_camera_transform: Transform3D = Transform3D.IDENTITY
var _walk_position: Vector3 = Vector3.ZERO
var _look_yaw:    float     = 0.0
var _look_pitch:  float     = 0.0

const LOOK_SENS      := 0.20
const LOOK_MAX_PITCH := 60.0
const LOOK_MAX_YAW   := 145.0

var _viewer_vp:  SubViewport    = null
var _vp_cam:     Camera3D       = null
var _viewscreen: MeshInstance3D = null
var _viewscreen_direction_index: int = 0
var _custom_viewscreen_angles: Vector2 = Vector2.ZERO
var _has_custom_viewscreen_angles := false

var _tac_vp:      SubViewport = null
var _tac_display: Node2D      = null   # ← Node2D statt TacticalDisplay (Parse-Order-Fix)

var _vscreen_mode: int              = VScreenMode.VIEWER
var _vs_mat:       ShaderMaterial = null

const VIEWSCREEN_SHADER_CODE := """
shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_texture : source_color;

void fragment() {
	vec2 rotated_uv = vec2(1.0 - UV.y, UV.x);
	vec3 screen_color = texture(screen_texture, rotated_uv).rgb;
	ALBEDO = screen_color;
	EMISSION = screen_color * 0.9;
}
"""

func _ready() -> void:
	if ResourceLoader.exists(BRIDGE_GLB):
		_load_glb()
	else:
		_build_fallback()
	_setup_viewer_vp()
	_setup_tactical_vp()
	if _viewscreen != null:
		_apply_vscreen_texture()
	visible = false

# ── GLB laden ─────────────────────────────────────────────────────────────────
func _load_glb() -> void:
	var ps: PackedScene = load(BRIDGE_GLB)
	var root: Node3D    = ps.instantiate() as Node3D
	root.scale          = Vector3.ONE * GLB_SCALE
	add_child(root)
	bridge_cam       = Camera3D.new()
	bridge_cam.near  = 0.0005
	bridge_cam.far   = 3000.0
	bridge_cam.fov   = BRIDGE_FOV
	add_child(bridge_cam)
	var mount: Node3D = _find_node(root, "CameraMount")
	if mount != null:
		var view_direction: Vector3 = -mount.global_transform.basis.z
		var upright_basis := Basis.looking_at(view_direction, Vector3.UP)
		upright_basis = upright_basis.rotated(
			view_direction.normalized(), deg_to_rad(CAMERA_ROLL_CORRECTION_DEG))
		bridge_cam.global_transform = Transform3D(upright_basis, mount.global_position)
		_base_camera_transform = bridge_cam.transform
		_walk_position = _base_camera_transform.origin
	else:
		push_warning("BridgeView: Kein 'CameraMount' in bridge.glb – Fallback-Position")
		bridge_cam.position = Vector3(0.0, S * 0.18, -S * 0.03)
		_walk_position = bridge_cam.position
	_viewscreen = _find_mesh(root, "Viewscreen")
	if _viewscreen == null:
		push_warning("BridgeView: Kein 'Viewscreen'-Mesh in bridge.glb")

# ── Außenansicht-Viewport ─────────────────────────────────────────────────────
func _setup_viewer_vp() -> void:
	_viewer_vp                           = SubViewport.new()
	_viewer_vp.size                      = _get_viewer_size()
	_viewer_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp_cam                              = Camera3D.new()
	_vp_cam.near                         = 0.5
	_vp_cam.far                          = 3000.0
	_vp_cam.fov                          = BRIDGE_FOV
	_viewer_vp.add_child(_vp_cam)
	get_tree().root.call_deferred("add_child", _viewer_vp)

func _get_viewer_size() -> Vector2i:
	if _viewscreen == null or _viewscreen.mesh == null:
		return Vector2i(720, 1280)
	var screen_size: Vector3 = _viewscreen.get_aabb().size
	var dimensions: Array[float] = [screen_size.x, screen_size.y, screen_size.z]
	dimensions.sort()
	var screen_height: float = max(dimensions[1], 0.001)
	var screen_width: float = max(dimensions[2], screen_height)
	var aspect: float = clamp(screen_width / screen_height, 1.0, 16.0 / 9.0)
	return Vector2i(720, roundi(720.0 * aspect))

# ── Taktik-Viewport ───────────────────────────────────────────────────────────
func _setup_tactical_vp() -> void:
	_tac_vp                           = SubViewport.new()
	_tac_vp.size                      = Vector2i(512, 512)
	_tac_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# TacticalDisplay als Node2D instanzieren – kein Typ-Annotation-Problem
	_tac_display = TacticalDisplay.new()
	_tac_vp.add_child(_tac_display)
	get_tree().root.call_deferred("add_child", _tac_vp)

func set_ship_ref(s: Node3D) -> void:
	# Methodenaufruf via call() – kein Cast auf custom type nötig
	if _tac_display != null and _tac_display.has_method("set_ship"):
		_tac_display.call("set_ship", s)

func set_viewscreen_direction(direction: Variant) -> bool:
	var index := -1
	if direction is int:
		index = int(direction)
	elif direction is String:
		for i in range(VIEWSCREEN_DIRECTIONS.size()):
			if VIEWSCREEN_DIRECTIONS[i]["name"] == direction:
				index = i
				break
	if index < 0 or index >= VIEWSCREEN_DIRECTIONS.size(): return false
	_viewscreen_direction_index = index
	_has_custom_viewscreen_angles = false
	_update_viewer_camera()
	viewscreen_direction_changed.emit(index, get_viewscreen_direction_name())
	return true

func cycle_viewscreen_direction(step: int = 1) -> void:
	var count: int = VIEWSCREEN_DIRECTIONS.size()
	_viewscreen_direction_index = posmod(_viewscreen_direction_index + step, count)
	_has_custom_viewscreen_angles = false
	_update_viewer_camera()
	viewscreen_direction_changed.emit(
		_viewscreen_direction_index, get_viewscreen_direction_name())

func set_viewscreen_angles(yaw_deg: float, pitch_deg: float) -> void:
	_custom_viewscreen_angles = Vector2(yaw_deg, clamp(pitch_deg, -90.0, 90.0))
	_has_custom_viewscreen_angles = true
	_update_viewer_camera()

func get_viewscreen_direction_index() -> int:
	return _viewscreen_direction_index

func get_viewscreen_direction_name() -> String:
	return String(VIEWSCREEN_DIRECTIONS[_viewscreen_direction_index]["name"])

func get_bridge_look_angles() -> Vector2:
	return Vector2(_look_yaw, _look_pitch)

func get_viewscreen_look_angles() -> Vector2:
	return _get_viewscreen_angles()

func _get_viewscreen_angles() -> Vector2:
	if _has_custom_viewscreen_angles: return _custom_viewscreen_angles
	var preset: Dictionary = VIEWSCREEN_DIRECTIONS[_viewscreen_direction_index]
	return Vector2(float(preset["yaw"]), float(preset["pitch"]))

func _update_viewer_camera() -> void:
	if _vp_cam == null: return
	var angles := _get_viewscreen_angles()
	var view_basis := Basis(Vector3.UP, deg_to_rad(angles.x))
	view_basis *= Basis(Vector3.RIGHT, deg_to_rad(angles.y))
	var local_view := Transform3D(_base_camera_transform.basis * view_basis,
		_base_camera_transform.origin)
	_vp_cam.global_transform = global_transform * local_view

# ── Viewscreen-Material ───────────────────────────────────────────────────────
func _apply_vscreen_texture() -> void:
	var shader := Shader.new()
	shader.code = VIEWSCREEN_SHADER_CODE
	_vs_mat = ShaderMaterial.new()
	_vs_mat.shader = shader
	_vs_mat.set_shader_parameter("screen_texture", _viewer_vp.get_texture())
	_viewscreen.material_override      = _vs_mat

func _toggle_vscreen_mode() -> void:
	if _vs_mat == null or _viewscreen == null: return
	if _vscreen_mode == VScreenMode.VIEWER:
		_vscreen_mode                        = VScreenMode.TACTICAL
		_viewer_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_tac_vp.render_target_update_mode    = SubViewport.UPDATE_ALWAYS
		_vs_mat.set_shader_parameter("screen_texture", _tac_vp.get_texture())
	else:
		_vscreen_mode                        = VScreenMode.VIEWER
		_tac_vp.render_target_update_mode    = SubViewport.UPDATE_DISABLED
		_viewer_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vs_mat.set_shader_parameter("screen_texture", _viewer_vp.get_texture())

# ── Aktivierung ───────────────────────────────────────────────────────────────
func activate(follow_cam: Camera3D) -> void:
	visible            = true
	is_active          = true
	follow_cam.current = false
	bridge_cam.current = true
	_look_yaw          = 0.0
	_look_pitch        = 0.0
	_walk_position     = _base_camera_transform.origin
	get_parent().set_meta("bridge_walk_active", true)
	_viewer_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func deactivate(follow_cam: Camera3D) -> void:
	visible            = false
	is_active          = false
	bridge_cam.current = false
	get_parent().set_meta("bridge_walk_active", false)
	follow_cam.current = true
	_viewer_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if _vscreen_mode == VScreenMode.TACTICAL:
		_tac_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ── Input: Maus-Freiblick ─────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return
	if event is InputEventMouseMotion:
		var me: InputEventMouseMotion = event as InputEventMouseMotion
		_look_yaw   = clamp(_look_yaw   - me.relative.x * LOOK_SENS, -LOOK_MAX_YAW,   LOOK_MAX_YAW)
		_look_pitch = clamp(_look_pitch - me.relative.y * LOOK_SENS, -LOOK_MAX_PITCH, LOOK_MAX_PITCH)
	if event.is_action_pressed("toggle_vscreen"): _toggle_vscreen_mode()
	if event.is_action_pressed("next_vscreen_direction"):
		cycle_viewscreen_direction()
	if event.is_action_pressed("previous_vscreen_direction"):
		cycle_viewscreen_direction(-1)
	if event.is_action_pressed("look_reset"):     _look_yaw = 0.0; _look_pitch = 0.0

func _process(_delta: float) -> void:
	if bridge_cam == null: return
	if is_active:
		_process_bridge_walk(_delta)
	var look_basis := Basis(Vector3.UP, deg_to_rad(_look_yaw))
	look_basis *= Basis(Vector3.RIGHT, deg_to_rad(_look_pitch))
	var camera_base := _base_camera_transform
	camera_base.origin = _walk_position
	bridge_cam.transform = camera_base * Transform3D(look_basis, Vector3.ZERO)
	if _vp_cam != null and is_active:
		_update_viewer_camera()

func _process_bridge_walk(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_action_pressed("move_forward"): direction -= Vector3.FORWARD
	if Input.is_action_pressed("move_back"):    direction += Vector3.FORWARD
	if Input.is_action_pressed("move_left"):    direction -= Vector3.RIGHT
	if Input.is_action_pressed("move_right"):   direction += Vector3.RIGHT
	if Input.is_action_pressed("move_up"):      direction += Vector3.UP
	if Input.is_action_pressed("move_down"):    direction -= Vector3.UP
	if direction.length_squared() == 0.0: return
	_walk_position += direction.normalized() * BRIDGE_WALK_SPEED * delta
	var minimum := _base_camera_transform.origin - BRIDGE_WALK_BOUNDS
	var maximum := _base_camera_transform.origin + BRIDGE_WALK_BOUNDS
	_walk_position.x = clamp(_walk_position.x, minimum.x, maximum.x)
	_walk_position.y = clamp(_walk_position.y, minimum.y, maximum.y)
	_walk_position.z = clamp(_walk_position.z, minimum.z, maximum.z)

# ── Aufräumen ─────────────────────────────────────────────────────────────────
func _exit_tree() -> void:
	if _viewer_vp != null and is_instance_valid(_viewer_vp) and _viewer_vp.is_inside_tree():
		_viewer_vp.queue_free()
	if _tac_vp != null and is_instance_valid(_tac_vp) and _tac_vp.is_inside_tree():
		_tac_vp.queue_free()
	_viewer_vp = null; _tac_vp = null; _vp_cam = null; _tac_display = null

# ── Primitiv-Fallback ─────────────────────────────────────────────────────────
func _build_fallback() -> void:
	bridge_cam          = Camera3D.new()
	bridge_cam.position = Vector3(0.0, S * 0.18, -S * 0.03)
	bridge_cam.near     = 0.0005
	bridge_cam.far      = 3000.0
	bridge_cam.fov      = BRIDGE_FOV
	add_child(bridge_cam)
	_base_camera_transform = bridge_cam.transform
	var mat_hull  := _solid(Color(0.07, 0.09, 0.13), 0.75)
	var mat_panel := _solid(Color(0.11, 0.14, 0.20), 0.70)
	var mat_glow  := _emissive(Color(0.04, 0.26, 0.78), 3.5)
	var mat_edge  := _emissive(Color(0.00, 0.45, 0.85), 2.0)
	_box(Vector3(S*1.9, S*0.05, S*1.6),  Vector3(0,       -S*0.20,  S*0.05), mat_hull)
	_box(Vector3(S*1.9, S*0.05, S*1.6),  Vector3(0,        S*0.72,  S*0.05), mat_hull)
	_box(Vector3(S*0.05,S*0.92, S*1.6),  Vector3(-S*0.95,  S*0.26,  S*0.05), mat_hull)
	_box(Vector3(S*0.05,S*0.92, S*1.6),  Vector3( S*0.95,  S*0.26,  S*0.05), mat_hull)
	_box(Vector3(S*1.9, S*0.92, S*0.05), Vector3(0,         S*0.26,  S*0.85), mat_hull)
	_box(Vector3(S*1.72,S*0.34, S*0.42), Vector3(0,        -S*0.03, -S*0.44), mat_panel)
	# Viewscreen-Rahmen
	_box(Vector3(S*1.9, S*0.09, S*0.05), Vector3(0,         S*0.64, -S*0.86), mat_hull)
	_box(Vector3(S*0.05,S*0.70, S*0.05), Vector3(-S*0.90,   S*0.29, -S*0.86), mat_hull)
	_box(Vector3(S*0.05,S*0.70, S*0.05), Vector3( S*0.90,   S*0.29, -S*0.86), mat_hull)
	_box(Vector3(S*1.9, S*0.05, S*0.05), Vector3(0,        -S*0.06, -S*0.86), mat_hull)
	# Viewscreen-Leinwand
	var vs := MeshInstance3D.new()
	var vsm := BoxMesh.new(); vsm.size = Vector3(S*1.78, S*0.68, S*0.01)
	vs.mesh = vsm; vs.position = Vector3(0.0, S*0.29, -S*0.855)
	add_child(vs); _viewscreen = vs
	# Randbeleuchtung
	_box(Vector3(S*1.82,S*0.02,S*0.02), Vector3(0,  S*0.59,-S*0.87), mat_edge)
	_box(Vector3(S*1.82,S*0.02,S*0.02), Vector3(0, -S*0.03,-S*0.87), mat_edge)
	for sx: float in [-0.55, 0.0, 0.55]:
		_box(Vector3(S*0.42,S*0.03,S*0.38), Vector3(sx*S*1.1, S*0.14,-S*0.44), mat_glow)
	for lx: float in [-0.5, 0.0, 0.5]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.72, 0.86, 1.0)
		l.omni_range  = S * 2.8; l.light_energy = 0.55
		l.position    = Vector3(lx * S * 0.8, S * 0.64, S * 0.1)
		add_child(l)

func _solid(color: Color, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.metallic = metallic; return m

func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color
	m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = energy; return m

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos; add_child(mi)

func _find_node(root: Node, search: String) -> Node3D:
	if root.name == search and root is Node3D: return root as Node3D
	for c in root.get_children():
		var f: Node3D = _find_node(c, search)
		if f != null: return f
	return null

func _find_mesh(root: Node, search: String) -> MeshInstance3D:
	if root.name == search and root is MeshInstance3D: return root as MeshInstance3D
	for c in root.get_children():
		var f: MeshInstance3D = _find_mesh(c, search)
		if f != null: return f
	return null