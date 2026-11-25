class_name FusionCore
extends Node3D

const VISUAL_SCALE := 0.1
const POWER_OUTPUT: float = 150.0
const TORUS_CENTER_R: float = 4.0
const TORUS_TUBE_R:   float = 1.4
const NUM_TF_COILS:   int   = 16

var is_enabled: bool  = true          # Togglebar via StationManagement
var power_output: float = POWER_OUTPUT

var _plasma_mat:   StandardMaterial3D = null
var _plasma_light: OmniLight3D        = null
var _plasma_mesh:  MeshInstance3D     = null
var _time: float = 0.0

func _ready() -> void:
	scale = Vector3.ONE * VISUAL_SCALE
	add_to_group("stations"); add_to_group("fusion_cores"); _build_visual()

func _process(delta: float) -> void:
	if not is_enabled:
		power_output = 0.0
		if _plasma_mat   != null: _plasma_mat.emission_energy_multiplier   = 0.08
		if _plasma_light != null: _plasma_light.light_energy = 0.0
		return
	power_output = POWER_OUTPUT
	_time += delta
	var pulse: float    = sin(_time * 1.9)
	var sawtooth: float = fmod(_time * 0.3, 1.0)
	var energy: float   = 4.5 + pulse * 1.8 + (sawtooth * sawtooth) * 2.0
	if _plasma_mat   != null: _plasma_mat.emission_energy_multiplier   = energy
	if _plasma_light != null: _plasma_light.light_energy = 2.5 + pulse * 1.2
	if _plasma_mesh  != null: _plasma_mesh.rotate_y(delta * 0.15)

func _build_visual() -> void:
	_build_central_solenoid(); _build_vacuum_vessel(); _build_plasma()
	_build_tf_coils(); _build_pf_coils(); _build_neutral_beam_injectors(); _build_plasma_light()

func _build_central_solenoid() -> void:
	var sol := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.65; cm.bottom_radius = 0.65; cm.height = 9.5; sol.mesh = cm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.72, 0.45, 0.18); mat.metallic = 0.95; mat.roughness = 0.2
	mat.emission_enabled = true; mat.emission = Color(0.6, 0.3, 0.05); mat.emission_energy_multiplier = 0.4
	sol.material_override = mat; add_child(sol)
	for i in range(8):
		var band := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.72; bm.bottom_radius = 0.72; bm.height = 0.12; band.mesh = bm
		var bmat := StandardMaterial3D.new(); bmat.albedo_color = Color(0.85, 0.55, 0.22); bmat.metallic = 1.0; band.material_override = bmat
		band.position.y = -3.5 + float(i) * 1.0; add_child(band)

func _build_vacuum_vessel() -> void:
	var vessel := MeshInstance3D.new(); var tm := TorusMesh.new()
	tm.inner_radius = TORUS_CENTER_R - TORUS_TUBE_R; tm.outer_radius = TORUS_CENTER_R + TORUS_TUBE_R; vessel.mesh = tm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.28, 0.32, 0.36, 0.55)
	mat.metallic = 0.85; mat.roughness = 0.25; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vessel.material_override = mat; add_child(vessel)

func _build_plasma() -> void:
	_plasma_mesh = MeshInstance3D.new(); var pm := TorusMesh.new()
	pm.inner_radius = TORUS_CENTER_R - TORUS_TUBE_R * 0.75; pm.outer_radius = TORUS_CENTER_R + TORUS_TUBE_R * 0.75
	pm.rings = 48; pm.ring_segments = 32; _plasma_mesh.mesh = pm
	_plasma_mat = StandardMaterial3D.new(); _plasma_mat.albedo_color = Color(1.0, 0.65, 0.05, 0.9)
	_plasma_mat.emission_enabled = true; _plasma_mat.emission = Color(1.0, 0.55, 0.0)
	_plasma_mat.emission_energy_multiplier = 5.5; _plasma_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plasma_mesh.material_override = _plasma_mat; add_child(_plasma_mesh)

func _build_tf_coils() -> void:
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.22, 0.28, 0.35); mat.metallic = 0.92; mat.roughness = 0.12
	for i in range(NUM_TF_COILS):
		var angle: float = float(i) / float(NUM_TF_COILS) * TAU
		var coil := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(5.2, 9.8, 0.28); coil.mesh = bm
		coil.material_override = mat; coil.position = Vector3(cos(angle)*TORUS_CENTER_R,0.0,sin(angle)*TORUS_CENTER_R); coil.rotation.y = -angle; add_child(coil)
		var rail := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(5.2,0.12,0.35); rail.mesh = rm
		var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color(0.3,0.55,1.0); rmat.emission_enabled = true; rmat.emission = Color(0.2,0.45,1.0); rmat.emission_energy_multiplier = 1.5
		rail.material_override = rmat; rail.position = Vector3(cos(angle)*TORUS_CENTER_R,4.85,sin(angle)*TORUS_CENTER_R); rail.rotation.y = -angle; add_child(rail)

func _build_pf_coils() -> void:
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.18,0.24,0.32); mat.metallic = 0.95; mat.roughness = 0.1
	mat.emission_enabled = true; mat.emission = Color(0.05,0.1,0.3); mat.emission_energy_multiplier = 0.6
	for ypos in [-3.6, -1.8, 0.0, 1.8, 3.6]:
		var ring := MeshInstance3D.new(); var tm := TorusMesh.new()
		tm.inner_radius = TORUS_CENTER_R+TORUS_TUBE_R+0.3; tm.outer_radius = TORUS_CENTER_R+TORUS_TUBE_R+0.7
		ring.mesh = tm; ring.material_override = mat; ring.position.y = ypos; add_child(ring)

func _build_neutral_beam_injectors() -> void:
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.5,0.5,0.55); mat.metallic = 0.8
	var beam_mat := StandardMaterial3D.new(); beam_mat.albedo_color = Color(0.8,0.7,0.2,0.6)
	beam_mat.emission_enabled = true; beam_mat.emission = Color(1.0,0.9,0.1); beam_mat.emission_energy_multiplier = 3.0; beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(4):
		var angle: float = float(i)*TAU*0.25+TAU*0.125
		var inj := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius=0.3; cm.bottom_radius=0.3; cm.height=4.0; inj.mesh=cm; inj.material_override=mat
		var r: float = TORUS_CENTER_R+TORUS_TUBE_R+2.5; inj.position=Vector3(cos(angle)*r,0.6,sin(angle)*r); inj.rotation.y=angle+PI*0.5; inj.rotation.z=deg_to_rad(25); add_child(inj)
		var beam := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius=0.08; bm.bottom_radius=0.08; bm.height=3.5; beam.mesh=bm; beam.material_override=beam_mat
		beam.position=Vector3(cos(angle)*(r-1.5),0.6,sin(angle)*(r-1.5)); beam.rotation.y=angle+PI*0.5; beam.rotation.z=deg_to_rad(25); add_child(beam)

func _build_plasma_light() -> void:
	_plasma_light = OmniLight3D.new(); _plasma_light.light_color = Color(1.0,0.55,0.05)
	_plasma_light.omni_range = 6.0; _plasma_light.light_energy = 4.0; add_child(_plasma_light)