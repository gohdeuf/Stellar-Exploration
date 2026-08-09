class_name TacticalDisplay
extends Node2D

const VP_SIZE      := 512.0
const RADAR_RADIUS := 220.0
const RANGE_UNITS  := 500.0
const CENTER       := Vector2(256.0, 256.0)
const FONT_SIZE_S  := 10
const FONT_SIZE_M  := 13

# ═══════════════════════════════════════════════════════════════════════════════
#  YAW-KORREKTUR – Einfach anpassen falls das Radar um 90° (oder mehr) versetzt
#  ist. Der Wert wird in Radiant zu ship_yaw addiert.
#  Beispiele:
#    0.0              = keine Korrektur (Standard)
#    PI / 2.0         = +90°  nach rechts drehen
#    -PI / 2.0        = -90°  nach links drehen
#    deg_to_rad(90.0) = +90° (alternativ in Grad)
# ═══════════════════════════════════════════════════════════════════════════════
const YAW_OFFSET := deg_to_rad(0.0)

var ship: Node3D = null

func set_ship(s: Node3D) -> void: ship = s

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if ship == null: return
	var ship_pos: Vector3 = ship.global_position
	var fwd: Vector3      = -ship.transform.basis.z
	var ship_yaw: float   = atan2(fwd.x, fwd.z) + YAW_OFFSET

	# Hintergrund
	draw_rect(Rect2(Vector2.ZERO, Vector2(VP_SIZE, VP_SIZE)),
		Color(0.01, 0.05, 0.03), true)

	# Entfernungsringe
	for i in range(1, 5):
		var ring_r: float = RADAR_RADIUS * float(i) / 4.0
		draw_arc(CENTER, ring_r, 0.0, TAU, 64,
			Color(0.0, 0.35, 0.12, 0.45), 1.0)
		draw_string(ThemeDB.fallback_font,
			CENTER + Vector2(ring_r + 3.0, -3.0),
			"%.0fu" % (RANGE_UNITS * float(i) / 4.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_S,
			Color(0.0, 0.55, 0.22, 0.75))

	# Außenring
	draw_arc(CENTER, RADAR_RADIUS, 0.0, TAU, 80,
		Color(0.0, 0.80, 0.30, 0.85), 2.0)

	# Fadenkreuz
	var dim := Color(0.0, 0.28, 0.10, 0.4)
	draw_line(CENTER + Vector2(-RADAR_RADIUS, 0),
		CENTER + Vector2( RADAR_RADIUS, 0), dim, 1.0)
	draw_line(CENTER + Vector2(0, -RADAR_RADIUS),
		CENTER + Vector2(0,  RADAR_RADIUS), dim, 1.0)

	# ── Planeten ─────────────────────────────────────────────────────────────
	for node in get_tree().get_nodes_in_group("planets"):
		if not node is Planet: continue
		var planet: Planet  = node as Planet
		var rp: Vector2     = _to_radar(planet.global_position - ship_pos, ship_yaw)
		if rp.length() > RADAR_RADIUS: continue
		var cls: String     = planet.planet_data.get("class", "M")
		var is_gas: bool    = PlanetClassDB.classes.has(cls) and \
			PlanetClassDB.classes[cls]["type"] == "gas"
		var col: Color      = Color(0.75, 0.55, 0.15) if is_gas else Color(0.18, 0.75, 0.35)
		var pr: float       = float(planet.planet_data.get("radius", 5.0))
		var dot_r: float    = clamp(pr / 15.0 * 7.0, 3.0, 11.0)
		draw_circle(CENTER + rp, dot_r, col)
		draw_string(ThemeDB.fallback_font,
			CENTER + rp + Vector2(dot_r + 3.0, 4.0),
			str(planet.planet_data.get("name", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_S,
			col.lightened(0.25))

	# ── Monde ────────────────────────────────────────────────────────────────
	for node in get_tree().get_nodes_in_group("moons"):
		var rp: Vector2 = _to_radar(node.global_position - ship_pos, ship_yaw)
		if rp.length() > RADAR_RADIUS: continue
		draw_circle(CENTER + rp, 2.5, Color(0.55, 0.55, 0.65, 0.8))

	# ── Stationen ────────────────────────────────────────────────────────────
	for node in get_tree().get_nodes_in_group("stations"):
		var rp: Vector2 = _to_radar(node.global_position - ship_pos, ship_yaw)
		if rp.length() > RADAR_RADIUS: continue
		draw_rect(Rect2(CENTER + rp - Vector2(4, 4), Vector2(8, 8)),
			Color(0.0, 0.85, 0.95), false, 1.5)
		draw_string(ThemeDB.fallback_font,
			CENTER + rp + Vector2(6.0, 4.0), "ST",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_S,
			Color(0.0, 0.85, 0.95, 0.9))

	# ── NPC-Schiffe / Gegner ─────────────────────────────────────────────────
	for node in get_tree().get_nodes_in_group("npc_ships"):
		var rp: Vector2      = _to_radar(node.global_position - ship_pos, ship_yaw)
		var clamped: Vector2 = rp
		var on_edge: bool    = false
		if rp.length() > RADAR_RADIUS:
			clamped = rp.normalized() * (RADAR_RADIUS - 8.0)
			on_edge = true
		var threat_col: Color = Color(1.0, 0.15, 0.05) if not on_edge \
			else Color(1.0, 0.50, 0.10)
		# Feindrichtung
		var enemy_fwd: Vector3 = Vector3.ZERO
		if node is Node3D:
			enemy_fwd = -(node as Node3D).transform.basis.z
		var enemy_angle: float = atan2(enemy_fwd.x, enemy_fwd.z) - ship_yaw
		var tip_dir := Vector2(sin(enemy_angle), -cos(enemy_angle))
		var perp    := Vector2(-tip_dir.y, tip_dir.x)
		var tc      := CENTER + clamped
		var pts     := PackedVector2Array([
			tc + tip_dir * 8.0,
			tc - tip_dir * 4.0 + perp * 5.0,
			tc - tip_dir * 4.0 - perp * 5.0,
		])
		# ← Fix: draw_colored_polygon nimmt eine Color, keine PackedColorArray
		draw_colored_polygon(pts, threat_col)
		if on_edge:
			var dist_u: int = int(rp.length() / RADAR_RADIUS * RANGE_UNITS)
			draw_string(ThemeDB.fallback_font,
				tc + Vector2(9.0, 4.0), "%du" % dist_u,
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_S,
				Color(1.0, 0.55, 0.10, 0.9))

	# ── Spielerschiff ─────────────────────────────────────────────────────────
	draw_circle(CENTER, 5.5, Color(0.20, 1.0, 0.40))
	var arrow := PackedVector2Array([
		CENTER + Vector2( 0.0, -17.0),
		CENTER + Vector2(-5.5,  -5.0),
		CENTER + Vector2( 5.5,  -5.0),
	])
	# ← Fix: einzelne Color statt PackedColorArray
	draw_colored_polygon(arrow, Color(0.20, 1.0, 0.40))

	# ── HUD-Texte ─────────────────────────────────────────────────────────────
	var hdg: float = fmod(rad_to_deg(ship_yaw) + 360.0, 360.0)
	draw_string(ThemeDB.fallback_font,
		Vector2(8.0, 18.0), "HDG %03d°" % int(hdg),
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_M,
		Color(0.20, 1.0, 0.45, 1.0))

	# Legende
	var legend_y: float = VP_SIZE - 56.0
	var legend_entries: Array = [
		["■", Color(0.20, 0.75, 0.35), "Planet (Rocky)"],
		["■", Color(0.75, 0.55, 0.15), "Planet (Gas)"],
		["□", Color(0.00, 0.85, 0.95), "Station"],
		["▲", Color(1.00, 0.15, 0.05), "Feind"],
	]
	for entry in legend_entries:
		draw_string(ThemeDB.fallback_font,
			Vector2(8.0, legend_y),
			"%s %s" % [entry[0], entry[2]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_S,
			entry[1] as Color)
		legend_y += 14.0

	draw_string(ThemeDB.fallback_font,
		Vector2(8.0, VP_SIZE - 6.0), "SENSOR v1.0",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE_S,
		Color(0.0, 0.60, 0.25, 0.65))

# ── Hilfsfunktion: Weltoffset → Radar-Pixel (Heading-Up) ──────────────────────
func _to_radar(world_offset: Vector3, ship_yaw: float) -> Vector2:
	var flat := Vector2(world_offset.x, world_offset.z)
	var ca   := cos(-ship_yaw); var sa := sin(-ship_yaw)
	var rot  := Vector2(flat.x * ca - flat.y * sa, flat.x * sa + flat.y * ca)
	return Vector2(rot.x, -rot.y) * (RADAR_RADIUS / RANGE_UNITS)
