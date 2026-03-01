class_name BlockData
## Defines all block types in the game.
##
## CONCEPT: This is a pure data class — no nodes, no scenes. It maps integer
## block IDs to their properties (name, color, transparency, etc.).
## Using integers for block storage keeps chunk data compact.

# Block type IDs — 0 is always AIR (empty space)
enum BlockType {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3,
	SAND = 4,
	WOOD = 5,
	WATER = 6,
	BRICK = 7,
	CLAY = 8,
	TORCH = 9,
}

## Properties for each block type.
## Colors are chosen to be visually distinct without textures.
const BLOCK_PROPERTIES: Dictionary = {
	BlockType.AIR: {
		"name": "Air",
		"color": Color(0, 0, 0, 0),  # Transparent — never rendered
		"is_solid": false,
		"is_transparent": true,
	},
	BlockType.GRASS: {
		"name": "Grass",
		"color": Color(0.36, 0.68, 0.25),  # Fresh green
		"is_solid": true,
		"is_transparent": false,
	},
	BlockType.DIRT: {
		"name": "Dirt",
		"color": Color(0.55, 0.37, 0.24),  # Brown
		"is_solid": true,
		"is_transparent": false,
	},
	BlockType.STONE: {
		"name": "Stone",
		"color": Color(0.55, 0.55, 0.55),  # Gray
		"is_solid": true,
		"is_transparent": false,
	},
	BlockType.SAND: {
		"name": "Sand",
		"color": Color(0.87, 0.81, 0.58),  # Tan/sandy
		"is_solid": true,
		"is_transparent": false,
	},
	BlockType.WOOD: {
		"name": "Wood",
		"color": Color(0.65, 0.45, 0.22),  # Warm brown
		"is_solid": true,
		"is_transparent": false,
	},
	BlockType.WATER: {
		"name": "Water",
		"color": Color(0.2, 0.45, 0.85, 0.7),  # Semi-transparent blue
		"is_solid": false,
		"is_transparent": true,
	},
	BlockType.BRICK: {
		"name": "Brick",
		"color": Color(0.72, 0.3, 0.25),  # Reddish
		"is_solid": true,
		"is_transparent": false,
	},
	BlockType.CLAY: {
		"name": "Clay",
		"color": Color(0.75, 0.6, 0.45),  # Light brown/orange
		"is_solid": true,
		"is_transparent": false,
	},
	BlockType.TORCH: {
		"name": "Torch",
		"color": Color(0.95, 0.8, 0.3),  # Warm yellow
		"is_solid": false,
		"is_transparent": true,
	},
}


static func get_block_name(block_type: int) -> String:
	if BLOCK_PROPERTIES.has(block_type):
		return BLOCK_PROPERTIES[block_type]["name"]
	return "Unknown"


static func get_color(block_type: int) -> Color:
	if BLOCK_PROPERTIES.has(block_type):
		return BLOCK_PROPERTIES[block_type]["color"]
	return Color.MAGENTA  # Obvious error color


static func is_solid(block_type: int) -> bool:
	if BLOCK_PROPERTIES.has(block_type):
		return BLOCK_PROPERTIES[block_type]["is_solid"]
	return false


static func is_transparent(block_type: int) -> bool:
	if BLOCK_PROPERTIES.has(block_type):
		return BLOCK_PROPERTIES[block_type]["is_transparent"]
	return true
