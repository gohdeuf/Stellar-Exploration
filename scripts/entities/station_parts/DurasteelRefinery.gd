class_name DurasteelRefinery
extends Node3D

const VISUAL_SCALE := 0.1
const REFINING_RATE := 0.1
const MINERALS_PER_DURASTEEL := 25.0
const HYDROGEN_PER_DURASTEEL := 10.0
const REQUIRED_POWER := 75.0
const FULL_POWER := 150.0
const POWER_RANGE := 200.0
const SID_REFRESH := 5.0
const PRODUCTION_TICK := 1.0

var is_enabled: bool = true

var _sid_timer: float = 0.0
var _production_timer: float = 0.0
var _cached_sid: String = ""
var _pulse_time: float = 0.0
var _active: bool = false
var _furnace_mat: StandardMaterial3D
var _furnace_light: OmniLight3D

func _ready() -> void:
	scale = Vector3.ONE * VISUAL_SCALE
	add_to_group("stations")
	add_to_group("durasteel_refineries")
	_build_visual()

func _process(delta: float) -> void:
	_sid_timer -= delta
	if _sid_timer <= 0.0:
		_sid_timer = SID_REFRESH
		_cached_sid = _find_station_sid()

	_pulse_time += delta
	_production_timer += delta
	if _production_timer < PRODUCTION_TICK:
		_update_visuals()
		return

	var production_delta := _production_timer - fmod(_production_timer, PRODUCTION_TICK)
	_production_timer = fmod(_production_timer, PRODUCTION_TICK)
	_active = false
	if is_enabled and _cached_sid != "":
		var power := _find_nearby_power()
		if power >= REQUIRED_POWER:
			var efficiency := clampf(power / FULL_POWER, 0.0, 1.0)
			var possible_output := REFINING_RATE * efficiency * production_delta
			var storage: Dictionary = GameDatabase.get_station_storage(_cached_sid)
			var output := minf(possible_output, float(storage.get("minerals", 0.0)) / MINERALS_PER_DURASTEEL)
			output = minf(output, float(storage.get("hydrogen", 0.0)) / HYDROGEN_PER_DURASTEEL)
			if output > 0.0:
				_active = GameDatabase.refine_station_durasteel(
					_cached_sid,
					MINERALS_PER_DURASTEEL * output,
					HYDROGEN_PER_DURASTEEL * output,
					output
				)

	_update_visuals()

func _build_visual() -> void:
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.38, 0.42, 0.46)
	hull.metallic = 0.8
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(10.0, 8.0, 14.0)
	frame.mesh = frame_mesh
	frame.material_override = hull
	add_child(frame)

	var furnace := MeshInstance3D.new()
	var furnace_mesh := CylinderMesh.new()
	furnace_mesh.top_radius = 2.4
	furnace_mesh.bottom_radius = 2.8
	furnace_mesh.height = 6.0
	furnace.mesh = furnace_mesh
	_furnace_mat = StandardMaterial3D.new()
	_furnace_mat.albedo_color = Color(1.0, 0.32, 0.06)
	_furnace_mat.emission_enabled = true
	_furnace_mat.emission = Color(1.0, 0.18, 0.02)
	_furnace_mat.emission_energy_multiplier = 0.15
	furnace.material_override = _furnace_mat
	add_child(furnace)

	for side in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.5, 10.0, 15.0)
		rail.mesh = rail_mesh
		rail.material_override = hull
		rail.position.x = float(side) * 5.2
		add_child(rail)

	_furnace_light = OmniLight3D.new()
	_furnace_light.light_color = Color(1.0, 0.28, 0.04)
	_furnace_light.omni_range = 2.4
	_furnace_light.light_energy = 0.0
	add_child(_furnace_light)

func _update_visuals() -> void:
	var glow := 1.2 + sin(_pulse_time * 3.0) * 0.35 if _active else 0.1
	_furnace_mat.emission_energy_multiplier = glow
	_furnace_light.light_energy = glow * 0.6

func _find_nearby_power() -> float:
	var total := 0.0
	for node in get_tree().get_nodes_in_group("fusion_cores"):
		if not node is FusionCore:
			continue
		if global_position.distance_to(node.global_position) <= POWER_RANGE:
			total += (node as FusionCore).power_output
	return total

func _find_station_sid() -> String:
	var parent: Node = get_parent()
	while parent != null:
		if parent.is_in_group("station_orbiters"):
			return str(parent.get("orbit_id"))
		parent = parent.get_parent()

	var best: Node3D
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("main_station_parts"):
		var distance := global_position.distance_to(node.global_position)
		if distance < POWER_RANGE and distance < best_dist:
			best = node
			best_dist = distance
	if best == null:
		return ""
	return GameDatabase.get_station_id(best.global_position)
