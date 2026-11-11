class_name MiningDrill
extends Node3D

const VISUAL_SCALE      := 0.1
const MINING_RANGE     := 150.0   # Ideal für Orbitalstation
const MINERAL_RATE     := 6.0     # Einheiten/Sek
const DEUTERIUM_RATE   := 2.5
const TICK_INTERVAL    := 3.0
const SID_REFRESH      := 5.0

var is_enabled: bool = true

var _tick_timer: float = 0.0
var _sid_timer:  float = 0.0
var _cached_sid: String = ""
var _arm_pivot:  Node3D = null
var _drill_mat:  StandardMaterial3D = null
var _status_light: OmniLight3D = null

func _ready() -> void:
	scale = Vector3.ONE * VISUAL_SCALE
	add_to_group("stations")
	add_to_group("mining_drills")
	_build_visual()

func _build_visual() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.4, 0.42, 0.46); steel.metallic = 0.85

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new(); bm.top_radius = 3.5; bm.bottom_radius = 3.5; bm.height = 1.0
	base.mesh = bm; base.material_override = steel; add_child(base)

	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.55; cm.bottom_radius = 0.75; cm.height = 5.0
	col.mesh = cm; col.material_override = steel; col.position.y = 3.0; add_child(col)

	_arm_pivot = Node3D.new(); _arm_pivot.position.y = 5.6; add_child(_arm_pivot)

	var arm := MeshInstance3D.new()
	var am := BoxMesh.new(); am.size = Vector3(6.0, 0.35, 0.35); arm.mesh = am
	arm.material_override = steel; arm.position.x = 3.0; _arm_pivot.add_child(arm)

	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new(); hm.top_radius = 0.15; hm.bottom_radius = 0.55; hm.height = 1.4
	head.mesh = hm
	_drill_mat = StandardMaterial3D.new()
	_drill_mat.albedo_color = Color(0.85, 0.65, 0.05)
	_drill_mat.emission_enabled = true; _drill_mat.emission = Color(0.7, 0.45, 0.0)
	_drill_mat.emission_energy_multiplier = 0.5
	head.material_override = _drill_mat
	head.position = Vector3(6.5, -0.6, 0.0)
	_arm_pivot.add_child(head)

	_status_light = OmniLight3D.new()
	_status_light.light_color = Color(0.9, 0.65, 0.1)
	_status_light.omni_range = 1.8; _status_light.light_energy = 0.0
	add_child(_status_light)

func _process(delta: float) -> void:
	_sid_timer -= delta
	if _sid_timer <= 0.0:
		_sid_timer = SID_REFRESH
		_cached_sid = _find_station_sid()

	var nearby: bool = _has_nearby_planet()
	var running: bool = is_enabled and _cached_sid != "" and nearby

	if _arm_pivot != null:
		_arm_pivot.rotate_y(deg_to_rad((20.0 if running else 2.0) * delta))
	if _drill_mat != null:
		_drill_mat.emission_energy_multiplier = 2.5 if running else 0.1
	if _status_light != null:
		_status_light.light_energy = 1.5 if running else 0.0

	if not running: return
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer = 0.0
		_do_mining()

func _do_mining() -> void:
	if _cached_sid == "": return
	for node in get_tree().get_nodes_in_group("planets"):
		if not node is Planet: continue
		var planet: Planet = node as Planet
		if global_position.distance_to(planet.global_position) > MINING_RANGE: continue
		var res: Dictionary = planet.planet_data["resources"]
		var take_min: float = minf(MINERAL_RATE * TICK_INTERVAL, res["current"])
		if take_min > 0.0:
			res["current"] -= take_min
			GameDatabase.add_station_resource(_cached_sid, "minerals", take_min)
		if planet.planet_data.has("deuterium"):
			var deu: Dictionary = planet.planet_data["deuterium"]
			var take_deu: float = minf(DEUTERIUM_RATE * TICK_INTERVAL, deu["current"])
			if take_deu > 0.0:
				deu["current"] -= take_deu
				GameDatabase.add_station_resource(_cached_sid, "deuterium", take_deu)
		return  # nur nächsten Planeten

func _has_nearby_planet() -> bool:
	for node in get_tree().get_nodes_in_group("planets"):
		if not node is Planet: continue
		if global_position.distance_to(node.global_position) <= MINING_RANGE:
			return true
	return false

func _find_station_sid() -> String:
	var parent: Node = get_parent()
	while parent != null:
		if parent.is_in_group("station_orbiters"):
			return str(parent.get("orbit_id"))
		parent = parent.get_parent()
	var best: Node3D = null; var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("main_station_parts"):
		var dist: float = global_position.distance_to(node.global_position)
		if dist < 500.0 and dist < best_dist: best = node; best_dist = dist
	if best == null: return ""
	return GameDatabase.get_station_id(best.global_position)