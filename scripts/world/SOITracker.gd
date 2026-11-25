class_name SOITracker
extends Node

signal enter_system(system_data: Dictionary)
signal exit_system(system_data: Dictionary)
signal enter_planet_soi(planet_data: Dictionary, planet_node: Node3D)
signal exit_planet_soi(planet_name: String)
signal enter_moon_soi(moon_name: String, moon_node: Node3D)
signal exit_moon_soi(moon_name: String)

const PLANET_SOI_MULT  := 2.0    # Planet-SOI = max(radius * 2.0, MIN)
const PLANET_SOI_MIN   := 30.0

# Mond-SOI proportional zum Mondradius statt fester Wert:
# Phobos (r=1.0) → SOI 5.0  statt 15.0 (war viel zu groß)
# Luna   (r=2.75) → SOI 11.0
# Ganymed(r=4.0) → SOI 16.0
const MOON_SOI_MULT := 4.0
const MOON_SOI_MIN  := 4.0

enum FlightState { INTERSTELLAR, SYSTEM }

var state: int           = FlightState.INTERSTELLAR
var active_system: Dictionary = {}
var _active_planet_name: String = ""
var _active_moon_name:   String = ""
var _active_planet_node: Node3D = null
var _active_moon_node:   Node3D = null
var player: Node3D

func set_player(node: Node3D) -> void: player = node

func _process(_delta: float) -> void:
	if player == null: return
	_update_system_soi()
	_update_planet_soi()
	_update_moon_soi()

# ── Sternsystem ───────────────────────────────────────────────────────────────
func _update_system_soi() -> void:
	var found: Dictionary = find_active_system(player.global_position)
	if found.is_empty():
		if state == FlightState.SYSTEM:
			state = FlightState.INTERSTELLAR
			exit_system.emit(active_system)
			active_system = {}
	else:
		if active_system.get("system_id","") != found.get("system_id",""):
			if state == FlightState.SYSTEM: exit_system.emit(active_system)
			active_system = found; state = FlightState.SYSTEM; enter_system.emit(active_system)

# ── Planet ────────────────────────────────────────────────────────────────────
func _update_planet_soi() -> void:
	var found_node: Node3D = _nearest_planet_in_soi(player.global_position)
	var new_name: String   = ""
	if found_node != null and found_node is Planet:
		new_name = str((found_node as Planet).planet_data.get("name",""))
	if new_name == _active_planet_name: return
	if _active_planet_name != "":
		var old: String = _active_planet_name
		_active_planet_name = ""; _active_planet_node = null
		exit_planet_soi.emit(old)
	_active_planet_name = new_name
	if found_node != null and found_node is Planet:
		_active_planet_node = found_node
		enter_planet_soi.emit((found_node as Planet).planet_data, found_node)

func _nearest_planet_in_soi(ship_pos: Vector3) -> Node3D:
	var best: Node3D     = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("planets"):
		if not node is Planet: continue
		var planet: Planet   = node as Planet
		var r: float         = float(planet.planet_data.get("radius", 5.0))
		var soi_r: float     = maxf(r * PLANET_SOI_MULT, PLANET_SOI_MIN)
		var dist: float      = ship_pos.distance_to(node.global_position)
		if dist <= soi_r and dist < best_dist: best = node; best_dist = dist
	return best

# ── Mond ──────────────────────────────────────────────────────────────────────
func _update_moon_soi() -> void:
	var found_node: Node3D = _nearest_moon_in_soi(player.global_position)
	var new_name: String   = ""
	if found_node != null and found_node is Moon:
		var moon: Moon = found_node as Moon
		new_name = moon.moon_display_name if moon.moon_display_name != "" \
			else moon.name.replace("_", " ")
	if new_name == _active_moon_name: return
	if _active_moon_name != "":
		var old: String = _active_moon_name
		_active_moon_name = ""; _active_moon_node = null
		exit_moon_soi.emit(old)
	_active_moon_name = new_name
	if found_node != null:
		_active_moon_node = found_node
		enter_moon_soi.emit(new_name, found_node)

func _nearest_moon_in_soi(ship_pos: Vector3) -> Node3D:
	var best: Node3D     = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("moons"):
		if not node is Moon: continue
		var moon: Moon   = node as Moon
		# SOI proportional zum Mondradius – keine fixe 15-Unit-Kugel mehr
		var soi_r: float = maxf(moon.moon_radius * MOON_SOI_MULT, MOON_SOI_MIN)
		var dist: float  = ship_pos.distance_to(node.global_position)
		if dist <= soi_r and dist < best_dist: best = node; best_dist = dist
	return best

func find_active_system(ship_pos: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = INF
	for sys in SectorGenerator.get_cached_systems():
		var system_local_position: Vector3 = WorldCoordinates.to_local_position(sys["position"])
		var d: float = SectorUtils.distance_3d(ship_pos, system_local_position)
		if d <= sys["sphere_of_influence"] and d < best_dist:
			best = sys; best_dist = d
	return best