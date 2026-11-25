class_name DockingSystem
extends Node
# Andock-System (K). Area-basiert: Station muss <= DOCK_RANGE entfernt sein.
# Tween richtet Schiff butterweich am Docking-Port aus.
# Zustand wird in world_meta.json gespeichert.

const DOCK_RANGE := 20.0

var ship: Node3D = null
var _hud: Node   = null
var _is_docked: bool       = false
var _docked_station: Node3D = null

signal docked(station: Node3D)
signal undocked()

func setup(p_ship: Node3D, p_hud: Node = null) -> void:
	ship = p_ship; _hud = p_hud
	_is_docked = GameDatabase.is_docked
	if _is_docked and _hud:
		_hud.show_message(Locale.t("docking.restored"))

func _process(_delta: float) -> void:
	if ship == null: return
	if Input.is_action_just_pressed("dock_station"):
		if _is_docked: _undock()
		else:          _try_dock()

func _try_dock() -> void:
	var nearest: Node3D = _find_nearest_station()
	if nearest == null:
		if _hud: _hud.show_message(Locale.t("docking.no_station"))
		return
	var dist: float = ship.global_position.distance_to(nearest.global_position)
	if dist > DOCK_RANGE:
		if _hud: _hud.show_message(Locale.t("docking.too_far", {"dist": "%.0f" % dist}))
		return
	_dock_to(nearest)

func _dock_to(station: Node3D) -> void:
	_is_docked = true; _docked_station = station
	var dock_pos: Vector3 = station.global_position + Vector3.UP * 14.0
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ship, "global_position", dock_pos, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ship, "quaternion", Quaternion.IDENTITY, 1.5)
	var coords: Vector3i  = WorldCoordinates.to_sector_coords(station.global_position)
	var sector_id: String = SectorUtils.sector_coords_to_id(coords.x, coords.y, coords.z)
	GameDatabase.set_docked_state(
		true, sector_id, WorldCoordinates.to_world_position(dock_pos))
	if _hud: _hud.show_message(Locale.t("docking.docked"))
	docked.emit(station)

func _undock() -> void:
	_is_docked = false; _docked_station = null
	GameDatabase.set_docked_state(false, "", Vector3.ZERO)
	if _hud: _hud.show_message(Locale.t("docking.undocked"))
	undocked.emit()

func _find_nearest_station() -> Node3D:
	var best: Node3D  = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("stations"):
		var dist: float = ship.global_position.distance_to(node.global_position)
		if dist < best_dist:
			best = node as Node3D; best_dist = dist
	return best
