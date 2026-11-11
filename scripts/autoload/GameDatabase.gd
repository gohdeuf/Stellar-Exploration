extends Node
const DEFAULT_RESOURCES := {
	"minerals": 0.0,
	"hydrogen": 0.0,
	"deuterium": 0.0,
	"tritium": 0.0,
	"antimatter": 50.0,
	"durasteel": 0.0,
}

const SAVE_DIR    := "user://savegame/"
const DB_PATH     := SAVE_DIR + "stellar_exploration.db"

# ── Spielstand (wird aus DB geladen) ──────────────────────────────────────────
var world_seed:       int        = 0
var player_position:  Vector3    = Vector3.ZERO
var player_rotation:  Quaternion = Quaternion.IDENTITY
var player_inventory: Dictionary = DEFAULT_RESOURCES.duplicate()
var player_shield:    Dictionary = {"integrity":100.0,"active":true}
var needs_seed_setup: bool   = false
var is_docked:        bool   = false
var docked_sector_id: String = ""
var docked_position:  Vector3 = Vector3.ZERO

var db: SQLite = null
var _db_ok: bool = false

func _ready() -> void:
	_ensure_save_dirs()
	_init_database()
	_load_or_create_world_meta()
	WorldCoordinates.initialize(player_position)

func _ensure_save_dirs() -> void:
	var dir := DirAccess.open("user://")
	if dir != null: dir.make_dir_recursive("savegame")

func _init_database() -> void:
	if not ClassDB.can_instantiate("SQLite"):
		push_error("GameDatabase: godot-sqlite Addon nicht gefunden! Bitte aus Asset-Library installieren.")
		return
	db = SQLite.new()
	db.path = DB_PATH
	db.open_db()
	_db_ok = true
	_create_tables()

func _create_tables() -> void:
	if not _db_ok: return

	var sql_world_meta := "CREATE TABLE IF NOT EXISTS world_meta (id INTEGER PRIMARY KEY CHECK (id = 1), world_seed TEXT, pos_x REAL, pos_y REAL, pos_z REAL, rot_x REAL, rot_y REAL, rot_z REAL, rot_w REAL, inv_minerals REAL, inv_hydrogen REAL, inv_deuterium REAL, inv_tritium REAL, inv_antimatter REAL, inv_durasteel REAL, shield_integrity REAL DEFAULT 100.0, shield_active INTEGER DEFAULT 1, is_docked INTEGER DEFAULT 0, docked_sector_id TEXT DEFAULT '', docked_pos_x REAL DEFAULT 0, docked_pos_y REAL DEFAULT 0, docked_pos_z REAL DEFAULT 0)"
	db.query(sql_world_meta)

	var sql_systems := "CREATE TABLE IF NOT EXISTS systems (system_id TEXT PRIMARY KEY, sector_id TEXT NOT NULL UNIQUE, name TEXT, pos_x REAL, pos_y REAL, pos_z REAL, soi REAL, planet_data TEXT, created_at INTEGER)"
	db.query(sql_systems)

	var sql_sectors := "CREATE TABLE IF NOT EXISTS sectors (sector_id TEXT PRIMARY KEY, stations TEXT DEFAULT '[]', ships TEXT DEFAULT '[]', orbital_stations TEXT DEFAULT '[]', planet_resources TEXT DEFAULT '{}', planet_deuterium TEXT DEFAULT '{}')"
	db.query(sql_sectors)

	var sql_station_storage := "CREATE TABLE IF NOT EXISTS station_storage (station_id TEXT PRIMARY KEY, minerals REAL DEFAULT 0, hydrogen REAL DEFAULT 0, deuterium REAL DEFAULT 0, tritium REAL DEFAULT 0, antimatter REAL DEFAULT 0, durasteel REAL DEFAULT 0)"
	db.query(sql_station_storage)

	var sql_freighter_storage := "CREATE TABLE IF NOT EXISTS freighter_storage (freighter_id TEXT PRIMARY KEY, minerals REAL DEFAULT 0, hydrogen REAL DEFAULT 0, deuterium REAL DEFAULT 0, tritium REAL DEFAULT 0, antimatter REAL DEFAULT 0, durasteel REAL DEFAULT 0)"
	db.query(sql_freighter_storage)
	_ensure_table_columns()

func _ensure_table_columns() -> void:
	if not _db_ok: return
	var world_columns := [
		["inv_hydrogen", "REAL DEFAULT 0"],
		["inv_tritium", "REAL DEFAULT 0"],
		["inv_durasteel", "REAL DEFAULT 0"],
	]
	for entry in world_columns:
		_ensure_column("world_meta", entry[0], entry[1])
	var station_columns := [
		["hydrogen", "REAL DEFAULT 0"],
		["tritium", "REAL DEFAULT 0"],
		["durasteel", "REAL DEFAULT 0"],
	]
	for entry in station_columns:
		_ensure_column("station_storage", entry[0], entry[1])
	var freighter_columns := [
		["hydrogen", "REAL DEFAULT 0"],
		["tritium", "REAL DEFAULT 0"],
		["durasteel", "REAL DEFAULT 0"],
	]
	for entry in freighter_columns:
		_ensure_column("freighter_storage", entry[0], entry[1])

func _ensure_column(table_name: String, column_name: String, column_def: String) -> void:
	if not _db_ok: return
	db.query("PRAGMA table_info(%s)" % table_name)
	for row in db.query_result:
		if str(row.get("name", "")) == column_name:
			return
	db.query("ALTER TABLE %s ADD COLUMN %s %s" % [table_name, column_name, column_def])

# ── Welt-Meta laden / anlegen ─────────────────────────────────────────────────
func _load_or_create_world_meta() -> void:
	if not _db_ok: needs_seed_setup = true; return

	db.query("SELECT * FROM world_meta WHERE id = 1")
	if db.query_result.is_empty():
		needs_seed_setup = true
		return

	var row: Dictionary = db.query_result[0]
	world_seed = _parse_seed_value(row.get("world_seed", 0))
	player_position  = Vector3(row.get("pos_x", 0.0), row.get("pos_y", 0.0), row.get("pos_z", 0.0))
	player_rotation  = Quaternion(row.get("rot_x", 0.0), row.get("rot_y", 0.0), row.get("rot_z", 0.0), row.get("rot_w", 1.0))
	player_inventory = {
		"minerals":   float(row.get("inv_minerals",   0.0)),
		"hydrogen":   float(row.get("inv_hydrogen",   0.0)),
		"deuterium":  float(row.get("inv_deuterium",  0.0)),
		"tritium":    float(row.get("inv_tritium",    0.0)),
		"antimatter": float(row.get("inv_antimatter", 50.0)),
		"durasteel":  float(row.get("inv_durasteel",  0.0)),
	}
	for key in DEFAULT_RESOURCES.keys():
		if not player_inventory.has(key):
			player_inventory[key] = float(DEFAULT_RESOURCES.get(key, 0.0))
	player_shield = {
		"integrity": float(row.get("shield_integrity", 100.0)),
		"active":    bool(row.get("shield_active", 1)),
	}
	is_docked        = bool(row.get("is_docked", 0))
	docked_sector_id = str(row.get("docked_sector_id", ""))
	docked_position  = Vector3(row.get("docked_pos_x", 0.0), row.get("docked_pos_y", 0.0), row.get("docked_pos_z", 0.0))
	needs_seed_setup = false

func _parse_seed_value(raw: Variant) -> int:
	if raw is String: return (raw as String).to_int()
	return int(raw)

func _generate_random_seed() -> int:
	randomize(); var high: int = randi(); var low: int = randi()
	return (high << 32) | low

func finish_new_world_setup(custom_seed_text: String = "") -> void:
	if custom_seed_text.strip_edges() != "":
		set_world_seed_from_text(custom_seed_text.strip_edges())
	else:
		world_seed = _generate_random_seed()
	needs_seed_setup = false
	_insert_world_meta()

func set_world_seed_from_text(text: String) -> void:
	var sha := text.sha256_buffer(); var seed_int: int = 0
	for i in range(8): seed_int = (seed_int << 8) | sha[i]
	world_seed = seed_int

func _insert_world_meta() -> void:
	if not _db_ok: return
	db.query("DELETE FROM world_meta WHERE id = 1")
	var sql := "INSERT INTO world_meta (id, world_seed, pos_x, pos_y, pos_z, rot_x, rot_y, rot_z, rot_w, inv_minerals, inv_hydrogen, inv_deuterium, inv_tritium, inv_antimatter, inv_durasteel, shield_integrity, shield_active, is_docked, docked_sector_id, docked_pos_x, docked_pos_y, docked_pos_z) VALUES (1, '%s', %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f, %d, %d, '%s', %.6f, %.6f, %.6f)" % [
		str(world_seed),
		player_position.x, player_position.y, player_position.z,
		player_rotation.x, player_rotation.y, player_rotation.z, player_rotation.w,
		player_inventory.get("minerals", 0.0),
		player_inventory.get("hydrogen", 0.0),
		player_inventory.get("deuterium", 0.0),
		player_inventory.get("tritium", 0.0),
		player_inventory.get("antimatter", 50.0),
		player_inventory.get("durasteel", 0.0),
		player_shield.get("integrity", 100.0), 1 if player_shield.get("active", true) else 0,
		1 if is_docked else 0, docked_sector_id,
		docked_position.x, docked_position.y, docked_position.z
	]
	db.query(sql)

func set_docked_state(docked: bool, sector_id: String, pos: Vector3) -> void:
	is_docked = docked; docked_sector_id = sector_id; docked_position = pos
	save_world_meta()

func save_world_meta() -> void:
	_insert_world_meta()

func save_player_state(pos: Vector3, rot: Quaternion) -> void:
	player_position = WorldCoordinates.to_world_position(pos)
	player_rotation = rot
	save_world_meta()

# close Database on exit
func close_database() -> void:
	if db != null and _db_ok:
		db.close_db()
	_db_ok = false

# ── Spieler-Inventar ──────────────────────────────────────────────────────────
func _resource_dict(values: Dictionary = {}) -> Dictionary:
	var result: Dictionary = DEFAULT_RESOURCES.duplicate()
	for key in DEFAULT_RESOURCES.keys():
		result[key] = float(values.get(key, DEFAULT_RESOURCES.get(key, 0.0)))
	return result

func get_resource(type: String) -> int:
	return int(player_inventory.get(type, DEFAULT_RESOURCES.get(type, 0.0)))

func add_resource(type: String, amount: float) -> void:
	if not player_inventory.has(type):
		player_inventory[type] = 0.0
	player_inventory[type] = float(player_inventory.get(type, 0.0)) + amount

func spend_resource(type: String, amount: int) -> bool:
	var current: float = float(player_inventory.get(type, DEFAULT_RESOURCES.get(type, 0.0)))
	if int(current) < amount: return false
	player_inventory[type] = current - float(amount); return true

# ── Schild-System ─────────────────────────────────────────────────────────────
func get_shield_integrity() -> float:
	return float(player_shield.get("integrity", 100.0))

func set_shield_integrity(value: float) -> void:
	player_shield["integrity"] = clampf(value, 0.0, 100.0)

func is_shield_active() -> bool:
	return bool(player_shield.get("active", true))

func set_shield_active(active: bool) -> void:
	player_shield["active"] = active

func damage_shield(amount: float) -> void:
	player_shield["integrity"] = clampf(float(player_shield.get("integrity", 100.0)) - amount, 0.0, 100.0)

func repair_shield(amount: float) -> void:
	player_shield["integrity"] = clampf(float(player_shield.get("integrity", 100.0)) + amount, 0.0, 100.0)

# ── Stations-Ressourcen ───────────────────────────────────────────────────────
func get_station_resource(sid: String, type: String) -> int:
	return int(float(get_station_storage(sid).get(type, 0.0)))

func add_station_resource(sid: String, type: String, amount: float) -> void:
	var st := get_station_storage(sid)
	st[type] = float(st.get(type, 0.0)) + amount
	_upsert_station_storage(sid, st)

func spend_station_resource(sid: String, type: String, amount: float) -> bool:
	var st := get_station_storage(sid)
	var current: float = float(st.get(type, 0.0))
	if current < amount: return false
	st[type] = current - amount
	_upsert_station_storage(sid, st)
	return true

func refine_station_durasteel(sid: String, minerals_cost: float = 25.0, hydrogen_cost: float = 10.0) -> bool:
	var st := get_station_storage(sid)
	if float(st.get("minerals", 0.0)) < minerals_cost: return false
	if float(st.get("hydrogen", 0.0)) < hydrogen_cost: return false
	st["minerals"] = float(st.get("minerals", 0.0)) - minerals_cost
	st["hydrogen"] = float(st.get("hydrogen", 0.0)) - hydrogen_cost
	st["durasteel"] = float(st.get("durasteel", 0.0)) + 1.0
	_upsert_station_storage(sid, st)
	return true

func _upsert_station_storage(sid: String, st: Dictionary) -> void:
	if not _db_ok: return
	var storage := _resource_dict(st)
	var sql := "INSERT INTO station_storage (station_id, minerals, hydrogen, deuterium, tritium, antimatter, durasteel) VALUES ('%s', %.6f, %.6f, %.6f, %.6f, %.6f, %.6f) ON CONFLICT(station_id) DO UPDATE SET minerals = excluded.minerals, hydrogen = excluded.hydrogen, deuterium = excluded.deuterium, tritium = excluded.tritium, antimatter = excluded.antimatter, durasteel = excluded.durasteel" % [
		sid,
		storage["minerals"],
		storage["hydrogen"],
		storage["deuterium"],
		storage["tritium"],
		storage["antimatter"],
		storage["durasteel"]
	]
	db.query(sql)

func get_station_id(hub_pos: Vector3) -> String:
	var world_position := WorldCoordinates.to_world_position(hub_pos)
	return "station_%d_%d_%d" % [
		int(round(world_position.x)), int(round(world_position.y)), int(round(world_position.z))]

func get_station_storage(sid: String) -> Dictionary:
	if not _db_ok: return _resource_dict({"minerals":0.0,"hydrogen":0.0,"deuterium":0.0,"tritium":0.0,"antimatter":0.0,"durasteel":0.0})
	db.query("SELECT * FROM station_storage WHERE station_id = '%s'" % sid)
	if db.query_result.is_empty():
		return _resource_dict({"minerals":0.0,"hydrogen":0.0,"deuterium":0.0,"tritium":0.0,"antimatter":0.0,"durasteel":0.0})
	var row: Dictionary = db.query_result[0]
	var result: Dictionary = {
		"minerals":   float(row.get("minerals", 0.0)),
		"hydrogen":   float(row.get("hydrogen", 0.0)),
		"deuterium":  float(row.get("deuterium", 0.0)),
		"tritium":    float(row.get("tritium", 0.0)),
		"antimatter": float(row.get("antimatter", 0.0)),
		"durasteel":  float(row.get("durasteel", 0.0)),
	}
	return _resource_dict(result)

func deposit_to_station(sid: String, cap_min: int, cap_deu: int, cap_am: int, cap_hydrogen: int = -1, cap_tritium: int = -1, cap_durasteel: int = -1) -> void:
	var st := get_station_storage(sid)
	var cap_hyd: int = cap_hydrogen if cap_hydrogen >= 0 else int(st.get("hydrogen", 0.0))
	var cap_tri: int = cap_tritium if cap_tritium >= 0 else int(st.get("tritium", 0.0))
	var cap_dur: int = cap_durasteel if cap_durasteel >= 0 else int(st.get("durasteel", 0.0))
	var space_min: int = cap_min - int(st.get("minerals",  0.0))
	var space_hyd: int = cap_hyd - int(st.get("hydrogen", 0.0))
	var space_deu: int = cap_deu - int(st.get("deuterium", 0.0))
	var space_tri: int = cap_tri - int(st.get("tritium", 0.0))
	var space_am:  int = cap_am  - int(st.get("antimatter",0.0))
	var space_dur: int = cap_dur - int(st.get("durasteel",0.0))
	var move_min: int = min(get_resource("minerals"),  max(0, space_min))
	var move_hyd: int = min(get_resource("hydrogen"), max(0, space_hyd))
	var move_deu: int = min(get_resource("deuterium"), max(0, space_deu))
	var move_tri: int = min(get_resource("tritium"), max(0, space_tri))
	var move_am:  int = min(get_resource("antimatter"),max(0, space_am))
	var move_dur: int = min(get_resource("durasteel"),max(0, space_dur))
	if move_min > 0: spend_resource("minerals",  move_min); st["minerals"]   = float(st.get("minerals",  0.0)) + move_min
	if move_hyd > 0: spend_resource("hydrogen",  move_hyd); st["hydrogen"]   = float(st.get("hydrogen",  0.0)) + move_hyd
	if move_deu > 0: spend_resource("deuterium", move_deu); st["deuterium"]  = float(st.get("deuterium", 0.0)) + move_deu
	if move_tri > 0: spend_resource("tritium", move_tri); st["tritium"]    = float(st.get("tritium", 0.0)) + move_tri
	if move_am  > 0: spend_resource("antimatter",move_am);  st["antimatter"] = float(st.get("antimatter",0.0)) + move_am
	if move_dur > 0: spend_resource("durasteel",move_dur);  st["durasteel"] = float(st.get("durasteel",0.0)) + move_dur
	_upsert_station_storage(sid, st); save_world_meta()

func withdraw_from_station(sid: String) -> void:
	var st := get_station_storage(sid)
	add_resource("minerals",  float(int(st.get("minerals",  0.0))))
	add_resource("hydrogen",  float(int(st.get("hydrogen",  0.0))))
	add_resource("deuterium", float(int(st.get("deuterium", 0.0))))
	add_resource("tritium",   float(int(st.get("tritium",   0.0))))
	add_resource("antimatter",float(int(st.get("antimatter",0.0))))
	add_resource("durasteel", float(int(st.get("durasteel", 0.0))))
	_upsert_station_storage(sid, _resource_dict({"minerals":0.0,"hydrogen":0.0,"deuterium":0.0,"tritium":0.0,"antimatter":0.0,"durasteel":0.0}))
	save_world_meta()

func get_freighter_storage(freighter_id: String) -> Dictionary:
	if not _db_ok: return _resource_dict({"minerals":0.0,"hydrogen":0.0,"deuterium":0.0,"tritium":0.0,"antimatter":0.0,"durasteel":0.0})
	db.query("SELECT * FROM freighter_storage WHERE freighter_id = '%s'" % freighter_id)
	if db.query_result.is_empty():
		return _resource_dict({"minerals":0.0,"hydrogen":0.0,"deuterium":0.0,"tritium":0.0,"antimatter":0.0,"durasteel":0.0})
	var row: Dictionary = db.query_result[0]
	return _resource_dict({
		"minerals":   float(row.get("minerals", 0.0)),
		"hydrogen":   float(row.get("hydrogen", 0.0)),
		"deuterium":  float(row.get("deuterium", 0.0)),
		"tritium":    float(row.get("tritium", 0.0)),
		"antimatter": float(row.get("antimatter", 0.0)),
		"durasteel":  float(row.get("durasteel", 0.0)),
	})

func set_freighter_storage(freighter_id: String, cargo: Dictionary) -> void:
	if not _db_ok: return
	var storage := _resource_dict(cargo)
	var sql := "INSERT INTO freighter_storage (freighter_id, minerals, hydrogen, deuterium, tritium, antimatter, durasteel) VALUES ('%s', %.6f, %.6f, %.6f, %.6f, %.6f, %.6f) ON CONFLICT(freighter_id) DO UPDATE SET minerals = excluded.minerals, hydrogen = excluded.hydrogen, deuterium = excluded.deuterium, tritium = excluded.tritium, antimatter = excluded.antimatter, durasteel = excluded.durasteel" % [
		freighter_id,
		storage["minerals"],
		storage["hydrogen"],
		storage["deuterium"],
		storage["tritium"],
		storage["antimatter"],
		storage["durasteel"]
	]
	db.query(sql)

# ── Orbitalstationen ──────────────────────────────────────────────────────────
func create_orbital_station(sector_id: String, orbit_id: String, planet_name: String,
		orbit_radius: float, orbit_angle_deg: float, orbit_speed_deg: float) -> void:
	var data := load_sector_data(sector_id)
	var orbital: Array = data.get("orbital_stations", [])
	orbital.append({
		"orbit_id": orbit_id, "planet_name": planet_name,
		"orbit_radius": orbit_radius, "orbit_angle_deg": orbit_angle_deg,
		"orbit_speed_deg": orbit_speed_deg, "parts": [],
	})
	data["orbital_stations"] = orbital; save_sector_data(sector_id, data)

func add_orbital_station_part(sector_id: String, orbit_id: String,
		part_type: String, offset: Vector3) -> void:
	var data := load_sector_data(sector_id)
	var orbital: Array = data.get("orbital_stations", [])
	for entry in orbital:
		if entry.get("orbit_id", "") != orbit_id: continue
		var parts: Array = entry.get("parts", [])
		parts.append({"type": part_type, "off_x": offset.x, "off_y": offset.y, "off_z": offset.z})
		entry["parts"] = parts; data["orbital_stations"] = orbital
		save_sector_data(sector_id, data); return

func save_orbital_station_angle(sector_id: String, orbit_id: String, angle_deg: float) -> void:
	var data := load_sector_data(sector_id)
	var orbital: Array = data.get("orbital_stations", [])
	for entry in orbital:
		if entry.get("orbit_id", "") != orbit_id: continue
		entry["orbit_angle_deg"] = angle_deg
		data["orbital_stations"] = orbital; save_sector_data(sector_id, data); return

# ── Systeme (NEU: fuer GalaxyMap) ─────────────────────────────────────────────
func save_system(system_data: Dictionary) -> void:
	if not _db_ok or system_data.is_empty(): return
	var sid: String = system_data.get("system_id", "")
	var sec_id: String = system_data.get("sector_id", "")
	var pos: Vector3 = system_data.get("position", Vector3.ZERO)
	var planets: Array = system_data.get("planets", [])
	var planet_json: String = JSON.stringify(planets)
	var sql := "INSERT INTO systems (system_id, sector_id, name, pos_x, pos_y, pos_z, soi, planet_data, created_at) VALUES ('%s', '%s', '%s', %.6f, %.6f, %.6f, %.6f, '%s', %d) ON CONFLICT(sector_id) DO UPDATE SET name = excluded.name, pos_x = excluded.pos_x, pos_y = excluded.pos_y, pos_z = excluded.pos_z, soi = excluded.soi, planet_data = excluded.planet_data" % [
		sid, sec_id,
		system_data.get("name", "").replace("'", "''"),
		pos.x, pos.y, pos.z,
		system_data.get("sphere_of_influence", 0.0),
		planet_json.replace("'", "''"),
		Time.get_unix_time_from_system()
	]
	db.query(sql)

func get_all_systems() -> Array:
	if not _db_ok: return []
	db.query("SELECT * FROM systems")
	var result: Array = []
	for row in db.query_result:
		var pos := Vector3(float(row.get("pos_x", 0.0)), float(row.get("pos_y", 0.0)), float(row.get("pos_z", 0.0)))
		var planets: Variant = JSON.parse_string(str(row.get("planet_data", "[]")))
		result.append({
			"system_id": row.get("system_id", ""),
			"sector_id": row.get("sector_id", ""),
			"name":      row.get("name", ""),
			"position":  pos,
			"sphere_of_influence": float(row.get("soi", 0.0)),
			"planets":   planets if planets is Array else [],
		})
	return result

func get_system_revision() -> String:
	if not _db_ok: return "0:0"
	db.query("SELECT COUNT(*) AS system_count, COALESCE(MAX(created_at), 0) AS latest_system FROM systems")
	if db.query_result.is_empty(): return "0:0"
	var row: Dictionary = db.query_result[0]
	return "%s:%s" % [row.get("system_count", 0), row.get("latest_system", 0)]

func has_system(sector_id: String) -> bool:
	if not _db_ok: return false
	db.query("SELECT 1 FROM systems WHERE sector_id = '%s'" % sector_id)
	return not db.query_result.is_empty()

# ── Sektor-Daten ──────────────────────────────────────────────────────────────
func load_sector_data(sector_id: String) -> Dictionary:
	if not _db_ok: return {}
	db.query("SELECT * FROM sectors WHERE sector_id = '%s'" % sector_id)
	if db.query_result.is_empty(): return {}
	var row: Dictionary = db.query_result[0]
	var result := {}
	var fields := ["stations", "ships", "orbital_stations", "planet_resources", "planet_deuterium"]
	for f in fields:
		var parsed: Variant = JSON.parse_string(str(row.get(f, "{}")))
		result[f] = parsed if parsed is Dictionary or parsed is Array else {} if f in ["planet_resources", "planet_deuterium"] else []
	return result

func save_sector_data(sector_id: String, data: Dictionary) -> void:
	if not _db_ok: return
	var stations := JSON.stringify(data.get("stations", []))
	var ships := JSON.stringify(data.get("ships", []))
	var orbital := JSON.stringify(data.get("orbital_stations", []))
	var min_ov := JSON.stringify(data.get("planet_resources", {}))
	var deu_ov := JSON.stringify(data.get("planet_deuterium", {}))
	var sql := "INSERT INTO sectors (sector_id, stations, ships, orbital_stations, planet_resources, planet_deuterium) VALUES ('%s', '%s', '%s', '%s', '%s', '%s') ON CONFLICT(sector_id) DO UPDATE SET stations = excluded.stations, ships = excluded.ships, orbital_stations = excluded.orbital_stations, planet_resources = excluded.planet_resources, planet_deuterium = excluded.planet_deuterium" % [sector_id, stations, ships, orbital, min_ov, deu_ov]
	db.query(sql)

func save_planet_state(sector_id: String, planet_name: String, minerals: float, deuterium: float) -> void:
	var data := load_sector_data(sector_id)
	var min_ov: Dictionary = data.get("planet_resources", {}); var deu_ov: Dictionary = data.get("planet_deuterium", {})
	min_ov[planet_name] = minerals; deu_ov[planet_name] = deuterium
	data["planet_resources"] = min_ov; data["planet_deuterium"] = deu_ov; save_sector_data(sector_id, data)

func add_station(sector_id: String, station: Dictionary) -> void:
	var data := load_sector_data(sector_id)
	var stations: Array = data.get("stations", []); stations.append(station)
	data["stations"] = stations; save_sector_data(sector_id, data)

func add_ship(sector_id: String, ship: Dictionary) -> void:
	var data := load_sector_data(sector_id)
	var ships: Array = data.get("ships", []); ships.append(ship)
	data["ships"] = ships; save_sector_data(sector_id, data)
