class_name ChunkMeshBuilder
## Builds a combined mesh from a chunk's block data using SurfaceTool.
##
## ===== 3D CONCEPT: MESH GENERATION =====
## A mesh is a collection of triangles (faces) that define a 3D shape.
## Each triangle has 3 vertices, and each vertex has:
##   - Position (where it is in 3D space)
##   - Normal (which direction the surface faces — used for lighting)
##   - UV (texture coordinates — we skip these since we use vertex colors)
##   - Color (the vertex color — we use this for block coloring)
##
## SurfaceTool is Godot's helper for building meshes vertex-by-vertex.
## You add vertices one at a time, then call commit() to get an ArrayMesh.
##
## KEY OPTIMIZATION: We only generate faces between solid blocks and air/transparent
## blocks. A block buried underground with solid neighbors on all 6 sides
## generates zero faces. This is what makes the chunk system performant.
## ========================================

const CHUNK_SIZE := 16

## The 6 directions a block face can point (and the neighbor offset to check).
## In Godot's coordinate system:
##   +X = right, -X = left
##   +Y = up,    -Y = down
##   +Z = back,  -Z = forward (toward camera in default view)
enum Face { TOP, BOTTOM, NORTH, SOUTH, EAST, WEST }

## For each face direction: the offset to the neighboring block.
const FACE_NORMALS: Array[Vector3i] = [
	Vector3i(0, 1, 0),   # TOP    — check block above
	Vector3i(0, -1, 0),  # BOTTOM — check block below
	Vector3i(0, 0, -1),  # NORTH  — check block in front (-Z is forward)
	Vector3i(0, 0, 1),   # SOUTH  — check block behind
	Vector3i(1, 0, 0),   # EAST   — check block to the right
	Vector3i(-1, 0, 0),  # WEST   — check block to the left
]

## For each face: the 4 vertices that make up that face of a unit cube.
## Vertices are in counter-clockwise winding order when viewed from outside
## the cube — this is how Godot knows which side is the "front" of the face.
## Each face is made of 2 triangles (a quad), so we need 4 vertices.
const FACE_VERTICES: Dictionary = {
	Face.TOP: [
		Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)
	],
	Face.BOTTOM: [
		Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)
	],
	Face.NORTH: [
		Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0)
	],
	Face.SOUTH: [
		Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(0, 0, 1)
	],
	Face.EAST: [
		Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)
	],
	Face.WEST: [
		Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1), Vector3(0, 0, 0)
	],
}

## Triangle indices for a quad (2 triangles from 4 vertices).
## [0,1,2] is the first triangle, [0,2,3] is the second.
const QUAD_INDICES: Array[int] = [0, 1, 2, 0, 2, 3]


## Build a mesh from chunk block data.
## block_data: 3D array [x][y][z] of BlockType integers
## neighbor_data: function to query blocks in neighboring chunks
## Returns: ArrayMesh (or null if chunk is entirely empty/hidden)
static func build_mesh(
	block_data: Array,
	get_neighbor_block: Callable
) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()

	# Begin building with TRIANGLES primitive type.
	# Every 3 vertices form one triangle.
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var has_any_face := false

	# Iterate every block position in the chunk
	for x in CHUNK_SIZE:
		for y in CHUNK_SIZE:
			for z in CHUNK_SIZE:
				var block_type: int = block_data[x][y][z]

				# Skip air — nothing to render
				if block_type == BlockData.BlockType.AIR:
					continue

				# Skip transparent non-solid blocks (like water) for now
				# We'll handle water rendering in a later phase
				if not BlockData.is_solid(block_type):
					continue

				var block_color := BlockData.get_color(block_type)
				var block_pos := Vector3(x, y, z)

				# Check each of the 6 faces
				for face_idx in 6:
					var normal_offset: Vector3i = FACE_NORMALS[face_idx]
					var nx := x + normal_offset.x
					var ny := y + normal_offset.y
					var nz := z + normal_offset.z

					# Get the neighboring block type.
					# If it's inside this chunk, look it up directly.
					# If it's outside, ask the world via the callable.
					var neighbor_type: int
					if (nx >= 0 and nx < CHUNK_SIZE and
						ny >= 0 and ny < CHUNK_SIZE and
						nz >= 0 and nz < CHUNK_SIZE):
						neighbor_type = block_data[nx][ny][nz]
					else:
						neighbor_type = get_neighbor_block.call(nx, ny, nz)

					# Only generate this face if the neighbor is transparent.
					# If the neighbor is solid, this face is hidden — skip it.
					if not BlockData.is_transparent(neighbor_type):
						continue

					# Apply slight shading per face direction for visual depth.
					# Top faces are brightest, bottom darkest. This fakes
					# ambient occlusion and makes block shapes readable.
					var shaded_color := _shade_face(block_color, face_idx)

					_add_face(surface_tool, block_pos, face_idx, shaded_color)
					has_any_face = true

	if not has_any_face:
		return null

	# Generate normals automatically from the triangle winding order.
	# This is simpler than manually specifying normals for each vertex.
	surface_tool.generate_normals()

	return surface_tool.commit()


## Build collision data from the same block data.
## Returns a PackedVector3Array of triangle vertices for ConcavePolygonShape3D.
static func build_collision(
	block_data: Array,
	get_neighbor_block: Callable
) -> PackedVector3Array:
	var collision_faces := PackedVector3Array()

	for x in CHUNK_SIZE:
		for y in CHUNK_SIZE:
			for z in CHUNK_SIZE:
				var block_type: int = block_data[x][y][z]
				if not BlockData.is_solid(block_type):
					continue

				var block_pos := Vector3(x, y, z)

				for face_idx in 6:
					var normal_offset: Vector3i = FACE_NORMALS[face_idx]
					var nx := x + normal_offset.x
					var ny := y + normal_offset.y
					var nz := z + normal_offset.z

					var neighbor_type: int
					if (nx >= 0 and nx < CHUNK_SIZE and
						ny >= 0 and ny < CHUNK_SIZE and
						nz >= 0 and nz < CHUNK_SIZE):
						neighbor_type = block_data[nx][ny][nz]
					else:
						neighbor_type = get_neighbor_block.call(nx, ny, nz)

					if not BlockData.is_transparent(neighbor_type):
						continue

					# Get the 4 vertices for this face, offset to block position
					var verts: Array = FACE_VERTICES[face_idx]
					var v0: Vector3 = verts[0] + block_pos
					var v1: Vector3 = verts[1] + block_pos
					var v2: Vector3 = verts[2] + block_pos
					var v3: Vector3 = verts[3] + block_pos

					# Two triangles per face (matching QUAD_INDICES order)
					collision_faces.append(v0)
					collision_faces.append(v1)
					collision_faces.append(v2)
					collision_faces.append(v0)
					collision_faces.append(v2)
					collision_faces.append(v3)

	return collision_faces


## Add a single quad (2 triangles) to the SurfaceTool for one block face.
static func _add_face(
	st: SurfaceTool,
	block_pos: Vector3,
	face_idx: int,
	color: Color
) -> void:
	var verts: Array = FACE_VERTICES[face_idx]

	# Add vertices in index order to form 2 triangles.
	# SurfaceTool in PRIMITIVE_TRIANGLES mode takes every 3 vertices as a triangle.
	for idx in QUAD_INDICES:
		st.set_color(color)
		st.add_vertex(verts[idx] + block_pos)


## Apply simple directional shading to fake ambient occlusion.
## Makes blocks look 3D even without complex lighting.
static func _shade_face(color: Color, face_idx: int) -> Color:
	var brightness: float
	match face_idx:
		Face.TOP:    brightness = 1.0     # Full brightness
		Face.BOTTOM: brightness = 0.5     # Darkest
		Face.NORTH:  brightness = 0.8     # Medium-light
		Face.SOUTH:  brightness = 0.8
		Face.EAST:   brightness = 0.7     # Medium-dark
		Face.WEST:   brightness = 0.7
		_:           brightness = 1.0
	return Color(
		color.r * brightness,
		color.g * brightness,
		color.b * brightness,
		color.a
	)
