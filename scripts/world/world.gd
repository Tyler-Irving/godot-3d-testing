extends Node3D
## World manager: creates, stores, and manages all chunks.
##
## Handles chunk creation, terrain generation, save/load serialization,
## and torch placement. Acts as the central coordinator for all world state.

const CHUNK_SIZE := 16

@export var world_width_chunks := 4
@export var world_height_chunks := 4
@export var world_depth_chunks := 4
@export var world_seed := 42

## Dictionary mapping Vector3i chunk positions to Chunk nodes
var chunks: Dictionary = {}

var generator: WorldGenerator
var torch_manager: TorchManager

signal world_generated


func _ready() -> void:
	generator = WorldGenerator.new()
	generator.set_seed(world_seed)

	torch_manager = TorchManager.new()
	torch_manager.name = "TorchManager"
	add_child(torch_manager)

	generate_world()


## Create all chunks and generate terrain.
func generate_world() -> void:
	# Clear existing chunks and torches
	for chunk_pos in chunks:
		chunks[chunk_pos].queue_free()
	chunks.clear()
	torch_manager.clear_all()

	# Create chunks in a grid
	for cx in world_width_chunks:
		for cy in world_height_chunks:
			for cz in world_depth_chunks:
				var chunk_pos := Vector3i(cx, cy, cz)
				_create_chunk(chunk_pos)

	# Generate terrain for all chunks first
	for chunk_pos in chunks:
		generator.generate_chunk(chunks[chunk_pos])

	# Then build meshes (needs neighbor data)
	for chunk_pos in chunks:
		chunks[chunk_pos].rebuild_mesh()

	world_generated.emit()


func _create_chunk(chunk_pos: Vector3i) -> Chunk:
	var chunk := Chunk.new()
	chunk.chunk_position = chunk_pos
	chunk.world = self
	chunk.position = Vector3(chunk_pos) * CHUNK_SIZE
	chunk.name = "Chunk_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	add_child(chunk)
	chunks[chunk_pos] = chunk
	return chunk


func get_block_at_world_pos(world_x: int, world_y: int, world_z: int) -> int:
	var chunk_x := _floor_div(world_x, CHUNK_SIZE)
	var chunk_y := _floor_div(world_y, CHUNK_SIZE)
	var chunk_z := _floor_div(world_z, CHUNK_SIZE)

	var local_x := _positive_mod(world_x, CHUNK_SIZE)
	var local_y := _positive_mod(world_y, CHUNK_SIZE)
	var local_z := _positive_mod(world_z, CHUNK_SIZE)

	var chunk_pos := Vector3i(chunk_x, chunk_y, chunk_z)
	if chunks.has(chunk_pos):
		return chunks[chunk_pos].get_block(local_x, local_y, local_z)
	return BlockData.BlockType.AIR


func set_block_at_world_pos(world_x: int, world_y: int, world_z: int, block_type: int) -> void:
	var chunk_x := _floor_div(world_x, CHUNK_SIZE)
	var chunk_y := _floor_div(world_y, CHUNK_SIZE)
	var chunk_z := _floor_div(world_z, CHUNK_SIZE)

	var local_x := _positive_mod(world_x, CHUNK_SIZE)
	var local_y := _positive_mod(world_y, CHUNK_SIZE)
	var local_z := _positive_mod(world_z, CHUNK_SIZE)

	var chunk_pos := Vector3i(chunk_x, chunk_y, chunk_z)
	if not chunks.has(chunk_pos):
		return

	# Handle torch placement/removal
	var world_pos := Vector3i(world_x, world_y, world_z)
	var old_type := chunks[chunk_pos].get_block(local_x, local_y, local_z)

	if old_type == BlockData.BlockType.TORCH:
		torch_manager.remove_torch(world_pos)

	chunks[chunk_pos].set_block(local_x, local_y, local_z, block_type)
	chunks[chunk_pos].rebuild_mesh()

	if block_type == BlockData.BlockType.TORCH:
		torch_manager.add_torch(world_pos)

	_rebuild_neighbors_if_needed(chunk_pos, local_x, local_y, local_z)


func _rebuild_neighbors_if_needed(chunk_pos: Vector3i, lx: int, ly: int, lz: int) -> void:
	if lx == 0:
		_rebuild_chunk(chunk_pos + Vector3i(-1, 0, 0))
	if lx == CHUNK_SIZE - 1:
		_rebuild_chunk(chunk_pos + Vector3i(1, 0, 0))
	if ly == 0:
		_rebuild_chunk(chunk_pos + Vector3i(0, -1, 0))
	if ly == CHUNK_SIZE - 1:
		_rebuild_chunk(chunk_pos + Vector3i(0, 1, 0))
	if lz == 0:
		_rebuild_chunk(chunk_pos + Vector3i(0, 0, -1))
	if lz == CHUNK_SIZE - 1:
		_rebuild_chunk(chunk_pos + Vector3i(0, 0, 1))


func _rebuild_chunk(chunk_pos: Vector3i) -> void:
	if chunks.has(chunk_pos):
		chunks[chunk_pos].rebuild_mesh()


## --- Save/Load support ---

## Get all chunk block data for saving.
func get_save_data() -> Dictionary:
	var data := {}
	for chunk_pos in chunks:
		var chunk: Chunk = chunks[chunk_pos]
		var key := "%d,%d,%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
		var flat_blocks := []
		for x in CHUNK_SIZE:
			for y in CHUNK_SIZE:
				for z in CHUNK_SIZE:
					flat_blocks.append(chunk.blocks[x][y][z])
		data[key] = flat_blocks
	return data


## Apply saved block data to existing chunks, then rebuild meshes.
func apply_save_data(chunks_data: Dictionary) -> void:
	for key in chunks_data:
		var parts := key.split(",")
		if parts.size() != 3:
			continue
		var chunk_pos := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		if not chunks.has(chunk_pos):
			continue

		var chunk: Chunk = chunks[chunk_pos]
		var flat_blocks: Array = chunks_data[key]
		var idx := 0
		for x in CHUNK_SIZE:
			for y in CHUNK_SIZE:
				for z in CHUNK_SIZE:
					chunk.blocks[x][y][z] = int(flat_blocks[idx])
					idx += 1

	# Rebuild all meshes after loading
	for chunk_pos in chunks:
		chunks[chunk_pos].rebuild_mesh()


## Get all torch world positions for saving.
func get_torch_positions() -> Array:
	var positions := []
	for pos in torch_manager._torch_lights:
		positions.append(pos)
	return positions


## Restore torches from saved positions.
func restore_torches(positions: Array[Vector3i]) -> void:
	torch_manager.clear_all()
	for pos in positions:
		torch_manager.add_torch(pos)


static func _floor_div(a: int, b: int) -> int:
	return int(floorf(float(a) / float(b)))


static func _positive_mod(a: int, b: int) -> int:
	return ((a % b) + b) % b
