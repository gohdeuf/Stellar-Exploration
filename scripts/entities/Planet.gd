class_name Planet
extends Node3D

var planet_data: Dictionary = {}
var star_node:   Node3D     = null

const SELF_ROTATION_SPEED_DEG := 10.0
const TEXTURE_VERSION := 3
const TEX_W := 512; const TEX_H := 256
static var _tex_cache: Dictionary = {}

func setup(data: Dictionary, star: Node3D) -> void:
	planet_data = data
	star_node   = star
	add_to_group("planets")

	var cls: String      = data["class"]
	var cd: Dictionary   = PlanetClassDB.classes[cls]
	var r: float         = float(data["radius"])

	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r; sp.height = r * 2.0
	sp.radial_segments = 96; sp.rings = 48
	mi.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.albedo_color   = Color.WHITE
	mat.albedo_texture = _get_tex(cls, cd, String(data["name"]))
	mat.roughness = 0.68 if cd["type"] != "gas" else 0.44
	mat.metallic = 0.0
	mat.metallic_specular = 0.48 if cd["type"] != "gas" else 0.62
	mi.material_override = mat; add_child(mi)
	if cd.has("atmosphere"):
		_add_atmosphere(r, cd["atmosphere"])

	name = String(data["name"]).replace(" ", "_")
	_apply_orbit_position()   # Startposition sofort setzen

func _process(delta: float) -> void:
	rotate_y(deg_to_rad(SELF_ROTATION_SPEED_DEG * delta))
	_apply_orbit_position()

func _apply_orbit_position() -> void:
	if star_node == null or not is_instance_valid(star_node): return
	global_position = SectorGenerator.get_planet_position(star_node.global_position, planet_data)

func _add_atmosphere(radius: float, atmosphere_color: Color) -> void:
	var atmosphere := MeshInstance3D.new()
	atmosphere.name = "Atmosphere"
	var shell := SphereMesh.new()
	shell.radius = radius * 1.055
	shell.height = shell.radius * 2.0
	shell.radial_segments = 96; shell.rings = 48
	atmosphere.mesh = shell
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.albedo_color = atmosphere_color
	material.emission_enabled = true
	material.emission = atmosphere_color
	material.emission_energy_multiplier = 0.65
	atmosphere.material_override = material
	add_child(atmosphere)

# ── Textur-Generierung ────────────────────────────────────────────────────────

func _get_tex(_cls: String, cd: Dictionary, pname: String) -> ImageTexture:
	var key: int = ("%d|%d|%s" % [TEXTURE_VERSION, GameDatabase.world_seed, pname]).hash()
	if _tex_cache.has(key): return _tex_cache[key]
	var noise := FastNoiseLite.new(); noise.seed = int(key & 0x7fffffff)
	noise.frequency = 1.6; noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0; noise.fractal_gain = 0.5
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGB8)
	if cd["type"] == "gas": _fill_gas(img, noise, cd["color"])
	else:                   _fill_rocky(img, noise, cd["color"])
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex; return tex

func _sp(u: float, v: float) -> Vector3:
	var lon := u * TAU; var lat := (v - 0.5) * PI
	return Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))

func _fill_rocky(img: Image, noise: FastNoiseLite, base: Color) -> void:
	var dark := base.darkened(0.4)
	var light := base.lightened(0.3)
	var highlands := base.lightened(0.48)
	var ice := Color(0.9, 0.94, 1.0)
	for y in range(TEX_H):
		var v: float  = float(y) / float(TEX_H - 1)
		var latitude: float = abs(v - 0.5) * 2.0
		for x in range(TEX_W):
			var u: float    = float(x) / float(TEX_W - 1)
			var p: Vector3  = _sp(u, v)
			var continent: float = (noise.get_noise_3d(p.x * 0.72, p.y * 0.72, p.z * 0.72) + 1.0) * 0.5
			var region: float = (noise.get_noise_3d(p.x * 2.2, p.y * 2.2, p.z * 2.2) + 1.0) * 0.5
			var detail: float = (noise.get_noise_3d(p.x * 8.0, p.y * 8.0, p.z * 8.0) + 1.0) * 0.5
			var terrain: float = clamp(continent * 0.58 + region * 0.32 + detail * 0.1, 0.0, 1.0)
			var col: Color = dark.lerp(base, terrain * 2.0) if terrain < 0.5 \
				else base.lerp(light, (terrain - 0.5) * 2.0)
			if continent > 0.68:
				col = col.lerp(highlands, clamp((continent - 0.68) * 2.2, 0.0, 1.0))
			if latitude > 0.82:
				col = col.lerp(ice, clamp((latitude - 0.82) / 0.18, 0.0, 1.0))
			img.set_pixel(x, y, col)

func _fill_gas(img: Image, noise: FastNoiseLite, base: Color) -> void:
	var a := base.darkened(0.32); var b := base.lightened(0.26)
	for y in range(TEX_H):
		var v: float   = float(y) / float(TEX_H - 1)
		var lat: float = (v - 0.5) * PI
		var band: float = sin(lat * 10.0 + noise.get_noise_2d(0.0, lat) * 0.45) * 0.5 + 0.5
		for x in range(TEX_W):
			var u: float   = float(x) / float(TEX_W - 1)
			var p: Vector3 = _sp(u, v)
			var flow: float = noise.get_noise_3d(p.x * 2.0, p.y * 2.0, p.z * 2.0) * 0.25
			var fine: float = noise.get_noise_3d(p.x * 8.0, p.y * 8.0, p.z * 8.0) * 0.08
			var storm: float = max(noise.get_noise_3d(p.x * 4.0, p.y * 4.0, p.z * 4.0), 0.0)
			var t: float = clamp(band + flow + fine, 0.0, 1.0)
			var col: Color = a.lerp(b, t)
			if storm > 0.72 and band > 0.55:
				col = col.lightened(clamp((storm - 0.72) * 1.8, 0.0, 0.2))
			img.set_pixel(x, y, col)