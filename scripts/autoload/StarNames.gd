extends Node
const PREFIXES:=["Vulcan","Andor","Risa","Bajor","Cardassia","Romulus","Tellar","Trill","Betazed","Deneva","Rigel","Talos","Ceti","Ferenginar","Cait","Benzar","Denobula","Ardana"]
const SUFFIXES:=["Prime","Major","Minor","Alpha","Beta","Gamma","I","II","III","IV","V"]
const CATALOGS := ["TOI", "Kepler", "K2", "HD", "WASP", "TIC"]

func random_names(rng: RandomNumberGenerator) -> Dictionary:
	var legacy_rng := RandomNumberGenerator.new()
	legacy_rng.state = rng.state
	var legacy_name: String = _legacy_random_name(legacy_rng)
	var catalog: String = CATALOGS[rng.randi_range(0, CATALOGS.size() - 1)]
	var designation: String
	if catalog == "HD":
		designation = "HD %d" % rng.randi_range(10000, 250000)
	elif catalog == "TIC":
		designation = "TIC %d" % rng.randi_range(100000000, 999999999)
	else:
		designation = "%s-%d" % [catalog, rng.randi_range(100, 9999)]
	return {"name": designation, "legacy_name": legacy_name}

func random_name(rng: RandomNumberGenerator) -> String:
	return String(random_names(rng)["name"])

func _legacy_random_name(rng: RandomNumberGenerator) -> String:
	return "%s %s"%[PREFIXES[rng.randi_range(0,PREFIXES.size()-1)],SUFFIXES[rng.randi_range(0,SUFFIXES.size()-1)]]
