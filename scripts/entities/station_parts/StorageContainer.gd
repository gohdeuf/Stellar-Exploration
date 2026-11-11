class_name StorageContainer
extends Node3D
# Lager-Modul fuer Stationsressourcen.
# Jeder Container erhoht die Stationskapazitaet um CAPACITY_PER_UNIT.

const CAPACITY_PER_UNIT := {
	"minerals": 5000,
	"hydrogen": 8000,
	"deuterium": 2000,
	"tritium": 1500,
	"antimatter": 200,
	"durasteel": 500,
}

func _ready() -> void:
	add_to_group("stations")
	add_to_group("storage_containers")
	_build_visual()

func _build_visual() -> void:
	# Hauptkorpus
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(10.0, 10.0, 14.0); body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.45, 0.40); mat.metallic = 0.6; mat.roughness = 0.5
	body.material_override = mat; add_child(body)

	# Innenraum / Ladebucht
	var interior := MeshInstance3D.new()
	var ibm := BoxMesh.new(); ibm.size = Vector3(7.6, 6.6, 10.4)
	interior.mesh = ibm
	var imat := StandardMaterial3D.new(); imat.albedo_color = Color(0.18, 0.22, 0.25); imat.roughness = 0.8
	interior.material_override = imat; add_child(interior)

	# 4 Verstaerkungsrippen (horizontal)
	var rib_mat := StandardMaterial3D.new()
	rib_mat.albedo_color = Color(0.3, 0.3, 0.3); rib_mat.metallic = 0.85
	for i in range(4):
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new(); rm.size = Vector3(10.6, 0.5, 14.6); rib.mesh = rm
		rib.material_override = rib_mat
		rib.position.y = -3.5 + float(i) * 2.3; add_child(rib)

	# 4 Eckpfeiler
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.25, 0.25, 0.25); pillar_mat.metallic = 0.9
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			var pillar := MeshInstance3D.new()
			var pm := CylinderMesh.new(); pm.top_radius = 0.4; pm.bottom_radius = 0.4; pm.height = 10.2
			pillar.mesh = pm; pillar.material_override = pillar_mat
			pillar.position = Vector3(float(dx) * 4.8, 0.0, float(dz) * 6.8); add_child(pillar)

	# Ladeluken (grosse Frontflaechen)
	var hatch_mat := StandardMaterial3D.new()
	hatch_mat.albedo_color = Color(0.35, 0.38, 0.42); hatch_mat.metallic = 0.7
	for dz in [-1, 1]:
		var hatch := MeshInstance3D.new()
		var hm := BoxMesh.new(); hm.size = Vector3(7.5, 7.5, 0.3); hatch.mesh = hm
		hatch.material_override = hatch_mat
		hatch.position = Vector3(0.0, 0.0, float(dz) * 7.15); add_child(hatch)

	# Gruen-Streifen Sicherheitsmarkierungen
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.1, 0.7, 0.2)
	stripe_mat.emission_enabled = true; stripe_mat.emission = Color(0.05, 0.5, 0.1)
	stripe_mat.emission_energy_multiplier = 0.8
	for side in [-1, 1]:
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.25, 10.2, 0.25); stripe.mesh = sm
		stripe.material_override = stripe_mat
		stripe.position = Vector3(float(side) * 5.1, 0.0, 0.0); add_child(stripe)

	# Status-Licht
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 0.9, 0.3); light.omni_range = 20.0; light.light_energy = 0.8
	add_child(light)
