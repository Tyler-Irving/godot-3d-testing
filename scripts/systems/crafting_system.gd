class_name CraftingSystem
## Defines crafting recipes and handles crafting logic.
##
## Each recipe takes ingredient block types + counts and produces a result.

class Recipe:
	var ingredients: Dictionary = {}  # {BlockType: count}
	var result_type: int = 0
	var result_count: int = 1

	func _init(p_ingredients: Dictionary, p_result: int, p_count: int = 1) -> void:
		ingredients = p_ingredients
		result_type = p_result
		result_count = p_count


## All available recipes
static var recipes: Array = [
	# Stone + Wood = 2 Brick
	Recipe.new(
		{BlockData.BlockType.STONE: 2, BlockData.BlockType.WOOD: 1},
		BlockData.BlockType.BRICK, 2
	),
	# Dirt + Sand = 2 Clay
	Recipe.new(
		{BlockData.BlockType.DIRT: 2, BlockData.BlockType.SAND: 1},
		BlockData.BlockType.CLAY, 2
	),
	# Sand + Stone = 3 Dirt (recycle)
	Recipe.new(
		{BlockData.BlockType.SAND: 2, BlockData.BlockType.STONE: 2},
		BlockData.BlockType.DIRT, 3
	),
	# Wood + Dirt = Torch (for Phase 4 lighting)
	Recipe.new(
		{BlockData.BlockType.WOOD: 1, BlockData.BlockType.DIRT: 1},
		BlockData.BlockType.TORCH, 2
	),
]


## Check if a recipe can be crafted with current inventory
static func can_craft(recipe: Recipe) -> bool:
	for block_type in recipe.ingredients:
		var needed: int = recipe.ingredients[block_type]
		if InventoryManager.get_block_count(block_type) < needed:
			return false
	return true


## Execute a craft: remove ingredients, add results
static func craft(recipe: Recipe) -> bool:
	if not can_craft(recipe):
		return false

	# Remove ingredients
	for block_type in recipe.ingredients:
		var count: int = recipe.ingredients[block_type]
		InventoryManager.remove_block(block_type, count)

	# Add result
	InventoryManager.add_block(recipe.result_type, recipe.result_count)
	return true
