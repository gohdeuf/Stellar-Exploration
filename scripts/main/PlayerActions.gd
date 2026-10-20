class_name PlayerActions
extends Node
# Nur noch Abbau-Gameplay. Stationsbau laeuft ueber StationEditor (B-Taste).

const MINING_RANGE := 20.0
const MINING_RATE_MINERALS        := 80.0
const MINING_RATE_DEUTERIUM_ROCKY := 20.0
const MINING_RATE_DEUTERIUM_GAS   := 60.0
const PERSIST_INTERVAL := 1.0
const HUD_MSG_INTERVAL := 0.3

var ship: Node3D; var world_manager: WorldManager; var hud: SOINotification
var _mining_planet: Planet = null
var _persist_timer: float = 0.0; var _hud_timer: float = 0.0

func setup(p_ship: Node3D, p_world_manager: WorldManager, p_hud: SOINotification) -> void:
	ship = p_ship; world_manager = p_world_manager; hud = p_hud

func _process(delta: float) -> void:
	if ship == null or StationEditor.is_editor_open: return
	_handle_mining(delta)

func _handle_mining(delta: float) -> void:
	_hud_timer += delta; _persist_timer += delta
	if _mining_planet != null and not is_instance_valid(_mining_planet): _mining_planet = null
	var nearby := _find_nearby_planet()
	if not Input.is_action_pressed("mine_resource") or nearby == null:
		if _mining_planet != null: _persist_mining(_mining_planet); _mining_planet = null
		return
	_mining_planet = nearby
	var cls: String  = _mining_planet.planet_data["class"]
	var is_gas: bool = PlanetClassDB.classes[cls]["type"] == "gas"
	var deu_rate     := MINING_RATE_DEUTERIUM_GAS if is_gas else MINING_RATE_DEUTERIUM_ROCKY
	var resources: Dictionary = _mining_planet.planet_data["resources"]
	if resources["current"] > 0.0:
		var m: float = min(MINING_RATE_MINERALS * delta, resources["current"])
		resources["current"] = max(0.0, resources["current"] - m)
		GameDatabase.add_resource("minerals", m)
	if _mining_planet.planet_data.has("deuterium"):
		var deu: Dictionary = _mining_planet.planet_data["deuterium"]
		if deu["current"] > 0.0:
			var d: float = min(deu_rate * delta, deu["current"])
			deu["current"] = max(0.0, deu["current"] - d)
			GameDatabase.add_resource("deuterium", d)
	if hud != null and _hud_timer >= HUD_MSG_INTERVAL:
		_hud_timer = 0.0
		var pn: String = _mining_planet.planet_data["name"]
		var mr := int(_mining_planet.planet_data["resources"]["current"])
		var dr := int(_mining_planet.planet_data.get("deuterium",{}).get("current",0.0))
		if mr==0 and dr==0: hud.show_message(Locale.t("actions.mine_empty",{"planet":pn}))
		else: hud.show_message(Locale.t("actions.mining",{"planet":pn,"minerals":mr,"deuterium":dr}))
	if _persist_timer >= PERSIST_INTERVAL: _persist_timer=0.0; _persist_mining(_mining_planet)

func _persist_mining(planet: Planet) -> void:
	var coords    := WorldCoordinates.to_sector_coords(planet.global_position)
	var sector_id := SectorUtils.sector_coords_to_id(coords.x, coords.y, coords.z)
	GameDatabase.save_planet_state(sector_id, planet.planet_data["name"],
		planet.planet_data["resources"]["current"],
		planet.planet_data.get("deuterium",{}).get("current",0.0))

func _find_nearby_planet() -> Planet:
	var best: Planet = null; var best_dist := INF
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Planet
		if planet == null:
			continue
		var pr: float = planet.planet_data.get("radius",0.0)
		var dist: float = ship.global_position.distance_to(planet.global_position) - pr
		if dist <= MINING_RANGE and dist < best_dist: best=planet; best_dist=dist
	return best
