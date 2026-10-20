class_name WarpDrive
extends Node
# Alcubierre-Metrik-Antrieb (J toggle).
# Benoetigt Deuterium UND Antimaterie (E=mc² - Fusion reicht nicht aus).
#   Aktivierung:  WARP_ENGAGE_DEU_COST Deuterium + WARP_ENGAGE_AM_COST Antimaterie
#   Laufend:      WARP_FUEL_RATE Deu/Sek  +  WARP_AM_RATE AM/Sek
# Keine Manöver moeglich waehrend Warp aktiv.

const WARP_SPEED          := 15000.0
const WARP_FUEL_RATE      := 20.0    # Deuterium/Sek
const WARP_AM_RATE        := 1.0     # Antimaterie/Sek
const WARP_ENGAGE_DEU_COST := 100    # Deuterium beim Aktivieren
const WARP_ENGAGE_AM_COST  := 10     # Antimaterie beim Aktivieren
const RING_COUNT           := 10
const RING_SPACING         := 20.0
const RING_MOVE_SPEED      := 800.0

var ship: Node3D = null
var _hud: Node   = null
var is_warping: bool     = false
var _warp_effect: Node3D = null
var _rings: Array        = []
var _fuel_debt: float    = 0.0
var _am_debt:   float    = 0.0

func setup(p_ship: Node3D, p_hud: Node = null) -> void:
	ship = p_ship; _hud = p_hud

func _process(delta: float) -> void:
	if ship == null: return
	if Input.is_action_just_pressed("toggle_warp"):
		if is_warping: _disengage_warp()
		else:          _engage_warp()
	if is_warping:
		_process_warp(delta)

func _engage_warp() -> void:
	if GameDatabase.get_resource("deuterium") < WARP_ENGAGE_DEU_COST:
		if _hud: _hud.show_message(Locale.t("warp.no_fuel")); return
	if GameDatabase.get_resource("antimatter") < WARP_ENGAGE_AM_COST:
		if _hud: _hud.show_message(Locale.t("warp.no_antimatter")); return
	GameDatabase.spend_resource("deuterium",  WARP_ENGAGE_DEU_COST)
	GameDatabase.spend_resource("antimatter", WARP_ENGAGE_AM_COST)
	is_warping = true; _fuel_debt = 0.0; _am_debt = 0.0
	_rings.clear()
	_warp_effect = _create_warp_effect()
	ship.add_child(_warp_effect)
	if _hud: _hud.show_message(Locale.t("warp.engaged"))

func _disengage_warp() -> void:
	is_warping = false; _rings.clear()
	if _warp_effect != null and is_instance_valid(_warp_effect):
		_warp_effect.queue_free()
	_warp_effect = null
	if _hud: _hud.show_message(Locale.t("warp.disengaged"))

func _process_warp(delta: float) -> void:
	# Deuterium-Verbrauch
	_fuel_debt += WARP_FUEL_RATE * delta
	if _fuel_debt >= 1.0:
		var deu: int = int(_fuel_debt); _fuel_debt -= float(deu)
		if not GameDatabase.spend_resource("deuterium", deu):
			_disengage_warp()
			if _hud: _hud.show_message(Locale.t("warp.fuel_empty")); return
	# Antimaterie-Verbrauch (Hauptenergiequelle fuer Raumzeitkruemmung)
	_am_debt += WARP_AM_RATE * delta
	if _am_debt >= 1.0:
		var am: int = int(_am_debt); _am_debt -= float(am)
		if not GameDatabase.spend_resource("antimatter", am):
			_disengage_warp()
			if _hud: _hud.show_message(Locale.t("warp.am_empty")); return
	ship.global_position -= ship.transform.basis.z * WARP_SPEED * delta
	for ring in _rings:
		if not is_instance_valid(ring): continue
		ring.position.z += RING_MOVE_SPEED * delta
		if ring.position.z > 5.0:
			ring.position.z -= float(RING_COUNT) * RING_SPACING

func is_active() -> bool: return is_warping

func set_active(active: bool) -> bool:
	if active and not is_warping:
		_engage_warp()
	elif not active and is_warping:
		_disengage_warp()
	return is_warping

func toggle_active() -> bool:
	return set_active(not is_warping)

func _create_warp_effect() -> Node3D:
	var effect := Node3D.new(); _rings.clear()
	for i in range(RING_COUNT):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 4.0; tm.outer_radius = 5.0; ring.mesh = tm
		var mat := StandardMaterial3D.new()
		var t_val: float = float(i) / float(RING_COUNT)
		mat.albedo_color = Color(0.1, 0.3 + t_val*0.3, 0.8 + t_val*0.2, 0.45)
		mat.emission_enabled = true; mat.emission = Color(0.1, 0.3 + t_val*0.3, 0.8 + t_val*0.2)
		mat.emission_energy_multiplier = 2.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		ring.position = Vector3(0.0, 0.0, -float(i) * RING_SPACING - RING_SPACING)
		effect.add_child(ring); _rings.append(ring)
	return effect
