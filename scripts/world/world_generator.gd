class_name WorldGenerator
## Generates procedural terrain using FastNoiseLite.
##
## ===== 3D CONCEPT: PROCEDURAL GENERATION WITH NOISE =====
## FastNoiseLite generates smooth random values for any 2D/3D coordinate.
## For terrain, we sample noise at each (x, z) position to get a height value.
## The noise is deterministic — same seed = same terrain every time.
##
## We use 2D noise (sampling x, z only) because our terrain is a heightmap:
## every column of blocks has a single surface height. This gives us rolling
## hills rather than floating islands or caves (which would need 3D noise).
## ========================================

const CHUNK_SIZE := 16

## Terrain parameters
const WATER_LEVEL := 18       # Blocks below this are filled with water
const BASE_HEIGHT := 20       # Average ground height (in blocks from y=0)
const HEIGHT_VARIATION := 5.0 # Max blocks above/below base height
const DIRT_DEPTH := 3         # Layers of dirt below the surface

var noise: FastNoiseLite


func _init() -> void:
	noise = FastNoiseLite.new()
	# OpenSimplex2 is great for terrain — smooth, organic-looking
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Frequency controls how "zoomed in" the noise is.
	# Lower = broader, gentler hills. Higher = more jagged.
	noise.frequency = 0.02
	# Fractal octaves add detail layers on top of the base noise.
	# More octaves = more detail (small bumps on top of large hills).
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5


func set_seed(new_seed: int) -> void:
	noise.seed = new_seed


## Generate terrain for a single chunk at the given chunk position.
## Fills the chunk's block array based on noise-generated height.
func generate_chunk(chunk: Chunk) -> void:
	var cx := chunk.chunk_position.x
	var cy := chunk.chunk_position.y
	var cz := chunk.chunk_position.z

	chunk.initialize_blocks()

	for x in CHUNK_SIZE:
		for z in CHUNK_SIZE:
			# Convert local chunk coords to world block coords
			var world_x := cx * CHUNK_SIZE + x
			var world_z := cz * CHUNK_SIZE + z

			# Sample noise at this (x, z) to get terrain height.
			# noise.get_noise_2d returns a value in [-1, 1].
			# We scale it to our desired height range.
			var noise_val := noise.get_noise_2d(float(world_x), float(world_z))
			var height := int(BASE_HEIGHT + noise_val * HEIGHT_VARIATION)

			# Fill blocks in this column
			for y in CHUNK_SIZE:
				var world_y := cy * CHUNK_SIZE + y
				var block_type := _get_block_for_height(world_y, height)
				chunk.set_block(x, y, z, block_type)


## Determine block type based on the block's Y position relative to terrain height.
func _get_block_for_height(world_y: int, surface_height: int) -> int:
	if world_y > surface_height:
		# Above surface: air or water
		if world_y <= WATER_LEVEL:
			return BlockData.BlockType.WATER
		return BlockData.BlockType.AIR

	if world_y == surface_height:
		# Surface layer: grass or sand depending on height
		if surface_height <= WATER_LEVEL:
			return BlockData.BlockType.SAND  # Beach/shoreline
		return BlockData.BlockType.GRASS

	if world_y > surface_height - DIRT_DEPTH:
		# Just below surface: dirt
		return BlockData.BlockType.DIRT

	# Deep underground: stone
	return BlockData.BlockType.STONE
