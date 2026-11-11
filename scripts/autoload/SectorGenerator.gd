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
	_cache[sector_id] = result; return result

func get_cached_systems() -> Array:
	var result: Array = []
	for sid in _cache.keys():
		var sys: Dictionary = _cache[sid]
		if not sys.is_empty(): result.append(sys)
	return result

func get_sector_nebulae(sector_id: String) -> Array[Dictionary]:
	var nebula_seed: int = SECTOR_UTILS.seed_for_sector(
		GameDatabase.world_seed, sector_id + "_nebula")
	var rng := RandomNumberGenerator.new()
	rng.seed = nebula_seed
	if rng.randf() >= NEBULA_SPAWN_CHANCE:
		return []

	var coords: Vector3i = SECTOR_UTILS.sector_id_to_coords(sector_id)
	var sector_origin := Vector3(coords.x, coords.y, coords.z) * SECTOR_UTILS.SECTOR_SIZE
	var nebulae: Array[Dictionary] = []
	var nebula_count: int = rng.randi_range(NEBULA_COUNT_MIN, NEBULA_COUNT_MAX)
	for nebula_index in range(nebula_count):
		var name_rng := RandomNumberGenerator.new()
		name_rng.seed = SECTOR_UTILS.seed_for_sector(
			GameDatabase.world_seed, "%s_nebula_name_%d" % [sector_id, nebula_index])
		nebulae.append({
			"name": _generate_nebula_name(name_rng),
			"position": sector_origin + Vector3(
				rng.randf_range(NEBULA_EDGE_MARGIN, SECTOR_UTILS.SECTOR_SIZE - NEBULA_EDGE_MARGIN),
				rng.randf_range(NEBULA_EDGE_MARGIN, SECTOR_UTILS.SECTOR_SIZE - NEBULA_EDGE_MARGIN),
				rng.randf_range(NEBULA_EDGE_MARGIN, SECTOR_UTILS.SECTOR_SIZE - NEBULA_EDGE_MARGIN)),
			"size": Vector3(
				rng.randf_range(NEBULA_SIZE_MIN, NEBULA_SIZE_MAX),
				rng.randf_range(NEBULA_SIZE_MIN * 0.55, NEBULA_SIZE_MAX * 0.65),
				rng.randf_range(NEBULA_SIZE_MIN, NEBULA_SIZE_MAX)),
			"color": Color.from_hsv(rng.randf_range(0.55, 0.9), 0.65, 1.0),
			"resources": {
				"hydrogen": rng.randf_range(350.0, 1200.0),
				"deuterium": rng.randf_range(50.0, 200.0),
				"tritium": rng.randf_range(1.0, 20.0),
			},
		})
	return nebulae

func _generate_nebula_name(rng: RandomNumberGenerator) -> String:
	var feature: String = NEBULA_FEATURES[rng.randi_range(0, NEBULA_FEATURES.size() - 1)]
	var constellation: String = NEBULA_CONSTELLATIONS[
		rng.randi_range(0, NEBULA_CONSTELLATIONS.size() - 1)]
	match rng.randi_range(0, 3):
		0:
			return "%s Nebula" % feature
		1:
			return "%s %s Nebula" % [constellation, feature]
		2:
			return "%s %s" % [constellation, ["Veil", "Cloud", "Complex"][rng.randi_range(0, 2)]]
		_:
			return "%s %s" % [feature, ["Cloud", "Veil", "Complex"][rng.randi_range(0, 2)]]

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

# ── Sol-System ────────────────────────────────────────────────────────────────
# Erde = 10.0 Units, Erde-Orbit = 200 Units.
# Alle abs_orbit = Abstand vom PLANETENZENTRUM (nicht Oberfläche).
#
# Lücken-Nachweis (Oberfläche → Oberfläche bei ungünstigster Ausrichtung):
#   Venus  ↔ Erde     :  (200-10) - (137.5+9.5)       = 43.0  ✓
#   Erde   ↔ Mars     :  (280-33) - (200+27.5)         = 19.5  ✓
#   Mars   ↔ Jupiter  :  (550-198) - (280+33)          = 39.0  ✓
#   Jupiter↔ Saturn   :  (950-134.5) - (550+198)       = 67.5  ✓
#   Saturn ↔ Uranus   :  (1200-57.5) - (950+134.5)     = 58.0  ✓
#   Uranus ↔ Neptun   :  (1380-58)   - (1200+57.5)     = 64.5  ✓
#   Neptun ↔ Pluto    :  (1500-11.875) - (1380+58)     = 50.1  ✓
func _build_sol_system() -> Dictionary:
	# [name, class, planet_radius, orbit_radius,
	#  moons: [suffix, speed, moon_r, abs_orbit_from_planet_center]]
	var defs := [
		{"name":"Merkur", "class":"D","radius":  3.75,"orbit_radius":  75.0,"moons":[]},
		{"name":"Venus",  "class":"H","radius":  9.5, "orbit_radius": 137.5,"moons":[]},
		{"name":"Erde",   "class":"M","radius": 10.0, "orbit_radius": 200.0,"moons":[
			# planet_r(10) + gap(12) + moon_r(2.75) = 24.75  → clearance 12.0 ✓
			{"suffix":"Luna",      "speed":15.0,"moon_r":2.75,"abs_orbit": 24.75},
		]},
		{"name":"Mars",   "class":"K","radius":  5.25,"orbit_radius": 280.0,"moons":[
			# 5.25 + 12 + 1.0 = 18.25   → clearance 12.0 ✓
			{"suffix":"Phobos",    "speed":35.0,"moon_r":1.0, "abs_orbit": 18.25},
			# 18.25 + 1.0 + 12 + 0.875 = 32.125  → gap to Phobos = 12.0 ✓
			{"suffix":"Deimos",    "speed":20.0,"moon_r":0.875,"abs_orbit":32.125},
		]},
		# Jupiter 11.21× Erde = 112 Units – orbit 550
		# Callisto-Reichweite: 194.25+3.75=198 → Jupiter-Seite: 550-198=352
		# Mars-Seite max: 280+33=313 → Lücke = 352-313 = 39 ✓
		{"name":"Jupiter","class":"J","radius":112.0, "orbit_radius": 550.0,"moons":[
			# 112 + 15 + 2.75 = 129.75  → clearance 15.0 ✓
			{"suffix":"Io",        "speed":30.0,"moon_r":2.75,"abs_orbit":129.75},
			# 129.75 + 2.75 + 15 + 2.5 = 150.0  → gap 15.0 ✓
			{"suffix":"Europa",    "speed":24.0,"moon_r":2.5, "abs_orbit":150.0 },
			# 150.0 + 2.5 + 15 + 4.0 = 171.5   → gap 15.0 ✓
			{"suffix":"Ganymed",   "speed":18.0,"moon_r":4.0, "abs_orbit":171.5 },
			# 171.5 + 4.0 + 15 + 3.75 = 194.25  → gap 15.0 ✓
			{"suffix":"Callisto",  "speed":12.0,"moon_r":3.75,"abs_orbit":194.25},
		]},
		# Saturn 9.45× Erde = 94.5 Units – orbit 950
		# Titan-Reichweite: 113.5+4.0=117.5, Enceladus: 133.5+1.0=134.5
		# Saturn-Seite: 950-134.5=815.5, Jupiter-Seite max: 550+198=748 → Lücke 67.5 ✓
		{"name":"Saturn", "class":"T","radius": 94.5, "orbit_radius": 950.0,"moons":[
			# 94.5 + 15 + 4.0 = 113.5  → clearance 15.0 ✓
			{"suffix":"Titan",     "speed":16.0,"moon_r":4.0, "abs_orbit":113.5},
			# 113.5 + 4.0 + 15 + 1.0 = 133.5  → gap 15.0 ✓
			{"suffix":"Enceladus", "speed":26.0,"moon_r":1.0, "abs_orbit":133.5},
		]},
		# Uranus 4.01× Erde = 40.0 Units – orbit 1200
		{"name":"Uranus", "class":"6","radius": 40.0, "orbit_radius":1200.0,"moons":[
			# 40.0 + 15 + 1.25 = 56.25  → clearance 15.0 ✓
			{"suffix":"Titania",   "speed":14.0,"moon_r":1.25,"abs_orbit": 56.25},
		]},
		# Neptun 3.88× Erde = 38.75 Units – orbit 1380
		{"name":"Neptun", "class":"7","radius": 38.75,"orbit_radius":1380.0,"moons":[
			# 38.75 + 15 + 2.125 = 55.875  → clearance 15.0 ✓
			{"suffix":"Triton",    "speed":13.0,"moon_r":2.125,"abs_orbit":55.875},
		]},
		# Pluto 0.186× Erde = 1.875 Units – orbit 1500
		{"name":"Pluto",  "class":"Y","radius":  1.875,"orbit_radius":1500.0,"moons":[
			# 1.875 + 8 + 1.0 = 10.875  → clearance 8.0 ✓
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