class_name StationEditor
extends Node

static var is_editor_open: bool = false

const EDITOR_RANGE          := 120.0
const MIN_ATTACH_DIST       :=   6.0
const ORBIT_DETECT_RANGE    := 200.0   # Planeten-SOI für Orbitalstation
const ORBIT_ALTITUDE        :=  30.0   # Einheiten über Planetenoberfläche
const ORBIT_SPEED_DEG       :=   0.2   # °/Sek Stationsumlauf

const MODULE_NAMES := ["main_station","fusion_core","am_factory_small","am_factory_big","storage_container","mining_drill"]

const COSTS := {
	"main_station":      [500, 100],
	"fusion_core":       [300,  50],
	"am_factory_small":  [200, 100],
	"am_factory_big":    [600, 200],
	"storage_container": [400,  50],
	"mining_drill":      [350,   0],
}

const GHOST_SIZES := {
	"main_station":      Vector3(22, 12, 22),
	"fusion_core":       Vector3(12, 12, 12),
	"am_factory_small":  Vector3( 5, 10,  5),
	"am_factory_big":    Vector3(10, 14, 10),
	"storage_container": Vector3(10, 10, 14),
	"mining_drill":      Vector3( 8,  8,  8),
}

const PART_OFFSETS := {
	"res://scripts/entities/station_parts/MainStationPart.gd":
		[Vector3(16,0,0),Vector3(-16,0,0),Vector3(0,0,16),Vector3(0,0,-16),Vector3(0,13,0),Vector3(0,-13,0)],
	"res://scripts/entities/station_parts/FusionCore.gd":
		[Vector3(10,0,0),Vector3(-10,0,0),Vector3(0,0,10),Vector3(0,0,-10)],
	"res://scripts/entities/station_parts/AntimatterFactorySmall.gd":
		[Vector3(8,0,0),Vector3(-8,0,0),Vector3(0,0,8),Vector3(0,0,-8)],
	"res://scripts/entities/station_parts/AntimatterFactoryBig.gd":
		[Vector3(12,0,0),Vector3(-12,0,0),Vector3(0,0,12),Vector3(0,0,-12)],
	"res://scripts/entities/station_parts/StorageContainer.gd":
		[Vector3(9,0,0),Vector3(-9,0,0),Vector3(0,0,9),Vector3(0,0,-9)],
	"res://scripts/entities/station_parts/MiningDrill.gd":
		[Vector3(7,0,0),Vector3(-7,0,0),Vector3(0,0,7),Vector3(0,0,-7)],
	"res://scripts/entities/Station.gd":
		[Vector3(8,0,0),Vector3(-8,0,0),Vector3(0,0,8),Vector3(0,0,-8)],
}

const SECTOR_UTILS := preload("res://scripts/autoload/SectorUtils.gd")

var ship:          Node3D = null
var _hud:          Node   = null
var world_manager: WorldManager = null
var selected_module: int  = 0

var _ghost:    MeshInstance3D      = null
var _ghost_mat: StandardMaterial3D = null
var _snap_point:       Vector3 = Vector3.ZERO
var _snap_valid:       bool    = false
var _snap_free:        bool    = false
var _snap_target_node: Node3D  = null   # Node der den Snap-Ankerpunkt bereitstellt
var _orbit_planet:     Node3D  = null   # non-null → Orbitalstations-Modus
var _scenes: Dictionary = {}

var _ui:           Control = null
var _status_label: Label   = null

func setup(p_ship: Node3D, p_hud: Node, p_wm: WorldManager) -> void:
	ship = p_ship; _hud = p_hud; world_manager = p_wm
	_scenes = {
		"main_station":      preload("res://scenes/station_parts/MainStationPart.tscn"),
		"fusion_core":       preload("res://scenes/station_parts/FusionCore.tscn"),
		"am_factory_small":  preload("res://scenes/station_parts/AntimatterFactorySmall.tscn"),
		"am_factory_big":    preload("res://scenes/station_parts/AntimatterFactoryBig.tscn"),
		"storage_container": preload("res://scenes/station_parts/StorageContainer.tscn"),
		"mining_drill":      preload("res://scenes/station_parts/MiningDrill.tscn"),
	}
	_build_ghost(); _build_ui()

func _build_ghost() -> void:
	_ghost = MeshInstance3D.new(); var bm := BoxMesh.new(); _ghost.mesh = bm
	_ghost_mat = StandardMaterial3D.new(); _ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.emission_enabled = true; _ghost.material_override = _ghost_mat; _ghost.visible = false
	ship.get_parent().call_deferred("add_child", _ghost)

func _build_ui() -> void:
	_ui = Control.new()
	_ui.anchor_right=0.0; _ui.anchor_bottom=1.0; _ui.offset_left=10; _ui.offset_top=10
	_ui.offset_right=290; _ui.offset_bottom=-10; _ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; _ui.visible=false
	var bg := ColorRect.new(); bg.color=Color(0,0,0,0.78); bg.anchor_right=1.0; bg.anchor_bottom=1.0; _ui.add_child(bg)
	var vbox := VBoxContainer.new(); vbox.anchor_right=1.0; vbox.anchor_bottom=1.0
	vbox.offset_left=12; vbox.offset_top=12; vbox.offset_right=-12; vbox.offset_bottom=-12; _ui.add_child(vbox)
	var title := Label.new(); title.text="─── STATION EDITOR ───"
	title.add_theme_color_override("font_color",Color(0.5,0.9,1.0)); title.add_theme_font_size_override("font_size",15); vbox.add_child(title)
	var _module_labels := ["Main Hub","Fusion Core","AM Factory S","AM Factory L","Storage","Mining Drill"]
	var _cost_labels   := ["500M+100D","300M+50D","200M+100D","600M+200D","400M+50D","350M"]
	for i in range(MODULE_NAMES.size()):
		var row := HBoxContainer.new(); vbox.add_child(row)
		var num := Label.new(); num.text="[%d] "%[(i+1)]; num.add_theme_color_override("font_color",Color(0.8,0.8,0.3)); row.add_child(num)
		var info := Label.new(); info.text="%s\n    %s"%[_module_labels[i],_cost_labels[i]]; info.add_theme_font_size_override("font_size",12); row.add_child(info)
	var sep := HSeparator.new(); vbox.add_child(sep)
	_status_label = Label.new(); _status_label.text=""; _status_label.autowrap_mode=TextServer.AUTOWRAP_WORD; vbox.add_child(_status_label)
	var sep2 := HSeparator.new(); vbox.add_child(sep2)
	var hint := Label.new(); hint.text="[E] Platzieren\n[1-6] Modul\n[G/B] Schliessen"
	hint.add_theme_color_override("font_color",Color(0.65,0.65,0.65)); hint.add_theme_font_size_override("font_size",12); vbox.add_child(hint)
	get_tree().root.call_deferred("add_child", _ui)

func _refresh_ui_highlight() -> void:
	if _ui == null: return
	var vbox := _ui.get_child(1); var idx: int = 0
	var _module_labels := ["Main Hub","Fusion Core","AM Factory S","AM Factory L","Storage","Mining Drill"]
	var _cost_labels   := ["500M+100D","300M+50D","200M+100D","600M+200D","400M+50D","350M"]
	for child in vbox.get_children():
		if not child is HBoxContainer: continue
		var info: Label = child.get_child(1) if child.get_child_count()>1 else null
		if info == null: idx+=1; continue
		if idx == selected_module: info.add_theme_color_override("font_color",Color(0.2,1.0,0.4))
		else: info.remove_theme_color_override("font_color")
		idx += 1

func open_editor() -> void:
	if is_editor_open: return
	is_editor_open=true; _ghost.visible=true; _ui.visible=true; _refresh_ui_highlight()

func close_editor() -> void:
	if not is_editor_open: return
	is_editor_open=false; _ghost.visible=false; _ui.visible=false

func _process(_delta: float) -> void:
	if not is_editor_open or ship==null: return
	_update_snap(); _update_ghost_visual(); _update_status()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton): return
	if Input.is_action_just_pressed("build_station"):
		if is_editor_open: close_editor()
		else: open_editor()
		return
	if not is_editor_open: return
	if Input.is_action_just_pressed("quit_game") or Input.is_action_pressed("toggle_map"):
		close_editor(); return
	if Input.is_action_just_pressed("place_module"):
		_place_module()
	for i in range(MODULE_NAMES.size()):
		if event is InputEventKey and (event as InputEventKey).pressed:
			if (event as InputEventKey).physical_keycode == (KEY_1 + i):
				selected_module = i; _refresh_ui_highlight()
				(_ghost.mesh as BoxMesh).size = GHOST_SIZES[MODULE_NAMES[i]]

# ── Snap ─────────────────────────────────────────────────────────────────────
func _update_snap() -> void:
	var station_nodes := get_tree().get_nodes_in_group("stations")
	_snap_target_node = null; _orbit_planet = null

	if station_nodes.is_empty():
		_snap_free = true
		_compute_free_or_orbital_snap()
		return

	_snap_free = false
	var station_positions: Array = []
	for n in station_nodes:
		station_positions.append(n.global_position)
	var best_pt: Vector3 = Vector3.ZERO; var best_dist: float = INF

	for node in station_nodes:
		var scr = node.get_script()
		if scr == null:
			continue
		var offsets: Array = PART_OFFSETS.get(scr.resource_path, [])
		for off in offsets:
			var world_pt: Vector3 = node.global_position + off
			var occupied := false
			for sp in station_positions:
				if world_pt.distance_to(sp) < MIN_ATTACH_DIST: occupied=true; break
			if occupied: continue
			var d: float = ship.global_position.distance_to(world_pt)
			if d < best_dist: best_dist=d; best_pt=world_pt; _snap_target_node=node

	if best_dist < EDITOR_RANGE:
		_snap_point=best_pt; _snap_valid=true
	else:
		# Kein Ankerpunkt in Reichweite – Orbitalstation als Alternative?
		_compute_free_or_orbital_snap()

func _compute_free_or_orbital_snap() -> void:
	# Nahen Planeten suchen
	var nearest_planet: Node3D = null; var nearest_dist: float = INF
	for node in get_tree().get_nodes_in_group("planets"):
		var dist: float = ship.global_position.distance_to(node.global_position)
		if dist < ORBIT_DETECT_RANGE and dist < nearest_dist:
			nearest_planet = node; nearest_dist = dist

	if nearest_planet != null and nearest_planet is Planet:
		_orbit_planet = nearest_planet
		var planet := nearest_planet as Planet
		var r: float = float(planet.planet_data.get("radius", 5.0))
		var diff: Vector3 = ship.global_position - planet.global_position
		var dir: Vector3 = diff.normalized() if diff.length() > 0.01 else Vector3.RIGHT
		_snap_point = planet.global_position + dir * (r + ORBIT_ALTITUDE)
		_snap_valid = true
	else:
		_snap_point = ship.global_position - ship.transform.basis.z * 18.0
		_snap_valid = _snap_free  # nur gültig wenn wirklich erstes Part überhaupt

func _update_ghost_visual() -> void:
	_ghost.global_position = _snap_point
	(_ghost.mesh as BoxMesh).size = GHOST_SIZES[MODULE_NAMES[selected_module]]
	if _orbit_planet != null:
		_ghost_mat.albedo_color = Color(0.0, 0.85, 1.0, 0.35)
		_ghost_mat.emission     = Color(0.0, 0.65, 0.9)
	elif _snap_free:
		_ghost_mat.albedo_color = Color(1.0, 0.9, 0.0, 0.35)
		_ghost_mat.emission     = Color(0.8, 0.7, 0.0)
	elif _snap_valid:
		_ghost_mat.albedo_color = Color(0.0, 1.0, 0.3, 0.35)
		_ghost_mat.emission     = Color(0.0, 0.8, 0.2)
	else:
		_ghost_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.35)
		_ghost_mat.emission     = Color(0.8, 0.05, 0.05)

func _update_status() -> void:
	if _status_label == null: return
	if _orbit_planet != null and _orbit_planet is Planet:
		var pname: String = (_orbit_planet as Planet).planet_data.get("name","?")
		_status_label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
		_status_label.text = "Orbitalstation\num %s" % pname
	elif _snap_free:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
		_status_label.text = "Erste Platzierung\n(vor dem Schiff)"
	elif _snap_valid:
		_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		_status_label.text = "Ankerpunkt gefunden ✓"
	else:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_status_label.text = "Kein Ankerpunkt\nin Reichweite"

# ── Platzierung ───────────────────────────────────────────────────────────────
func _place_module() -> void:
	if not _snap_valid: return
	var part_name: String = MODULE_NAMES[selected_module]
	var costs: Array      = COSTS[part_name]
	if GameDatabase.get_resource("minerals") < costs[0]:
		if _hud: _hud.show_message(Locale.t("actions.not_enough_minerals",{"cost":costs[0],"have":GameDatabase.get_resource("minerals")})); return
	if costs[1] > 0 and GameDatabase.get_resource("deuterium") < costs[1]:
		if _hud: _hud.show_message(Locale.t("actions.not_enough_deuterium",{"cost":costs[1],"have":GameDatabase.get_resource("deuterium")})); return
	GameDatabase.spend_resource("minerals", costs[0])
	if costs[1] > 0: GameDatabase.spend_resource("deuterium", costs[1])

	var inst: Node3D = _scenes[part_name].instantiate()

	# ── Orbitalstation? ───────────────────────────────────────────────────────
	var existing_orbiter: Node3D = _find_orbiter_of_snap_target()
	if existing_orbiter != null:
		# Teil einer bestehenden Orbitalstation
		var local_off: Vector3 = existing_orbiter.to_local(_snap_point)
		existing_orbiter.add_child(inst); inst.position = local_off
		var coords := WorldCoordinates.to_sector_coords(existing_orbiter.global_position)
		var sector_id := SECTOR_UTILS.sector_coords_to_id(coords.x, coords.y, coords.z)
		GameDatabase.add_orbital_station_part(sector_id, str(existing_orbiter.get("orbit_id")), part_name, local_off)
	elif _orbit_planet != null and _orbit_planet is Planet:
		# Neue Orbitalstation um Planeten starten
		_create_orbital_station_first_part(inst, part_name)
	else:
		# Feste Platzierung
		var coords := WorldCoordinates.to_sector_coords(_snap_point)
		var sector_id := SECTOR_UTILS.sector_coords_to_id(coords.x, coords.y, coords.z)
		var container: Node3D = world_manager.get_sector_container(sector_id)
		if container != null: container.add_child(inst)
		else: world_manager.add_child(inst)
		inst.global_position = _snap_point
		var world_snap_point := WorldCoordinates.to_world_position(_snap_point)
		GameDatabase.add_station(sector_id, {
			"pos_x": world_snap_point.x,
			"pos_y": world_snap_point.y,
			"pos_z": world_snap_point.z,
			"type": part_name})

	if _hud: _hud.show_message(Locale.t("actions.part_built",{"part":Locale.t("part."+part_name)}))
	_update_snap()

func _create_orbital_station_first_part(inst: Node3D, part_name: String) -> void:
	var planet := _orbit_planet as Planet
	var r: float        = float(planet.planet_data.get("radius", 5.0))
	var orbit_r: float  = r + ORBIT_ALTITUDE
	var diff: Vector3   = ship.global_position - planet.global_position
	var dir: Vector3    = diff.normalized() if diff.length() > 0.01 else Vector3.RIGHT
	var orbit_angle: float = rad_to_deg(atan2(dir.z, dir.x))
	var planet_name: String = str(planet.planet_data.get("name","Unknown"))
	var coords := WorldCoordinates.to_sector_coords(planet.global_position)
	var sector_id := SECTOR_UTILS.sector_coords_to_id(coords.x, coords.y, coords.z)
	var orbit_id: String = "orbit_%s_%d" % [planet_name.replace(" ","_"), Time.get_ticks_msec() % 100000]
	var container: Node3D = world_manager.get_sector_container(sector_id)
	var orbiter := StationOrbiter.new()
	if container != null: container.add_child(orbiter)
	else: world_manager.add_child(orbiter)
	orbiter.orbit_id = orbit_id
	orbiter.setup(_orbit_planet, orbit_r, orbit_angle, ORBIT_SPEED_DEG)
	orbiter.add_child(inst); inst.position = Vector3.ZERO
	GameDatabase.create_orbital_station(sector_id, orbit_id, planet_name, orbit_r, orbit_angle, ORBIT_SPEED_DEG)
	GameDatabase.add_orbital_station_part(sector_id, orbit_id, part_name, Vector3.ZERO)

func _find_orbiter_of_snap_target() -> Node3D:
	if _snap_target_node == null: return null
	var parent: Node = _snap_target_node.get_parent()
	while parent != null:
		if parent.is_in_group("station_orbiters"): return parent
		parent = parent.get_parent()
	return null