class_name Chunk
extends StaticBody3D
## A single chunk: a 16x16x16 cube of blocks.
##
## ===== 3D CONCEPT: StaticBody3D =====
## Godot has several physics body types:
##   - StaticBody3D:    Doesn't move, used for terrain/walls. Most efficient.
##   - CharacterBody3D: For player-controlled characters. Has move_and_slide().
##   - RigidBody3D:     Physics-simulated objects (falling crates, balls).
##   - AnimatableBody3D: Static bodies that can be moved via code.
## Chunks are terrain — they never move — so StaticBody3D is perfect.
##
## ===== 3D CONCEPT: MeshInstance3D =====
## A MeshInstance3D takes a Mesh resource (the geometry data) and renders it
## in the scene. The mesh itself is just data (vertices, triangles); the
## MeshInstance3D is the node that actually draws it on screen.
##
## ===== 3D CONCEPT: ConcavePolygonShape3D =====
## For collision on complex static geometry, we use ConcavePolygonShape3D.
## It takes an array of triangle vertices and creates a collision shape from them.
## It's efficient for static geometry but can't be used on moving bodies.
## ========================================

const CHUNK_SIZE := 16

## The chunk's position in chunk coordinates (not world coordinates).
## Chunk at (1, 0, 2) starts at world position (16, 0, 32).
var chunk_position := Vector3i.ZERO

## 3D array storing block types: blocks[x][y][z] = BlockType int
var blocks: Array = []

## Reference to the world so we can query neighboring chunks
var world: Node = null

## Child nodes for rendering and collision
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D


func _ready() -> void:
	# Create child nodes programmatically.
	# In 3D, a StaticBody3D needs both a visual (MeshInstance3D) and
	# a collision shape (CollisionShape3D) to be seen and interacted with.
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)

	_collision_shape = CollisionShape3D.new()
	add_child(_collision_shape)

	# Create and assign a material that uses vertex colors.
	# StandardMaterial3D is the main material type in Godot 4.
	# By enabling vertex_color_use_as_albedo, the mesh colors we set in
	# ChunkMeshBuilder will be used as the surface color.
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Slight roughness so blocks don't look plasticky
	material.roughness = 0.9
	_mesh_instance.material_override = material


## Initialize the block data array. All blocks start as AIR.
func initialize_blocks() -> void:
	blocks = []
	for x in CHUNK_SIZE:
		var plane := []
		for y in CHUNK_SIZE:
			var row := []
			for z in CHUNK_SIZE:
				row.append(BlockData.BlockType.AIR)
			plane.append(row)
		blocks.append(plane)


## Get the block type at a local chunk position.
func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return BlockData.BlockType.AIR
	return blocks[x][y][z]


## Set the block type at a local chunk position.
func set_block(x: int, y: int, z: int, block_type: int) -> void:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return
	blocks[x][y][z] = block_type


## Called by the world when a neighboring block might need to query into this chunk.
## local_x/y/z may be outside [0, CHUNK_SIZE) — that means we need to query
## the world for the right neighbor chunk.
func _get_neighbor_block(local_x: int, local_y: int, local_z: int) -> int:
	# Convert local chunk offset to world block position
	var world_x := chunk_position.x * CHUNK_SIZE + local_x
	var world_y := chunk_position.y * CHUNK_SIZE + local_y
	var world_z := chunk_position.z * CHUNK_SIZE + local_z

	if world:
		return world.get_block_at_world_pos(world_x, world_y, world_z)
	return BlockData.BlockType.AIR


## Rebuild this chunk's mesh and collision from the block data.
## Call this after changing any blocks in the chunk.
func rebuild_mesh() -> void:
	# Build the visual mesh
	var mesh := ChunkMeshBuilder.build_mesh(blocks, _get_neighbor_block)
	_mesh_instance.mesh = mesh

	# Build collision — ConcavePolygonShape3D from the same face data
	if mesh:
		var collision_data := ChunkMeshBuilder.build_collision(blocks, _get_neighbor_block)
		if collision_data.size() > 0:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(collision_data)
			_collision_shape.shape = shape
		else:
			_collision_shape.shape = null
	else:
		_collision_shape.shape = null
