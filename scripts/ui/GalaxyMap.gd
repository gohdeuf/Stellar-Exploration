class_name GalaxyMap
extends Control

@export var refresh_interval: float = 2.0
@export var pixels_per_unit: float = 0.05

var player: Node3D
var _systems: Array = []
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _dragging := false
var _refresh_timer: float = 0.0

func _ready() -> void:
	visible = false
	_refresh_systems()

func set_player(node: Node3D) -> void:
	player = node

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		visible = not visible
		get_viewport().set_input_as_handled()
		if visible: _refresh_systems()
		return
	if not visible: return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clamp(_zoom * 1.1, 0.1, 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clamp(_zoom / 1.1, 0.1, 20.0)
		queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		_pan_offset += event.relative
		queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	_refresh_timer += delta
	if _refresh_timer >= refresh_interval:
		_refresh_timer = 0.0
		_refresh_systems()
		queue_redraw()

func _refresh_systems() -> void:
	# Alle jemals generierten Systeme aus der Datenbank laden
	_systems = GameDatabase.get_all_systems()

func _world_to_map(pos: Vector3) -> Vector2:
	return size / 2.0 + _pan_offset + Vector2(pos.x, pos.z) * pixels_per_unit * _zoom

func _draw() -> void:
	if player == null: return
	var pmp := _world_to_map(player.global_position)

	# Stationen (nur aktuell geladene)
	for station in get_tree().get_nodes_in_group("stations"):
		if station is Node3D:
			var mp := _world_to_map((station as Node3D).global_position)
			draw_circle(mp, 2.2, Color(0.2, 0.9, 0.9))

	# Alle Systeme aus der DB
	for sys in _systems:
		var p: Vector3 = sys["position"]
		var mp := _world_to_map(p)
		draw_circle(mp, 4.0, Color(1.0, 0.9, 0.4))
		draw_string(ThemeDB.fallback_font, mp + Vector2(6, -6), sys["name"])

		var hd: float = p.y - player.global_position.y
		var ind := "^" if hd > 50.0 else ("v" if hd < -50.0 else "~")
		var ic := Color(1.0, 0.6, 0.1) if hd > 50.0 else (Color(0.3, 0.6, 1.0) if hd < -50.0 else Color(0.7, 0.7, 0.7))
		draw_string(ThemeDB.fallback_font, mp + Vector2(6, 8), ind, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ic)

		if _zoom > 4.0:
			for pl in sys.get("planets", []):
				draw_circle(_world_to_map(p + Vector3(pl["orbit_radius"], 0, 0)), 2.0, Color(0.6, 0.6, 0.9))

	# Spieler
	draw_line(pmp, pmp + Vector2(-sin(player.rotation.y), -cos(player.rotation.y)) * 12.0, Color(0.2, 1.0, 0.3), 2.0)
	draw_circle(pmp, 5.0, Color(0.2, 1.0, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(10, size.y - 10),
		Locale.t("map.info", {
			"x":"%.0f"%player.global_position.x,
			"y":"%.0f"%player.global_position.y,
			"z":"%.0f"%player.global_position.z,
			"zoom":"%.1f"%_zoom,
			"count":_systems.size()
		}))