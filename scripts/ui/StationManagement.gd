class_name StationManagement
extends Node

const SCAN_RADIUS := 250.0
const REFRESH_INT := 0.6

var ship: Node3D = null
var _hud: Node   = null
var is_open: bool = false
var _ui:    Control = null
var _info_label: Label = null
var _timer: float = 0.0
var _nearest_hub: Node3D = null

func setup(p_ship: Node3D, p_hud: Node) -> void:
	ship = p_ship; _hud = p_hud; _build_ui()

func _build_ui() -> void:
	_ui = Control.new()
	_ui.anchor_left=1.0; _ui.anchor_right=1.0; _ui.anchor_top=0.0; _ui.anchor_bottom=1.0
	_ui.offset_left=-310; _ui.offset_right=-10; _ui.offset_top=10; _ui.offset_bottom=-10
	_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; _ui.visible=false
	var bg := ColorRect.new(); bg.color=Color(0,0,0,0.80); bg.anchor_right=1.0; bg.anchor_bottom=1.0; _ui.add_child(bg)
	var vbox := VBoxContainer.new(); vbox.anchor_right=1.0; vbox.anchor_bottom=1.0
	vbox.offset_left=12; vbox.offset_top=12; vbox.offset_right=-12; vbox.offset_bottom=-12; _ui.add_child(vbox)
	var title := Label.new(); title.text="─── STATION MGMT ───"
	title.add_theme_color_override("font_color",Color(1.0,0.75,0.2)); title.add_theme_font_size_override("font_size",15); vbox.add_child(title)
	_info_label = Label.new(); _info_label.text="Suche Station..."; _info_label.autowrap_mode=TextServer.AUTOWRAP_WORD
	_info_label.add_theme_font_size_override("font_size",12); vbox.add_child(_info_label)
	var sep := HSeparator.new(); vbox.add_child(sep)
	# Toggle-Buttons
	var btn_row := HBoxContainer.new(); btn_row.add_theme_constant_override("separation",6); vbox.add_child(btn_row)
	var btn_fc := Button.new(); btn_fc.text="FC Ein/Aus"; btn_fc.custom_minimum_size=Vector2(130,0)
	btn_fc.pressed.connect(_toggle_fusion_cores); btn_row.add_child(btn_fc)
	var btn_am := Button.new(); btn_am.text="AM Ein/Aus"; btn_am.custom_minimum_size=Vector2(130,0)
	btn_am.pressed.connect(_toggle_am_factories); btn_row.add_child(btn_am)
	var sep2 := HSeparator.new(); vbox.add_child(sep2)
	var hint := Label.new(); hint.text="[D] Einlagern\n[W] Auslagern\n[F2] Schliessen"
	hint.add_theme_color_override("font_color",Color(0.6,0.6,0.6)); hint.add_theme_font_size_override("font_size",12); vbox.add_child(hint)
	get_tree().root.call_deferred("add_child", _ui)

func open_panel() -> void:
	if is_open: return
	is_open=true; _ui.visible=true; _timer=REFRESH_INT; _refresh()

func close_panel() -> void:
	if not is_open: return
	is_open=false; _ui.visible=false

func toggle_panel() -> void:
	if is_open: close_panel()
	else: open_panel()

func _process(delta: float) -> void:
	if not is_open: return
	_timer += delta
	if _timer >= REFRESH_INT: _timer=0.0; _refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton): return
	if Input.is_action_just_pressed("station_management"):
		toggle_panel()
		return
	if not is_open: return
	if Input.is_action_just_pressed("deposit_resources"):  _deposit()
	if Input.is_action_just_pressed("withdraw_resources"): _withdraw()

func _refresh() -> void:
	if ship==null: _info_label.text="Kein Schiff."; return
	_nearest_hub = _find_nearest_hub()
	if _nearest_hub==null:
		_info_label.text="Keine Station\nin Reichweite (%d Einh.)" % int(SCAN_RADIUS); return

	var sid: String    = _get_hub_station_sid(_nearest_hub)
	var parts: Array   = _get_nearby_parts(_nearest_hub.global_position)
	var is_orbital: bool = _is_in_orbiter(_nearest_hub)

	var power_out: float=0.0; var power_dem: float=0.0
	var fc_count:int=0; var amf_count:int=0; var st_count:int=0; var drill_count:int=0
	var fc_enabled:int=0; var amf_enabled:int=0

	for p in parts:
		if p.is_in_group("fusion_cores"):
			if p is FusionCore:
				power_out += (p as FusionCore).power_output; fc_count+=1
				if (p as FusionCore).is_enabled: fc_enabled+=1
		if p.is_in_group("am_factories"):
			power_dem += AntimatterFactorySmall.REQUIRED_POWER; amf_count+=1
			if p is AntimatterFactorySmall and (p as AntimatterFactorySmall).is_enabled: amf_enabled+=1
			elif p is AntimatterFactoryBig and (p as AntimatterFactoryBig).is_enabled: amf_enabled+=1
		if p.is_in_group("storage_containers"): st_count+=1
		if p.is_in_group("mining_drills"): drill_count+=1

	var am_rate: float=0.0
	for p in parts:
		if p.is_in_group("am_factories"):
			var base: float=0.0; var req: float=1.0
			if p is AntimatterFactorySmall:
				if not (p as AntimatterFactorySmall).is_enabled: continue
				base=AntimatterFactorySmall.AM_BASE_RATE; req=AntimatterFactorySmall.FULL_POWER
			elif p is AntimatterFactoryBig:
				if not (p as AntimatterFactoryBig).is_enabled: continue
				base=AntimatterFactoryBig.AM_BASE_RATE; req=AntimatterFactoryBig.FULL_POWER
			var eff: float = clamp(power_out/req,0.0,1.0) if req>0 else 0.0
			var star: float = AntimatterFactorySmall._get_star_proximity_bonus(p.global_position)
			am_rate += base*eff*star

	var cap_min: int = st_count * StorageContainer.CAPACITY_PER_UNIT["minerals"]
	var cap_deu: int = st_count * StorageContainer.CAPACITY_PER_UNIT["deuterium"]
	var cap_am:  int = st_count * StorageContainer.CAPACITY_PER_UNIT["antimatter"]
	var stored: Dictionary = GameDatabase.get_station_storage(sid)
	var st_min: int = int(stored.get("minerals",  0.0))
	var st_deu: int = int(stored.get("deuterium", 0.0))
	var st_am:  int = int(stored.get("antimatter",0.0))
	var dist: int   = int(ship.global_position.distance_to(_nearest_hub.global_position))
	var orbit_tag: String = " [ORBIT]" if is_orbital else ""

	_info_label.text = (
		"Station%s (%d Einh.)\n" % [orbit_tag, dist] +
		"─────────────────\n" +
		"Leistung: %.0f / %.0f W\n" % [power_out, power_dem] +
		"FC: %d/%d aktiv  AM: %d/%d aktiv\n" % [fc_enabled, fc_count, amf_enabled, amf_count] +
		"AM-Prod: %.3f AM/Sek\n" % am_rate +
		("Bohrer: %dx\n" % drill_count if drill_count>0 else "") +
		"─────────────────\n" +
		"Lager (Min): %d / %d\n" % [st_min, cap_min] +
		"Lager (Deu): %d / %d\n" % [st_deu, cap_deu] +
		"Lager (AM):  %d / %d"   % [st_am,  cap_am]
	)

func _deposit() -> void:
	if _nearest_hub==null: return
	var sid: String = _get_hub_station_sid(_nearest_hub)
	var parts: Array = _get_nearby_parts(_nearest_hub.global_position)
	var st_count: int=0
	for p in parts:
		if p.is_in_group("storage_containers"): st_count+=1
	if st_count==0:
		if _hud: _hud.show_message(Locale.t("station.no_storage")); return
	GameDatabase.deposit_to_station(sid,
		st_count*StorageContainer.CAPACITY_PER_UNIT["minerals"],
		st_count*StorageContainer.CAPACITY_PER_UNIT["deuterium"],
		st_count*StorageContainer.CAPACITY_PER_UNIT["antimatter"])
	if _hud: _hud.show_message(Locale.t("station.deposited")); _refresh()

func _withdraw() -> void:
	if _nearest_hub==null: return
	GameDatabase.withdraw_from_station(_get_hub_station_sid(_nearest_hub))
	if _hud: _hud.show_message(Locale.t("station.withdrawn")); _refresh()

func _toggle_fusion_cores() -> void:
	if _nearest_hub==null: return
	for p in _get_nearby_parts(_nearest_hub.global_position):
		if p.is_in_group("fusion_cores") and p is FusionCore:
			(p as FusionCore).is_enabled = not (p as FusionCore).is_enabled
	_refresh()

func _toggle_am_factories() -> void:
	if _nearest_hub==null: return
	for p in _get_nearby_parts(_nearest_hub.global_position):
		if p is AntimatterFactorySmall:
			(p as AntimatterFactorySmall).is_enabled = not (p as AntimatterFactorySmall).is_enabled
		elif p is AntimatterFactoryBig:
			(p as AntimatterFactoryBig).is_enabled = not (p as AntimatterFactoryBig).is_enabled
	_refresh()

func _get_hub_station_sid(hub: Node3D) -> String:
	var parent: Node = hub.get_parent()
	while parent != null:
		if parent.is_in_group("station_orbiters"): return str(parent.get("orbit_id"))
		parent = parent.get_parent()
	return GameDatabase.get_station_id(hub.global_position)

func _is_in_orbiter(node: Node3D) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent.is_in_group("station_orbiters"): return true
		parent = parent.get_parent()
	return false

func _find_nearest_hub() -> Node3D:
	var best: Node3D=null; var best_dist: float=INF
	for node in get_tree().get_nodes_in_group("main_station_parts"):
		var d: float=ship.global_position.distance_to(node.global_position)
		if d<SCAN_RADIUS and d<best_dist: best=node; best_dist=d
	if best==null:
		for node in get_tree().get_nodes_in_group("stations"):
			var d: float=ship.global_position.distance_to(node.global_position)
			if d<SCAN_RADIUS and d<best_dist: best=node; best_dist=d
	return best

func _get_nearby_parts(hub_pos: Vector3) -> Array:
	var result: Array=[]
	for node in get_tree().get_nodes_in_group("stations"):
		if hub_pos.distance_to(node.global_position)<SCAN_RADIUS: result.append(node)
	return result

func _count_group(parts: Array, group: String) -> int:
	var c: int=0
	for p in parts:
		if p.is_in_group(group): c+=1
	return c