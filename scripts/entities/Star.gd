class_name Star
extends Node3D

var system_name: String = ""

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	# Radius 7.5 = ~0.75× Erdradius (10.0) – Spielkompromiss, Sonne wäre real 109× Erde
	sp.radius = 7.5; sp.height = 15.0; mi.mesh = sp
	sp.radial_segments = 64; sp.rings = 32
	var mat := StandardMaterial3D.new()
	mat.albedo_color        = Color(1.0, 0.9, 0.4)
	mat.emission_enabled    = true
	mat.emission            = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat; add_child(mi)
	_add_corona(8.7, 0.12, 1.8)
	_add_corona(10.2, 0.045, 1.2)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.95, 0.8)
	l.light_energy = 4.0
	l.omni_range  = 2500.0   # Reicht bis Pluto (1225 Units)
	add_child(l)

func _add_corona(radius: float, alpha: float, energy: float) -> void:
	var corona := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = radius; shell.height = radius * 2.0
	shell.radial_segments = 64; shell.rings = 32
	corona.mesh = shell
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.render_priority = 1
	material.albedo_color = Color(1.0, 0.36, 0.08, alpha)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.3, 0.04)
	material.emission_energy_multiplier = energy
	corona.material_override = material
	add_child(corona)

func set_system_name(n: String) -> void:
	system_name = n; name = n.replace(" ", "_")