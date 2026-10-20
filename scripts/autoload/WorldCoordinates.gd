extends Node

const SECTOR_SIZE := 2000.0
const REBASE_DISTANCE := 10000.0

signal origin_shifted(shift: Vector3)

var origin_offset: Vector3 = Vector3.ZERO
var origin_sector: Vector3i = Vector3i.ZERO

func initialize(world_position: Vector3) -> void:
	origin_sector = Vector3i(
		int(floor(world_position.x / SECTOR_SIZE)),
		int(floor(world_position.y / SECTOR_SIZE)),
		int(floor(world_position.z / SECTOR_SIZE)))
	_update_origin_offset()

func to_world_position(local_position: Vector3) -> Vector3:
	return local_position + origin_offset

func to_local_position(world_position: Vector3) -> Vector3:
	return world_position - origin_offset

func to_sector_coords(local_position: Vector3) -> Vector3i:
	return origin_sector + Vector3i(
		int(floor(local_position.x / SECTOR_SIZE)),
		int(floor(local_position.y / SECTOR_SIZE)),
		int(floor(local_position.z / SECTOR_SIZE)))

func rebase(shift: Vector3) -> void:
	origin_sector += Vector3i(
		roundi(shift.x / SECTOR_SIZE),
		roundi(shift.y / SECTOR_SIZE),
		roundi(shift.z / SECTOR_SIZE))
	_update_origin_offset()
	origin_shifted.emit(shift)

func _update_origin_offset() -> void:
	origin_offset = Vector3(
		float(origin_sector.x) * SECTOR_SIZE,
		float(origin_sector.y) * SECTOR_SIZE,
		float(origin_sector.z) * SECTOR_SIZE)
