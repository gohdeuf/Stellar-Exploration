class_name CrewSystem
extends Node
# Crew-System mit Notfall-KI.
# Bedingung A/B (Referenz 3): Automatischer Flucht-Autopilot.
# N = Notfall-KI manuell ein-/ausschalten (zum Testen).
# activate_damage() wird durch Kampftreffer auf die Bruecke aufgerufen.

enum BridgeState { NORMAL = 0, DAMAGED = 1, DESTROYED = 2 }

var ship: Node3D = null
var _hud:  Node  = null
var crew_count: int      = 5
var bridge_state: int    = BridgeState.NORMAL
var emergency_ai_active: bool = false
var speed_modifier:    float = 1.0
var rotation_modifier: float = 1.0

signal emergency_ai_engaged()
signal emergency_ai_disengaged()

func setup(p_ship: Node3D, p_hud: Node = null) -> void:
	ship = p_ship; _hud = p_hud
	_update_modifiers()

func _process(delta: float) -> void:
	if ship == null: return
	if Input.is_action_just_pressed("emergency_ai_toggle"):
		toggle_emergency_ai()
	if emergency_ai_active:
		_run_emergency_ai(delta)

func toggle_emergency_ai() -> void:
	if emergency_ai_active:
		emergency_ai_active = false
		if _hud: _hud.show_message(Locale.t("crew.ai_disengaged"))
		emergency_ai_disengaged.emit()
	else:
		_activate_emergency_ai()

func activate_damage(amount: float) -> void:
	if amount <= 0.0: return
	if bridge_state == BridgeState.NORMAL:
		bridge_state = BridgeState.DAMAGED
		_update_modifiers()
		if _hud: _hud.show_message(Locale.t("crew.bridge_damaged"))
	elif bridge_state == BridgeState.DAMAGED:
		bridge_state = BridgeState.DESTROYED
		_activate_emergency_ai()

func _activate_emergency_ai() -> void:
	emergency_ai_active = true
	if _hud: _hud.show_message(Locale.t("crew.emergency_ai"))
	emergency_ai_engaged.emit()

func _run_emergency_ai(delta: float) -> void:
	var threat: Node3D = find_nearest_threat()
	if threat == null: return
	var flee_vec: Vector3 = ship.global_position - threat.global_position
	if flee_vec.length() < 0.001: return
	var flee_dir: Vector3 = flee_vec.normalized()
	ship.global_position += flee_dir * 75.0 * speed_modifier * delta
	var up: Vector3 = Vector3.UP if abs(flee_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var look_basis: Basis = Basis.looking_at(flee_dir, up)
	var target_quat := Quaternion(look_basis)
	ship.quaternion = ship.quaternion.slerp(target_quat, delta * 1.5)

func find_nearest_threat() -> Node3D:
	var best: Node3D = null
	var best_dist: float = INF
	for npc in get_tree().get_nodes_in_group("npc_ships"):
		var dist: float = ship.global_position.distance_to(npc.global_position)
		if dist < 1000.0 and dist < best_dist:
			best = npc as Node3D; best_dist = dist
	return best

func _update_modifiers() -> void:
	match bridge_state:
		BridgeState.NORMAL:    speed_modifier = 1.0;  rotation_modifier = 1.0
		BridgeState.DAMAGED:   speed_modifier = 0.75; rotation_modifier = 0.6
		BridgeState.DESTROYED: speed_modifier = 0.5;  rotation_modifier = 0.3
