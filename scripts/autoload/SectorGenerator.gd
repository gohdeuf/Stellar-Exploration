extends Node
const SYSTEM_SPAWN_CHANCE := 0.35
const SOI_MIN :=  800.0   # erhöht – System ist jetzt größer
const SOI_MAX := 1700.0
const PLANETS_MIN := 0;  const PLANETS_MAX := 5
const MOON_CHANCE_ROCKY := 0.28; const MOON_CHANCE_GAS := 0.55
const MAX_MOONS_ROCKY := 2;      const MAX_MOONS_GAS   := 4
const SOL_SECTOR_ID := "Sector_Alpha_0_0_0"
const SECTOR_UTILS  := preload("res://scripts/autoload/SectorUtils.gd")

# Kepler III: Erde-Orbit (200 Units) = 15 Minuten Echtzeit
const ORBIT_REFERENCE_RADIUS := 200.0
const ORBIT_REFERENCE_PERIOD := 900.0

const MOON_CLEARANCE_FIRST := 20.0
const MOON_CLEARANCE_NEXT  := 15.0

var _cache: Dictionary = {}

func ensure_sector_generated(sector_id: String) -> Dictionary:
	if _cache.has(sector_id): return _cache[sector_id]
	var result := _generate_sector(sector_id)
	_apply_resource_overrides(sector_id, result)
	_cache[sector_id] = result
	
	# NEU: System in die Datenbank speichern
	if not result.is_empty():
		GameDatabase.save_system(result)
	
	return result

func get_cached_systems() -> Array:
	var result: Array = []
	for sid in _cache.keys():
		var sys: Dictionary = _cache[sid]
		if not sys.is_empty(): result.append(sys)
	return result

func _orbit_speed_deg(orbit_radius: float) -> float:
	var period: float = ORBIT_REFERENCE_PERIOD \
		* pow(orbit_radius / ORBIT_REFERENCE_RADIUS, 1.5)
	return 360.0 / period

func _generate_sector(sector_id: String) -> Dictionary:
	if sector_id == SOL_SECTOR_ID: return _build_sol_system()
	var sector_seed: int = SECTOR_UTILS.seed_for_sector(GameDatabase.world_seed, sector_id)
	var rng := RandomNumberGenerator.new(); rng.seed = sector_seed
	if rng.randf() > SYSTEM_SPAWN_CHANCE: return {}
	var coords: Vector3i  = SECTOR_UTILS.sector_id_to_coords(sector_id)
	var origin := Vector3(coords.x, coords.y, coords.z) * SECTOR_UTILS.SECTOR_SIZE
	var star_pos := origin + Vector3(
		rng.randf_range(0.0, SECTOR_UTILS.SECTOR_SIZE),
		rng.randf_range(0.0, SECTOR_UTILS.SECTOR_SIZE),
		rng.randf_range(0.0, SECTOR_UTILS.SECTOR_SIZE))
	var soi: float        = rng.randf_range(SOI_MIN, SOI_MAX)
	var star_name: String = StarNames.random_name(rng)
	var planet_count      = rng.randi_range(PLANETS_MIN, PLANETS_MAX)
	var planets: Array    = []; var orbit_radius := 0.0; var prev_planet_radius := 0.0
	for i in range(planet_count):
		var cls: String          = PlanetClassDB.weighted_random_class(rng)
		var radius_range: Array  = PlanetClassDB.classes[cls]["radius"]
		var planet_radius: float = rng.randf_range(float(radius_range[0]), float(radius_range[1]))
		orbit_radius      += prev_planet_radius + planet_radius + rng.randf_range(70.0, 130.0)
		prev_planet_radius = planet_radius
		planets.append({
			"name":            "%s %s" % [star_name, _to_roman(i + 1)],
			"class":           cls,
			"orbit_radius":    orbit_radius,
			"orbit_angle":     rng.randf_range(0.0, 360.0),
			"orbit_speed_deg": _orbit_speed_deg(orbit_radius),
			"radius":          planet_radius,
			"resources":       PlanetClassDB.random_resources(rng, cls),
			"deuterium":       PlanetClassDB.random_deuterium(rng, cls),
			"moons":           _generate_moons(rng, cls, planet_radius,
			                   "%s %s" % [star_name, _to_roman(i + 1)]),
		})
	return {
		"system_id": sector_id + "_sys", "sector_id": sector_id, "name": star_name,
		"position":  star_pos, "sphere_of_influence": soi, "planets": planets,
	}

func _generate_moons(rng: RandomNumberGenerator, cls: String,
		planet_radius: float, planet_name: String) -> Array:
	var is_gas: bool   = PlanetClassDB.classes[cls]["type"] == "gas"
	var chance: float  = MOON_CHANCE_GAS  if is_gas else MOON_CHANCE_ROCKY
	var max_moons: int = MAX_MOONS_GAS    if is_gas else MAX_MOONS_ROCKY
	var moons: Array   = []
	var orbit_r: float = planet_radius + MOON_CLEARANCE_FIRST
	for _i in range(max_moons):
		if rng.randf() > chance: continue
		var moon_r: float = rng.randf_range(0.875, 2.25)
		orbit_r += moon_r
		moons.append({
			"name":              "%s %s" % [planet_name, _moon_letter(moons.size())],
			"orbit_radius":      orbit_r,
			"angular_speed_deg": rng.randf_range(10.0, 40.0),
			"radius":            moon_r,
		})
		orbit_r += moon_r + MOON_CLEARANCE_NEXT
	return moons

func _moon_letter(index: int) -> String: return ["a","b","c","d"][index % 4]

# ── Sol-System (kompakt) ──────────────────────────────────────────────────────
# Erde = 10.0 Units, Erde-Orbit = 200 Units.
# Gasriesen verkleinert, äußere Orbits komprimiert.
#
# Lücken-Nachweis (Oberfläche → Oberfläche):
#   Mars   ↔ Jupiter :  (480-95) - (280+5.25)      = 99.75  ✓
#   Jupiter↔ Saturn  :  (720-56) - (480+95)         = 89.0   ✓
#   Saturn ↔ Uranus  :  (900-26) - (720+56)         = 98.0   ✓
#   Uranus ↔ Neptun  :  (1040-24) - (900+26)        = 90.0   ✓
#   Neptun ↔ Pluto   :  (1140-10.875) - (1040+24)   = 65.125 ✓
func _build_sol_system() -> Dictionary:
	var defs := [
		{"name":"Merkur", "class":"D","radius":  3.75,"orbit_radius":  75.0,"moons":[]},
		{"name":"Venus",  "class":"H","radius":  9.5, "orbit_radius": 137.5,"moons":[]},
		{"name":"Erde",   "class":"M","radius": 10.0, "orbit_radius": 200.0,"moons":[
			{"suffix":"Luna",      "speed":15.0,"moon_r":2.75,"abs_orbit": 24.75},
		]},
		{"name":"Mars",   "class":"K","radius":  5.25,"orbit_radius": 280.0,"moons":[
			{"suffix":"Phobos",    "speed":35.0,"moon_r":1.0, "abs_orbit": 18.25},
			{"suffix":"Deimos",    "speed":20.0,"moon_r":0.875,"abs_orbit":32.125},
		]},
		{"name":"Jupiter","class":"J","radius": 40.0, "orbit_radius": 480.0,"moons":[
			{"suffix":"Io",        "speed":30.0,"moon_r":2.75,"abs_orbit": 52.0},
			{"suffix":"Europa",    "speed":24.0,"moon_r":2.5, "abs_orbit": 65.0 },
			{"suffix":"Ganymed",   "speed":18.0,"moon_r":4.0, "abs_orbit": 80.0 },
			{"suffix":"Callisto",  "speed":12.0,"moon_r":3.75,"abs_orbit": 95.0},
		]},
		{"name":"Saturn", "class":"T","radius": 34.0, "orbit_radius": 720.0,"moons":[
			{"suffix":"Titan",     "speed":16.0,"moon_r":4.0, "abs_orbit": 45.0},
			{"suffix":"Enceladus", "speed":26.0,"moon_r":1.0, "abs_orbit": 56.0},
		]},
		{"name":"Uranus", "class":"6","radius": 18.0, "orbit_radius": 900.0,"moons":[
			{"suffix":"Titania",   "speed":14.0,"moon_r":1.25,"abs_orbit": 26.0},
		]},
		{"name":"Neptun", "class":"7","radius": 16.0, "orbit_radius":1040.0,"moons":[
			{"suffix":"Triton",    "speed":13.0,"moon_r":2.125,"abs_orbit":24.0},
		]},
		{"name":"Pluto",  "class":"Y","radius":  1.875,"orbit_radius":1140.0,"moons":[
			{"suffix":"Charon",    "speed":10.0,"moon_r":1.0, "abs_orbit": 10.875},
		]},
	]

	var angle_step: float = 360.0 / float(defs.size())
	var planets: Array    = []
	for i in range(defs.size()):
		var def: Dictionary      = defs[i]
		var cls: String          = def["class"]
		var planet_radius: float = float(def["radius"])
		var res_r: Array         = PlanetClassDB.classes[cls]["resources"]
		var deu_r: Array         = PlanetClassDB.classes[cls]["deuterium"]
		var moons: Array         = []
		for md in def["moons"]:
			moons.append({
				"name":             "%s %s" % [def["name"], md["suffix"]],
				"orbit_radius":     float(md["abs_orbit"]),
				"angular_speed_deg": float(md["speed"]),
				"radius":           float(md["moon_r"]),
			})
		planets.append({
			"name":            def["name"],
			"class":           cls,
			"orbit_radius":    float(def["orbit_radius"]),
			"orbit_angle":     angle_step * float(i),
			"orbit_speed_deg": _orbit_speed_deg(float(def["orbit_radius"])),
			"radius":          planet_radius,
			"resources":       {"max":(float(res_r[0])+float(res_r[1]))*0.5,
			                    "current":(float(res_r[0])+float(res_r[1]))*0.5},
			"deuterium":       {"max":(float(deu_r[0])+float(deu_r[1]))*0.5,
			                    "current":(float(deu_r[0])+float(deu_r[1]))*0.5},
			"moons":           moons,
		})
	return {
		"system_id": SOL_SECTOR_ID + "_sys", "sector_id": SOL_SECTOR_ID, "name": "Sol",
		"position":  Vector3.ZERO, "sphere_of_influence": SOI_MAX, "planets": planets,
	}

func _apply_resource_overrides(sector_id: String, system: Dictionary) -> void:
	if system.is_empty(): return
	var saved    := load_sector_data_safe(sector_id)
	var min_ov: Dictionary = saved.get("planet_resources",{})
	var deu_ov: Dictionary = saved.get("planet_deuterium",{})
	if min_ov.is_empty() and deu_ov.is_empty(): return
	for planet in system["planets"]:
		var pname: String = planet["name"]
		if min_ov.has(pname): planet["resources"]["current"] = float(min_ov[pname])
		if deu_ov.has(pname) and planet.has("deuterium"):
			planet["deuterium"]["current"] = float(deu_ov[pname])

func load_sector_data_safe(sector_id: String) -> Dictionary:
	return GameDatabase.load_sector_data(sector_id)

func _to_roman(num: int) -> String:
	var vals := [10,9,5,4,1]; var syms := ["X","IX","V","IV","I"]
	var result := ""; var n := num
	for i in range(vals.size()):
		while n >= vals[i]: result += syms[i]; n -= vals[i]
	return result