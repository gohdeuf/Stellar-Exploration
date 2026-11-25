class_name Station
extends Node3D

const VISUAL_SCALE := 0.1

func _ready() -> void:
	scale = Vector3.ONE * VISUAL_SCALE
	add_to_group("stations")
	var body := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = Vector3(8, 8, 8); body.mesh = bx
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.2, 0.4, 0.9)
	mat.metallic = 0.7; mat.roughness = 0.2; body.material_override = mat; add_child(body)
	var interior := MeshInstance3D.new(); var ibx := BoxMesh.new(); ibx.size = Vector3(5.6, 4.8, 5.6)
	var imat := StandardMaterial3D.new(); imat.albedo_color = Color(0.12, 0.18, 0.24); imat.metallic = 0.2; imat.roughness = 0.8
	interior.mesh = ibx; interior.material_override = imat; interior.position.y = 0.0; add_child(interior)
	var light := OmniLight3D.new(); light.light_color = Color(0.3, 0.6, 1.0)
	light.omni_range = 3.5; light.light_energy = 1.5; add_child(light)
