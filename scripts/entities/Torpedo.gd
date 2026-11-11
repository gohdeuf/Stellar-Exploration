class_name Torpedo
extends Node3D

var damage: float = 200.0
var speed: float  = 350.0
var lifetime: float = 6.0
var _age: float = 0.0
var _direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	_build_visual()

func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3; cm.bottom_radius = 0.3; cm.height = 2.0
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mat.emission_energy_multiplier = 4.0
	mi.material_override = mat
	mi.rotation_degrees.x = 90.0
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.1)
	light.omni_range = 25.0; light.light_energy = 2.0
	add_child(light)

func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free(); return
	if _direction == Vector3.ZERO:
		_direction = -global_transform.basis.z
	global_position += _direction * speed * delta

	# ── Spieler-Treffer (mit Schild-Check) ─────────────────────────────────────
	var player_ship := get_tree().get_first_node_in_group("player_ship")
	if player_ship != null and global_position.distance_to(player_ship.global_position) < 6.0:
		var shield: ShieldSystem = player_ship.get_meta("shield_system", null)
		if shield != null and shield.intercept_torpedo():
			_explode()
			return
		if player_ship.has_method("take_damage"):
			player_ship.take_damage(damage)
		_explode()
		return

	# ── NPC-Treffer ────────────────────────────────────────────────────────────
	for npc in get_tree().get_nodes_in_group("npc_ships"):
		if global_position.distance_to(npc.global_position) < 6.0:
			if npc.has_method("take_damage"):
				npc.take_damage(damage)
			_explode()
			return

func _explode() -> void:
	if get_parent() == null: queue_free(); return
	var light := OmniLight3D.new()
	get_parent().add_child(light)
	light.global_position = global_position
	light.light_color = Color(1.0, 0.5, 0.1)
	light.omni_range = 80.0; light.light_energy = 8.0
	var tween := get_tree().create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.8)
	tween.tween_callback(light.queue_free)
	queue_free()