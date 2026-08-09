class_name Main
extends Node3D

const SAVE_INTERVAL     := 2.0
const SKYBOX_ASSET_PATH := "res://assets/skybox/starfield_panorama.png"

var ship:          Ship
var camera_rig:    CameraRig
var world_manager: WorldManager
var soi_tracker:   SOITracker
var _soi_notif:    SOINotification
var _save_timer:   float = 0.0

func _ready() -> void:
	if GameDatabase.needs_seed_setup:
		var d: PackedScene = preload("res://scenes/UI/WorldSeedDialog.tscn")
		var dlg: WorldSeedDialog = d.instantiate(); add_child(dlg)
		dlg.seed_confirmed.connect(_on_world_seed_confirmed.bind(dlg))
	else:
		_start_game()

func _on_world_seed_confirmed(custom_seed_text: String, dialog: WorldSeedDialog) -> void:
	GameDatabase.finish_new_world_setup(custom_seed_text); dialog.queue_free(); _start_game()

func _start_game() -> void:
	_setup_environment()
	ship = preload("res://scenes/Ship.tscn").instantiate() as Ship
	add_child(ship)

	camera_rig = preload("res://scenes/CameraRig.tscn").instantiate() as CameraRig
	add_child(camera_rig)
	camera_rig.set_target(ship)

	# ── Brücken-View als Kind des Schiffs ──────────────────────────────────────
	var bridge_view: Node3D = BridgeView.new()
	ship.add_child(bridge_view)
	camera_rig.set_bridge_view(bridge_view)
	bridge_view.set_ship_ref(ship)

	world_manager = WorldManager.new(); add_child(world_manager); world_manager.set_player(ship)
	soi_tracker   = SOITracker.new();   add_child(soi_tracker);   soi_tracker.set_player(ship)

	_soi_notif = SOINotification.new(); add_child(_soi_notif)

	soi_tracker.enter_system.connect(_on_enter_system)
	soi_tracker.exit_system.connect(_on_exit_system)
	soi_tracker.enter_planet_soi.connect(_on_enter_planet_soi)
	soi_tracker.exit_planet_soi.connect(_on_exit_planet_soi)
	soi_tracker.enter_moon_soi.connect(_on_enter_moon_soi)
	soi_tracker.exit_moon_soi.connect(_on_exit_moon_soi)

	var player_actions := PlayerActions.new(); add_child(player_actions)
	player_actions.setup(ship, world_manager, _soi_notif)

	var weapon_system := WeaponSystem.new(); ship.add_child(weapon_system)
	weapon_system.setup(ship, _soi_notif)
	var warp_drive := WarpDrive.new(); ship.add_child(warp_drive)
	warp_drive.setup(ship, _soi_notif)
	var crew_system := CrewSystem.new(); ship.add_child(crew_system)
	crew_system.setup(ship, _soi_notif)
	var ship_reactor := ShipReactor.new(); ship.add_child(ship_reactor)
	ship_reactor.setup(ship, _soi_notif)

	# ── Schild-System ──────────────────────────────────────────────────────────
	var shield_system := ShieldSystem.new(); ship.add_child(shield_system)
	shield_system.setup(ship, _soi_notif)
	var shield_data: Dictionary = GameDatabase.player_shield
	shield_system.integrity = float(shield_data.get("integrity", 100.0))
	shield_system.shield_active = bool(shield_data.get("active", true))

	var docking_system := DockingSystem.new(); add_child(docking_system)
	docking_system.setup(ship, _soi_notif)

	var station_editor := preload("res://scripts/ui/StationEditor.gd").new()
	add_child(station_editor); station_editor.setup(ship, _soi_notif, world_manager)

	var station_mgmt := preload("res://scripts/ui/StationManagement.gd").new()
	add_child(station_mgmt); station_mgmt.setup(ship, _soi_notif)
	docking_system.docked.connect(func(_st: Node3D) -> void: station_mgmt.open_panel())

	ship.init_systems(weapon_system, warp_drive, crew_system, shield_system)

	var map: GalaxyMap = preload("res://scenes/UI/GalaxyMap.tscn").instantiate()
	add_child(map); map.set_player(ship)
	add_child(preload("res://scenes/UI/HelpOverlay.tscn").instantiate())
	add_child(preload("res://scenes/UI/InventoryHUD.tscn").instantiate())
	if TouchControls.should_show():
		add_child(preload("res://scenes/UI/TouchControls.tscn").instantiate())

# ── SOI-Callbacks ─────────────────────────────────────────────────────────────
func _on_enter_system(sys: Dictionary) -> void:
	_soi_notif.show_message(Locale.t("soi.entering", {"system": sys.get("name","?")}))
func _on_exit_system(sys: Dictionary) -> void:
	_soi_notif.show_message(Locale.t("soi.leaving",  {"system": sys.get("name","?")}))
func _on_enter_planet_soi(pd: Dictionary, pnode: Node3D) -> void:
	_soi_notif.show_message(Locale.t("soi.entering_planet", {"planet": pd.get("name","?")}))
	if soi_tracker._active_moon_node == null: ship.set_orbit_carrier(pnode)
func _on_exit_planet_soi(planet_name: String) -> void:
	_soi_notif.show_message(Locale.t("soi.leaving_planet", {"planet": planet_name}))
	if soi_tracker._active_moon_node == null: ship.set_orbit_carrier(null)
func _on_enter_moon_soi(mn: String, mnode: Node3D) -> void:
	_soi_notif.show_message(Locale.t("soi.approaching_moon", {"moon": mn}))
	ship.set_orbit_carrier(mnode)
func _on_exit_moon_soi(mn: String) -> void:
	_soi_notif.show_message(Locale.t("soi.leaving_moon", {"moon": mn}))
	ship.set_orbit_carrier(soi_tracker._active_planet_node)

# ── Umgebung ──────────────────────────────────────────────────────────────────
func _setup_environment() -> void:
	var env := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new(); var pano_mat := PanoramaSkyMaterial.new()
	if ResourceLoader.exists(SKYBOX_ASSET_PATH): pano_mat.panorama = load(SKYBOX_ASSET_PATH)
	else: pano_mat.panorama = _build_procedural_starfield()
	sky.sky_material = pano_mat; environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color  = Color(0.15, 0.16, 0.25)
	environment.ambient_light_energy = 0.6
	env.environment = environment; add_child(env)

func _build_procedural_starfield() -> ImageTexture:
	var width := 512; var height := 256
	var img := Image.create(width, height, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new(); noise.seed = int(GameDatabase.world_seed & 0x7fffffff)
	noise.frequency = 0.015; noise.fractal_octaves = 3
	for y in range(height):
		for x in range(width):
			var n := noise.get_noise_2d(float(x), float(y))
			var neb: float = clamp(n * 0.08, 0.0, 0.1)
			img.set_pixel(x, y, Color(0.01+neb*0.5, 0.01+neb*0.35, 0.035+neb*0.7))
	var rng := RandomNumberGenerator.new(); rng.seed = GameDatabase.world_seed
	for _i in range(int(width * height * 0.012)):
		var bri: float = rng.randf_range(0.35, 1.0); var tint: float = rng.randf_range(0.85, 1.0)
		img.set_pixel(rng.randi_range(0,width-1), rng.randi_range(0,height-1), Color(bri,bri*tint,bri))
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL and ship != null:
		_save_timer = 0.0
		var shield: ShieldSystem = ship.get_meta("shield_system", null)
		if shield != null:
			GameDatabase.set_shield_integrity(shield.integrity)
			GameDatabase.set_shield_active(shield.shield_active)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		if ship != null:
			var shield: ShieldSystem = ship.get_meta("shield_system", null)
			if shield != null:
				GameDatabase.set_shield_integrity(shield.integrity)
				GameDatabase.set_shield_active(shield.shield_active)
			GameDatabase.save_player_state(ship.global_position, ship.quaternion)
		if world_manager != null: world_manager.save_all_sector_resources()
		GameDatabase.close_database()   # ← DAS HIER EINFÜGEN
		get_tree().quit()