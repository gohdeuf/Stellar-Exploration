class_name BridgeView
extends Node3D

const BRIDGE_GLB := "res://assets/ship/bridge.glb"
const GLB_SCALE  := 0.01
const S: float = 0.03

enum VScreenMode { VIEWER, TACTICAL }

var bridge_cam:   Camera3D  = null
var is_active:    bool      = false
var _look_yaw:    float     = 0.0
var _look_pitch:  float     = 0.0

const LOOK_SENS      := 0.20
const LOOK_MAX_PITCH := 60.0
const LOOK_MAX_YAW   := 145.0

var _viewer_vp:  SubViewport    = null
var _vp_cam:     Camera3D       = null
var _viewscreen: MeshInstance3D = null

var _tac_vp:      SubViewport = null
var _tac_display: Node2D      = null   # ← Node2D statt TacticalDisplay (Parse-Order-Fix)

var _vscreen_mode: int              = VScreenMode.VIEWER
var _vs_mat:       StandardMaterial3D = null

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
	bridge_cam.fov   = 90.0
	add_child(bridge_cam)
	var mount: Node3D = _find_node(root, "CameraMount")
	if mount != null:
		bridge_cam.global_position = mount.global_position
		bridge_cam.global_rotation = mount.global_rotation
	else:
		push_warning("BridgeView: Kein 'CameraMount' in bridge.glb – Fallback-Position")
		bridge_cam.position = Vector3(0.0, S * 0.18, -S * 0.03)
	_viewscreen = _find_mesh(root, "Viewscreen")
	if _viewscreen == null:
		push_warning("BridgeView: Kein 'Viewscreen'-Mesh in bridge.glb")

# ── Außenansicht-Viewport ─────────────────────────────────────────────────────
func _setup_viewer_vp() -> void:
	_viewer_vp                           = SubViewport.new()
	_viewer_vp.size                      = Vector2i(1280, 720)
	_viewer_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vp_cam                              = Camera3D.new()
	_vp_cam.near                         = 0.5
	_vp_cam.far                          = 3000.0
	_vp_cam.fov                          = 90.0
	_viewer_vp.add_child(_vp_cam)
	get_tree().root.call_deferred("add_child", _viewer_vp)

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

# ── Viewscreen-Material ───────────────────────────────────────────────────────
func _apply_vscreen_texture() -> void:
	_vs_mat                            = StandardMaterial3D.new()
	_vs_mat.albedo_texture             = _viewer_vp.get_texture()
	_vs_mat.emission_enabled           = true
	_vs_mat.emission_texture           = _viewer_vp.get_texture()
	_vs_mat.emission_energy_multiplier = 0.9
	_viewscreen.material_override      = _vs_mat

func _toggle_vscreen_mode() -> void:
	if _vs_mat == null or _viewscreen == null: return
	if _vscreen_mode == VScreenMode.VIEWER:
		_vscreen_mode                        = VScreenMode.TACTICAL
		_viewer_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_tac_vp.render_target_update_mode    = SubViewport.UPDATE_ALWAYS
		_vs_mat.albedo_texture               = _tac_vp.get_texture()
		_vs_mat.emission_texture             = _tac_vp.get_texture()
	else:
		_vscreen_mode                        = VScreenMode.VIEWER
		_tac_vp.render_target_update_mode    = SubViewport.UPDATE_DISABLED
		_viewer_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vs_mat.albedo_texture               = _viewer_vp.get_texture()
		_vs_mat.emission_texture             = _viewer_vp.get_texture()

# ── Aktivierung ───────────────────────────────────────────────────────────────
func activate(follow_cam: Camera3D) -> void:
	visible            = true
	is_active          = true
	follow_cam.current = false
	bridge_cam.current = true
	_look_yaw          = 0.0
	_look_pitch        = 0.0
	_viewer_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func deactivate(follow_cam: Camera3D) -> void:
	visible            = false
	is_active          = false
	bridge_cam.current = false
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
	if event.is_action_pressed("look_reset"):     _look_yaw = 0.0; _look_pitch = 0.0

func _process(_delta: float) -> void:
	if bridge_cam == null: return
	bridge_cam.rotation_degrees = Vector3(_look_pitch, _look_yaw, 0.0)
	if _vp_cam != null and is_active:
		_vp_cam.global_transform = bridge_cam.global_transform

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
	bridge_cam.fov      = 90.0
	add_child(bridge_cam)
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