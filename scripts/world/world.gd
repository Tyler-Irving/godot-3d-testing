extends Node3D
## World manager: creates, stores, and manages all chunks.
##
## ===== 3D CONCEPT: NODE3D (formerly Spatial in Godot 3) =====
## Node3D is the base type for anything that exists in 3D space.
## It has a Transform3D (position, rotation, scale). All 3D nodes inherit from it.
## This world node acts as a container — its children are the chunk nodes.
##
## ===== 3D CONCEPT: COORDINATE SYSTEM =====
## Godot uses a right-handed Y-up coordinate system:
##   +X = right
##   +Y = up
##   -Z = forward (into the screen)
## This matches most 3D conventions. Block (0,0,0) is at the world origin.
## ========================================

const CHUNK_SIZE := 16

## World dimensions in chunks
@export var world_width_chunks := 4    # X direction
@export var world_height_chunks := 4   # Y direction
@export var world_depth_chunks := 4    # Z direction

## The random seed for terrain generation. Change this for different worlds.
@export var world_seed := 42

## Dictionary mapping Vector3i chunk positions to Chunk nodes
var chunks: Dictionary = {}

var generator: WorldGenerator

signal world_generated


func _ready() -> void:
	generator = WorldGenerator.new()
	generator.set_seed(world_seed)
	generate_world()


## Create all chunks and generate terrain.
func generate_world() -> void:
	# Clear existing chunks
	for chunk_pos in chunks:
		chunks[chunk_pos].queue_free()
	chunks.clear()

	# Create chunks in a grid
	for cx in world_width_chunks:
		for cy in world_height_chunks:
			for cz in world_depth_chunks:
				var chunk_pos := Vector3i(cx, cy, cz)
				_create_chunk(chunk_pos)

	# Generate terrain for all chunks first (so neighbors exist for mesh building)
	for chunk_pos in chunks:
		generator.generate_chunk(chunks[chunk_pos])

	# Then build meshes (needs neighbor data to know which faces to hide)
	for chunk_pos in chunks:
		chunks[chunk_pos].rebuild_mesh()

	world_generated.emit()


## Create a single chunk node at the given chunk position.
func _create_chunk(chunk_pos: Vector3i) -> Chunk:
	var chunk := Chunk.new()
	chunk.chunk_position = chunk_pos
	chunk.world = self

	# Position the chunk in world space.
	# Chunk (1, 0, 2) → world position (16, 0, 32)
	chunk.position = Vector3(chunk_pos) * CHUNK_SIZE

	chunk.name = "Chunk_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	add_child(chunk)
	chunks[chunk_pos] = chunk
	return chunk


## Get the block type at an absolute world block position.
## Used by chunks to query their neighbors during mesh building.
func get_block_at_world_pos(world_x: int, world_y: int, world_z: int) -> int:
	# Convert world position to chunk position and local position.
	# Integer division gives us the chunk; modulo gives the position within it.
	# We use floored division to handle negative coordinates correctly.
	var chunk_x := _floor_div(world_x, CHUNK_SIZE)
	var chunk_y := _floor_div(world_y, CHUNK_SIZE)
	var chunk_z := _floor_div(world_z, CHUNK_SIZE)

	var local_x := _positive_mod(world_x, CHUNK_SIZE)
	var local_y := _positive_mod(world_y, CHUNK_SIZE)
	var local_z := _positive_mod(world_z, CHUNK_SIZE)

	var chunk_pos := Vector3i(chunk_x, chunk_y, chunk_z)
	if chunks.has(chunk_pos):
		return chunks[chunk_pos].get_block(local_x, local_y, local_z)

	# Outside the world boundary — return AIR so chunk edges render faces
	return BlockData.BlockType.AIR


## Set a block at a world position and rebuild affected chunks.
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

	chunks[chunk_pos].set_block(local_x, local_y, local_z, block_type)
	chunks[chunk_pos].rebuild_mesh()

	# If the block is on a chunk edge, rebuild the neighboring chunk too.
	# Otherwise you'd see a hole in the neighbor's mesh where this block was.
	_rebuild_neighbors_if_needed(chunk_pos, local_x, local_y, local_z)


## Check if a modified block is on a chunk edge and rebuild neighbors.
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


## Floored integer division (GDScript's / truncates toward zero, which breaks
## for negative coordinates: -1 / 16 = 0 in GDScript, but we want -1).
static func _floor_div(a: int, b: int) -> int:
	return int(floorf(float(a) / float(b)))


## Positive modulo (GDScript's % can return negative values for negative inputs).
static func _positive_mod(a: int, b: int) -> int:
	return ((a % b) + b) % b
