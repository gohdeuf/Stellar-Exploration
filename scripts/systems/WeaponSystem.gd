class_name WeaponSystem
extends Node
# Waffensystem: PSE (Partikel-Strahl-Emitter, F gehalten) und Torpedos (T).
# Waffe wechseln: X. Reihenfolge: PSE -> Kaskaden-Torpedo -> Antimaterie-Torpedo.

enum WeaponType { PSE = 0, CASCADE_TORPEDO = 1, ANTIMATTER_TORPEDO = 2 }

const PSE_DAMAGE_PER_SEC := 50.0
const PSE_RANGE          := 250.0
const PSE_CONE_DOT       := 0.97
const TORPEDO_SPEED      := 350.0
const CASCADE_DAMAGE     := 200.0
const ANTIMATTER_DAMAGE  := 800.0
const TORPEDO_COOLDOWN   := 1.5
const ANTIMATTER_COST    := 50

var ship: Node3D = null
var active_weapon: int = WeaponType.PSE
var external_primary_fire: bool = false
var _torpedo_cooldown: float = 0.0
var _pse_beam: MeshInstance3D = null
var _hud: Node = null

func setup(p_ship: Node3D, p_hud: Node = null) -> void:
	ship = p_ship; _hud = p_hud

func _process(delta: float) -> void:
	if ship == null: return
	_torpedo_cooldown = maxf(0.0, _torpedo_cooldown - delta)
	_handle_pse(delta)
	if Input.is_action_just_pressed("fire_torpedo"):
		_fire_torpedo()
	if Input.is_action_just_pressed("next_weapon"):
		_hide_beam()
		active_weapon = (active_weapon + 1) % 3
		if _hud: _hud.show_message(Locale.t("weapons.selected", {"weapon": _weapon_name()}))

func _handle_pse(delta: float) -> void:
	if (not Input.is_action_pressed("fire_primary") and not external_primary_fire) or active_weapon != WeaponType.PSE:
		_hide_beam(); return
	if _pse_beam == null:
		_pse_beam = _create_beam()
		ship.add_child(_pse_beam)
	var fwd: Vector3 = -ship.transform.basis.z
	for npc in get_tree().get_nodes_in_group("npc_ships"):
		var to_npc: Vector3 = npc.global_position - ship.global_position
		var dist: float = to_npc.length()
		if dist > PSE_RANGE: continue
		if to_npc.normalized().dot(fwd) < PSE_CONE_DOT: continue
		if npc.has_method("take_damage"): npc.take_damage(PSE_DAMAGE_PER_SEC * delta)

func _create_beam() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1; cm.bottom_radius = 0.1; cm.height = PSE_RANGE
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.7, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.rotation_degrees.x = 90.0
	mi.position = Vector3(0.0, 0.0, -PSE_RANGE * 0.5)
	return mi

func _hide_beam() -> void:
	if _pse_beam != null and is_instance_valid(_pse_beam):
		_pse_beam.queue_free()
	_pse_beam = null

func _fire_torpedo() -> void:
	if _torpedo_cooldown > 0.0: return
	if active_weapon == WeaponType.ANTIMATTER_TORPEDO:
		if GameDatabase.get_resource("antimatter") < ANTIMATTER_COST:
			if _hud: _hud.show_message(Locale.t("weapons.no_antimatter"))
			return
		GameDatabase.spend_resource("antimatter", ANTIMATTER_COST)
	_torpedo_cooldown = TORPEDO_COOLDOWN
	var dmg: float = ANTIMATTER_DAMAGE if active_weapon == WeaponType.ANTIMATTER_TORPEDO else CASCADE_DAMAGE
	var t := Torpedo.new()
	t.damage = dmg; t.speed = TORPEDO_SPEED
	var parent: Node = ship.get_parent()
	if parent == null: return
	parent.add_child(t)
	t.global_transform = ship.global_transform
	t.global_position = ship.global_position - ship.transform.basis.z * 8.0

func _weapon_name() -> String:
	match active_weapon:
		WeaponType.PSE:                return Locale.t("weapons.pse")
		WeaponType.CASCADE_TORPEDO:    return Locale.t("weapons.cascade_torpedo")
		WeaponType.ANTIMATTER_TORPEDO: return Locale.t("weapons.antimatter_torpedo")
	return ""

func select_weapon(weapon: int) -> bool:
	if weapon < WeaponType.PSE or weapon > WeaponType.ANTIMATTER_TORPEDO:
		return false
	_hide_beam()
	active_weapon = weapon
	return true

func cycle_weapon(step: int = 1) -> int:
	active_weapon = posmod(active_weapon + step, 3)
	return active_weapon

func fire_weapon() -> bool:
	if active_weapon == WeaponType.PSE:
		_handle_pse(0.0)
		return true
	if _torpedo_cooldown > 0.0: return false
	_fire_torpedo()
	return true

func set_primary_fire(active: bool) -> void:
	external_primary_fire = active
