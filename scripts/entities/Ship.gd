class_name Ship
extends Node3D

const SAUCER_RADIUS := 0.03

const DEFAULT_SPEED          := 150.0
const DEFAULT_ROTATION_SPEED := 100.0
const BOOST_MULTIPLIER       := 3.0

@export var speed: float              = DEFAULT_SPEED
@export var rotation_speed_deg: float = DEFAULT_ROTATION_SPEED

var _weapon_system: WeaponSystem = null
var _warp_drive:    WarpDrive    = null
var _crew_system:   CrewSystem   = null
var _shield_system: ShieldSystem = null
var _health: float = 1000.0
var _max_health: float = 1000.0
var engine_enabled: bool = true
var engine_power: float = 1.0

var _orbit_carrier:    Node3D  = null
var _last_carrier_pos: Vector3 = Vector3.ZERO
var _smooth_carry:     Vector3 = Vector3.ZERO

func set_orbit_carrier(body: Node3D) -> void:
	_orbit_carrier = body
	if body != null and is_instance_valid(body):
		_last_carrier_pos = body.global_position
		_smooth_carry = Vector3.ZERO

func _apply_orbit_carry() -> void:
	if _warp_drive != null and _warp_drive.is_active():
		return
	if _orbit_carrier == null or not is_instance_valid(_orbit_carrier):
		_orbit_carrier = null
		_smooth_carry = Vector3.ZERO
		return
	var body_delta: Vector3 = _orbit_carrier.global_position - _last_carrier_pos
	_last_carrier_pos = _orbit_carrier.global_position
	# Glättung um das Wackeln in Planetennähe deutlich zu reduzieren
	_smooth_carry = _smooth_carry.lerp(body_delta, 0.4)
	global_position += _smooth_carry

func _ready() -> void:
	add_to_group("player_ship")
	_build_model()
	global_position = GameDatabase.player_position
	quaternion      = GameDatabase.player_rotation
	add_to_group("player_ship")

func init_systems(weapon_sys: WeaponSystem, warp_drv: WarpDrive, crew_sys: CrewSystem, shield_sys: ShieldSystem = null) -> void:
	_weapon_system = weapon_sys
	_warp_drive = warp_drv
	_crew_system = crew_sys
	_shield_system = shield_sys
	set_meta("shield_system", shield_sys)
	
	# Sucht das eben generierte Mesh und übergibt es dem ShieldSystem
	if _shield_system != null and has_node("ShieldMesh"):
		_shield_system.shield_mesh = get_node("ShieldMesh") as MeshInstance3D
		_shield_system._update_mesh_visibility()


func set_engine_enabled(enabled: bool) -> void:
	engine_enabled = enabled

func set_engine_power(power: float) -> void:
	engine_power = clampf(power, 0.0, 1.0)

func get_engine_status() -> Dictionary:
	return {"enabled": engine_enabled, "power": engine_power, "speed": speed * engine_power}

func get_hull_status() -> Dictionary:
	return {"health": _health, "max_health": _max_health}

func set_warp_enabled(enabled: bool) -> bool:
	if _warp_drive == null: return false
	return _warp_drive.set_active(enabled)

func toggle_warp() -> bool:
	if _warp_drive == null: return false
	return _warp_drive.toggle_active()

func get_warp_status() -> Dictionary:
	return {"active": _warp_drive != null and _warp_drive.is_active()}

func select_weapon(weapon: int) -> bool:
	return _weapon_system != null and _weapon_system.select_weapon(weapon)

func cycle_weapon(step: int = 1) -> int:
	if _weapon_system == null: return -1
	return _weapon_system.cycle_weapon(step)

func fire_weapon() -> bool:
	return _weapon_system != null and _weapon_system.fire_weapon()

func get_weapon_status() -> Dictionary:
	if _weapon_system == null: return {"weapon": -1}
	return {"weapon": _weapon_system.active_weapon}

func set_shield_enabled(enabled: bool) -> void:
	if _shield_system != null:
		_shield_system.set_active(enabled)

func get_shield_status() -> Dictionary:
	if _shield_system == null: return {"active": false, "integrity": 0.0, "max_integrity": 0.0}
	return _shield_system.get_status()


func _physics_process(delta: float) -> void:
	if bool(get_meta("bridge_walk_active", false)):
		return
	_apply_orbit_carry()
	if _crew_system != null and _crew_system.emergency_ai_active:
		return
	if _warp_drive != null and _warp_drive.is_active():
		return
	if StationEditor.is_editor_open:
		return
	_handle_movement(delta)
	_handle_rotation(delta)

func _handle_movement(delta: float) -> void:
	if not engine_enabled or engine_power <= 0.0: return
	var speed_mult: float = 1.0
	if _crew_system != null:
		speed_mult = _crew_system.speed_modifier
	var boost: float = BOOST_MULTIPLIER if Input.is_action_pressed("boost") else 1.0
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		dir += transform.basis.x
	if Input.is_action_pressed("move_up"):
		dir += transform.basis.y
	if Input.is_action_pressed("move_down"):
		dir -= transform.basis.y
	if dir.length() > 0.0:
		global_position += dir.normalized() * speed * engine_power * speed_mult * boost * delta

func _handle_rotation(delta: float) -> void:
	var rot_mult: float = 1.0
	if _crew_system != null:
		rot_mult = _crew_system.rotation_modifier
	var rot: float = deg_to_rad(rotation_speed_deg * rot_mult * delta)
	if Input.is_action_pressed("pitch_up"):
		rotate_object_local(Vector3.RIGHT, rot)
	if Input.is_action_pressed("pitch_down"):
		rotate_object_local(Vector3.RIGHT, -rot)
	if Input.is_action_pressed("yaw_left"):
		rotate_object_local(Vector3.UP, rot)
	if Input.is_action_pressed("yaw_right"):
		rotate_object_local(Vector3.UP, -rot)
	if Input.is_action_pressed("roll_left"):
		rotate_object_local(Vector3.FORWARD, rot)
	if Input.is_action_pressed("roll_right"):
		rotate_object_local(Vector3.FORWARD, -rot)

func _build_model() -> void:
	var s := SAUCER_RADIUS

	var saucer := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = s
	sm.height = s * 0.4
	saucer.mesh = sm
	saucer.scale = Vector3(1.0, 0.20, 1.0)
	saucer.position = Vector3(0.0, s * 0.06, 0.0)
	add_child(saucer)

	var neck := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(s * 0.28, s * 0.22, s * 0.50)
	neck.mesh = nm
	neck.position = Vector3(0.0, -s * 0.10, s * 0.55)
	add_child(neck)

	var hull := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(s * 0.52, s * 0.34, s * 0.88)
	hull.mesh = hm
	hull.position = Vector3(0.0, -s * 0.16, s * 1.08)
	add_child(hull)

	for side in [-1, 1]:
		var pylon := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(s * 0.30, s * 0.10, s * 0.44)
		pylon.mesh = pm
		pylon.position = Vector3(float(side) * s * 0.72, -s * 0.05, s * 0.74)
		add_child(pylon)

	for side in [-1, 1]:
		var nac := MeshInstance3D.new()
		var ncm := CylinderMesh.new()
		ncm.top_radius = s * 0.12
		ncm.bottom_radius = s * 0.12
		ncm.height = s * 1.55
		nac.mesh = ncm
		nac.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		nac.position = Vector3(float(side) * s * 0.86, -s * 0.04, s * 1.08)
		add_child(nac)

		var bussard := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = s * 0.13
		bm.height = s * 0.26
		bussard.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.90, 0.08, 0.04)
		bmat.emission_enabled = true
		bmat.emission = Color(0.80, 0.04, 0.02)
		bmat.emission_energy_multiplier = 2.5
		bussard.material_override = bmat
		bussard.position = Vector3(float(side) * s * 0.86, -s * 0.04, s * 0.33)
		add_child(bussard)

		var gmat := StandardMaterial3D.new()
		gmat.emission_enabled = true
		gmat.emission = Color(0.55, 0.80, 1.0)
		gmat.emission_energy_multiplier = 4.5
		gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for stripe_angle in [0.0, PI]:
			add_child(_create_glow_stripe(float(side), stripe_angle, s, gmat))

	var defl := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = s * 0.20
	dm.height = s * 0.0
	defl.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.15, 0.35, 0.90)
	dmat.emission_enabled = true
	dmat.emission = Color(0.10, 0.25, 0.85)
	dmat.emission_energy_multiplier = 2.5
	defl.material_override = dmat
	defl.position = Vector3(0.0, -s * 0.18, s * 0.64)
	add_child(defl)

		# --- VISUELLES SCHILDSYSTEM HIER HINZUFÜGEN ---
	var shield_mesh := MeshInstance3D.new()
	shield_mesh.name = "ShieldMesh"
	
	var sm_shield := SphereMesh.new()
	# Mathematisch angepasst an deine Schiff-Proportionen (umschließt Untertasse und Gondeln)
	sm_shield.radius = s * 1.8 
	sm_shield.height = s * 3.6
	shield_mesh.mesh = sm_shield
	
	# Verschiebung zur Mitte des Rumpfes (Z-Achse nach hinten verschoben wegen den Gondeln)
	shield_mesh.position = Vector3(0.0, -s * 0.05, s * 0.8)
	
	# Erstellung des ShaderMaterials direkt über Code
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://assets/ship/shader/plasma_shield.gdshader") # Pfad zu deinem Shader-File
	shield_mesh.material_override = shader_mat
	
	add_child(shield_mesh)
	
	# Falls das Schildsystem bereits initialisiert wurde, verknüpfen wir das Mesh sofort
	if _shield_system != null:
		_shield_system.shield_mesh = shield_mesh
		_shield_system._update_mesh_visibility()


func _create_glow_stripe(side: float, angle: float, s: float, material: StandardMaterial3D) -> MeshInstance3D:
	var radial := Vector3(cos(angle), sin(angle), 0.0)
	var tangent := Vector3(-sin(angle), cos(angle), 0.0)
	var z_positions: Array[float] = [s * 0.33, s * 0.485, s * 1.83]
	var widths: Array[float] = [s * 0.30, s * 0.01, s * 0.01]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(z_positions.size()):
		var center := Vector3(side * s * 0.86, -s * 0.04, z_positions[i]) + radial * (s * 0.122)
		vertices.append(center - tangent * widths[i] * 0.5)
		vertices.append(center + tangent * widths[i] * 0.5)
		normals.append(radial)
		normals.append(radial)
	var indices := PackedInt32Array([0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var stripe_mesh := ArrayMesh.new()
	stripe_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var stripe := MeshInstance3D.new()
	stripe.mesh = stripe_mesh
	stripe.material_override = material
	return stripe

func take_damage(amount: float) -> void:
	if _shield_system != null and _shield_system.is_active and _shield_system.integrity > 0.0:
		# Schild ist aktiv, aber Torpedos durchdringen es nicht (intercept_torpedo wird vorher geprüft)
		# Diese Methode wird für direkten Schaden genutzt
		pass
	_health -= amount
	if _health <= 0.0:
		_health = 0.0
		# Optional: Spieler zerstört / Respawn