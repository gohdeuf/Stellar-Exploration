extends Node

# Alle Radien ×2.5 gegenüber der 50%-Version.
# Referenz: Erde (M-Klasse) Mittelwert = 10.0 Units.
# Gas-Riesen: J-Klasse bis 22.5, T bis 30, 9 bis 35 Units.
const classes: Dictionary = {
	"D": {"type":"rocky","color":Color(0.55,0.52,0.48),"radius":[ 2.5,  6.25],"resources":[  0,  30],"deuterium":[  0,   5]},
	"H": {"type":"rocky","color":Color(0.75,0.45,0.15),"radius":[ 3.75,10.0 ],"resources":[ 10,  80],"deuterium":[  5,  20]},
	"K": {"type":"rocky","color":Color(0.65,0.55,0.35),"radius":[ 5.0, 10.0 ],"resources":[ 20, 100],"deuterium":[ 10,  30]},
	"L": {"type":"rocky","color":Color(0.50,0.60,0.30),"radius":[ 5.0, 11.25],"resources":[ 30, 120],"deuterium":[ 15,  40]},
	"M": {"type":"rocky","color":Color(0.25,0.55,0.30),"radius":[ 6.25,12.5 ],"resources":[ 50, 200],"deuterium":[ 30,  80]},
	"N": {"type":"rocky","color":Color(0.35,0.40,0.45),"radius":[ 3.75, 8.75],"resources":[  5,  40],"deuterium":[  5,  15]},
	"Y": {"type":"rocky","color":Color(0.80,0.25,0.10),"radius":[ 1.25, 6.25],"resources":[  0,  20],"deuterium":[  0,   5]},
	"J": {"type":"gas",  "color":Color(0.80,0.65,0.40),"radius":[10.0, 22.5 ],"resources":[  0,   0],"deuterium":[1000, 10000]},
	"T": {"type":"gas",  "color":Color(0.85,0.80,0.60),"radius":[12.5, 30.0 ],"resources":[  0,   0],"deuterium":[1500, 12500]},
	"6": {"type":"gas",  "color":Color(0.55,0.70,0.80),"radius":[11.25,27.5 ],"resources":[  0,   0],"deuterium":[2000, 15000]},
	"7": {"type":"gas",  "color":Color(0.30,0.50,0.85),"radius":[11.25,25.0 ],"resources":[  0,   0],"deuterium":[2500, 18000]},
	"9": {"type":"gas",  "color":Color(0.60,0.45,0.30),"radius":[15.0, 35.0 ],"resources":[  0,   0],"deuterium":[3000, 20000]},
}

const CLASS_WEIGHTS: Dictionary = {
	"D":12,"H":10,"K":10,"L":8,"M":15,"N":7,"Y":3,
	"J":12,"T":10,"6":6,"7":6,"9":4
}

func weighted_random_class(rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for w in CLASS_WEIGHTS.values(): total += w
	var roll: int = rng.randi_range(0, total - 1)
	var cumul: int = 0
	for cls in CLASS_WEIGHTS.keys():
		cumul += CLASS_WEIGHTS[cls]
		if roll < cumul: return cls
	return "M"

func random_resources(rng: RandomNumberGenerator, cls: String) -> Dictionary:
	var r: Array = classes[cls]["resources"]
	var val: float = rng.randf_range(float(r[0]), float(r[1]))
	return {"max": val, "current": val}

func random_deuterium(rng: RandomNumberGenerator, cls: String) -> Dictionary:
	var d: Array = classes[cls]["deuterium"]
	var val: float = rng.randf_range(float(d[0]), float(d[1]))
	return {"max": val, "current": val}