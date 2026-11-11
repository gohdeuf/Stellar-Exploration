class_name AntimatterFactorySmall
extends Node3D

const AM_BASE_RATE    := 0.2
const REQUIRED_POWER  := 50.0
const FULL_POWER      := 100.0
const POWER_RANGE     := 200.0
const AM_DEU_COST     := 2.5
const MAX_STAR_BONUS  := 3.0
const SID_REFRESH     := 5.0

var is_enabled: bool = true   # Toggle via StationManagement
var _deu_debt:   float = 0.0
var _pulse_time: float = 0.0
var _sid_timer:  float = 0.0
var _cached_sid: String = ""
var _chamber_light: OmniLight3D        = null
var _chamber_mat:   StandardMaterial3D = null
var _active: bool = false

func _ready() -> void:
	add_to_group("stations"); add_to_group("am_factories"); _build_visual()

func _build_visual() -> void:
	var mat_silver := StandardMaterial3D.new(); mat_silver.albedo_color = Color(0.6,0.65,0.7); mat_silver.metallic = 0.85
	for side in [-1, 1]:
		var cyl := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius=0.7; cm.bottom_radius=0.7; cm.height=6.0; cyl.mesh=cm
		cyl.material_override = mat_silver; cyl.position = Vector3(float(side)*1.8,0.0,0.0); add_child(cyl)
	for z in [-2.0, 0.0, 2.0]:
		var bridge := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size=Vector3(4.2,0.5,0.6); bridge.mesh=bm
		bridge.material_override = mat_silver; bridge.position = Vector3(0,0,z); add_child(bridge)
	var chamber := MeshInstance3D.new(); var csm := SphereMesh.new(); csm.radius=0.9; csm.height=1.8; chamber.mesh=csm
	_chamber_mat = StandardMaterial3D.new(); _chamber_mat.albedo_color=Color(0.0,0.9,1.0)
	_chamber_mat.emission_enabled=true; _chamber_mat.emission=Color(0.0,0.8,1.0); _chamber_mat.emission_energy_multiplier=0.5
	chamber.material_override = _chamber_mat; add_child(chamber)
	_chamber_light = OmniLight3D.new(); _chamber_light.light_color=Color(0.0,0.8,1.0); _chamber_light.omni_range=25.0; _chamber_light.light_energy=0.3; add_child(_chamber_light)

func _process(delta: float) -> void:
	_pulse_time += delta
	_sid_timer -= delta
	if _sid_timer <= 0.0:
		_sid_timer = SID_REFRESH; _cached_sid = _find_station_sid()

	if not is_enabled:
		_active = false; _set_glow(0.1); return
	if _cached_sid == "":
		_active = false; _set_glow(0.1); return

	var power: float      = _find_nearby_power()
	var star_bonus: float = _get_star_proximity_bonus(global_position)
	var deu_avail: int    = GameDatabase.get_station_resource(_cached_sid, "deuterium")
	_active = (power >= REQUIRED_POWER and star_bonus > 0.0 and deu_avail >= 5)

	if _active:
		var efficiency: float = clamp(power / FULL_POWER, 0.0, 1.0)
		var am_rate: float    = AM_BASE_RATE * efficiency * star_bonus
		_deu_debt += am_rate * AM_DEU_COST * delta
		if _deu_debt >= 1.0:
			var to_spend: int = int(_deu_debt); _deu_debt -= float(to_spend)
			if not GameDatabase.spend_station_resource(_cached_sid, "deuterium", float(to_spend)):
				_active = false; _set_glow(0.1); return
		GameDatabase.add_station_resource(_cached_sid, "antimatter", am_rate * delta)

	_set_glow((1.5 + sin(_pulse_time * 3.0) * 0.8) if _active else 0.2)

func _set_glow(glow: float) -> void:
	if _chamber_mat   != null: _chamber_mat.emission_energy_multiplier   = glow
	if _chamber_light != null: _chamber_light.light_energy = glow * 0.5

func _find_nearby_power() -> float:
	var total: float = 0.0
	for node in get_tree().get_nodes_in_group("fusion_cores"):
		if not node is FusionCore: continue
		if global_position.distance_to(node.global_position) <= POWER_RANGE:
			total += (node as FusionCore).power_output
	return total

func _find_station_sid() -> String:
	var parent: Node = get_parent()
	while parent != null:
		if parent.is_in_group("station_orbiters"): return str(parent.get("orbit_id"))
		parent = parent.get_parent()
	var best: Node3D = null; var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("main_station_parts"):
		var dist: float = global_position.distance_to(node.global_position)
		if dist < POWER_RANGE and dist < best_dist: best = node; best_dist = dist
	if best == null: return ""
	return GameDatabase.get_station_id(best.global_position)

static func _get_star_proximity_bonus(pos: Vector3) -> float:
	var best: float = 0.0
	for sys in SectorGenerator.get_cached_systems():
		var system_local_position: Vector3 = WorldCoordinates.to_local_position(sys["position"])
		var dist: float = pos.distance_to(system_local_position)
		var soi: float = sys["sphere_of_influence"]
		if dist > soi: continue
		var bonus: float = 1.0 + (1.0 - clamp(dist/soi,0.0,1.0)) * (MAX_STAR_BONUS - 1.0)
		if bonus > best: best = bonus
	return best