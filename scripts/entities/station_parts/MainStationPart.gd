class_name MainStationPart
extends Node3D
# Haupt-Stationsmodul: zentraler Hub fuer alle anderen Station-Parts.
# Visuell: Torusring + Zentralzylinder + 4 Solarfluegelpaare.

const VISUAL_SCALE := 0.1

var _ring_time: float = 0.0
var _outer_ring: MeshInstance3D = null

func _ready() -> void:
	scale = Vector3.ONE * VISUAL_SCALE
	add_to_group("stations")
	add_to_group("main_station_parts")
	_build_visual()

func _build_visual() -> void:
	# Zentraler Hub-Zylinder
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new(); hm.top_radius = 3.0; hm.bottom_radius = 3.0; hm.height = 4.0
	hub.mesh = hm
	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.55, 0.65, 0.80); hub_mat.metallic = 0.8; hub_mat.roughness = 0.2
	hub.material_override = hub_mat; add_child(hub)

	# Innenraum / Docking-Halle
	var interior := MeshInstance3D.new()
	var im := BoxMesh.new(); im.size = Vector3(6.0, 3.2, 6.0)
	interior.mesh = im
	var interior_mat := StandardMaterial3D.new(); interior_mat.albedo_color = Color(0.16, 0.2, 0.28)
	interior_mat.metallic = 0.2; interior_mat.roughness = 0.7; interior.material_override = interior_mat
	add_child(interior)

	# Aeusserer Torus-Ring (langsam drehend)
	_outer_ring = MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 7.5; tm.outer_radius = 9.0
	_outer_ring.mesh = tm
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.3, 0.45, 0.75); ring_mat.metallic = 0.9; ring_mat.roughness = 0.15
	_outer_ring.material_override = ring_mat; add_child(_outer_ring)

	# 4 Solarfluegelpaare
	for i in range(4):
		var angle: float = float(i) * PI * 0.5
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new(); wm.size = Vector3(10.0, 0.3, 2.5); wing.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.1, 0.15, 0.6); wmat.metallic = 0.5
		wmat.emission_enabled = true; wmat.emission = Color(0.05, 0.1, 0.4)
		wmat.emission_energy_multiplier = 0.8
		wing.material_override = wmat
		wing.position = Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0)
		wing.rotation.y = angle; add_child(wing)

	# Andock-Licht
	var dock_light := OmniLight3D.new()
	dock_light.light_color = Color(0.4, 0.7, 1.0); dock_light.omni_range = 4.0
	dock_light.light_energy = 2.0; add_child(dock_light)

func _process(delta: float) -> void:
	_ring_time += delta
	if _outer_ring != null:
		_outer_ring.rotation.y = _ring_time * 0.08
