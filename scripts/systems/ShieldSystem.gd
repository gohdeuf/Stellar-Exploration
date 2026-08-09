class_name ShieldSystem
extends Node

const MAX_INTEGRITY      := 100.0
const RECHARGE_RATE      := 15.0       # Haltbarkeit / Sekunde beim Aufladen
const RECHARGE_DEUT_COST := 5.0        # Deuterium / Sekunde beim Aufladen
const IDLE_DEUT_COST     := 0.5        # Deuterium / Sekunde im normalen Betrieb
const TORPEDO_DAMAGE     := 25.0       # Haltbarkeitsverlust bei Torpedo-Treffer
const PSE_DAMAGE_PER_SEC := 8.0        # Haltbarkeitsverlust / Sekunde bei PSE-Treffer
const PSE_HULL_DAMAGE_PCT:= 0.05       # Schiff nimmt nur 5 % des PSE-Schadens

var integrity: float = MAX_INTEGRITY
var shield_active: bool = true
var _ship: Node3D = null
var _hud: Node = null

func setup(ship: Node3D, hud: Node = null) -> void:
	_ship = ship
	_hud = hud

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_shield"):
		toggle()
	if _ship == null:
		return
	if not shield_active:
		return  # Aus = kein Deuterium-Verbrauch

	if integrity < MAX_INTEGRITY:
		# Aufladen – mehr Deuterium
		var recharge_cost: float = RECHARGE_DEUT_COST * delta
		if GameDatabase.get_resource("deuterium") >= int(recharge_cost):
			GameDatabase.spend_resource("deuterium", int(recharge_cost))
			integrity = minf(MAX_INTEGRITY, integrity + RECHARGE_RATE * delta)
		else:
			# Nicht genug Deuterium zum Aufladen → normaler Betrieb versuchen
			_try_idle_cost(delta)
	else:
		# Normaler Betrieb – weniger Deuterium
		_try_idle_cost(delta)

func _try_idle_cost(delta: float) -> void:
	var idle_cost: float = IDLE_DEUT_COST * delta
	if GameDatabase.get_resource("deuterium") >= int(idle_cost):
		GameDatabase.spend_resource("deuterium", int(idle_cost))
	else:
		shield_active = false
		if _hud != null:
			_hud.show_message(Locale.t("shield.no_deuterium"))

## Wird von Torpedo aufgerufen. Gibt true zurück, wenn der Torpedo abgefangen wurde.
func intercept_torpedo() -> bool:
	if not shield_active or integrity <= 0.0:
		return false
	integrity -= TORPEDO_DAMAGE
	if integrity <= 0.0:
		integrity = 0.0
		shield_active = false
		if _hud != null:
			_hud.show_message(Locale.t("shield.collapsed"))
	return true

## Wird von feindlichem PSE aufgerufen. Gibt den reduzierten Schaden zurück.
func absorb_pse(raw_damage: float, delta: float) -> float:
	if not shield_active or integrity <= 0.0:
		return raw_damage
	integrity -= PSE_DAMAGE_PER_SEC * delta
	if integrity <= 0.0:
		integrity = 0.0
		shield_active = false
		if _hud != null:
			_hud.show_message(Locale.t("shield.collapsed"))
	return raw_damage * PSE_HULL_DAMAGE_PCT

func toggle() -> void:
	shield_active = not shield_active
	if _hud != null:
		var key: String = "shield.activated" if shield_active else "shield.deactivated"
		_hud.show_message(Locale.t(key))

func get_status_text() -> String:
	if not shield_active:
		return Locale.t("shield.status_off")
	return Locale.t("shield.status_on", {"integrity": int(integrity), "max": int(MAX_INTEGRITY)})