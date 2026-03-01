class_name CraftingSystem
## Defines crafting recipes and handles crafting logic.

class Recipe:
	var ingredients: Dictionary = {}  # {BlockType: count}
	var result_type: int = 0
	var result_count: int = 1

	func _init(p_ingredients: Dictionary, p_result: int, p_count: int = 1) -> void:
		ingredients = p_ingredients
		result_type = p_result
		result_count = p_count


## Lazy-initialized recipe list. Static var initializers with inner class
## constructors can fail silently in GDScript, so we build on first access.
static var _recipes: Array = []
static var _initialized := false


static func get_recipes() -> Array:
	if not _initialized:
		_recipes = [
			Recipe.new(
				{BlockData.BlockType.STONE: 2, BlockData.BlockType.WOOD: 1},
				BlockData.BlockType.BRICK, 2
			),
			Recipe.new(
				{BlockData.BlockType.DIRT: 2, BlockData.BlockType.SAND: 1},
				BlockData.BlockType.CLAY, 2
			),
			Recipe.new(
				{BlockData.BlockType.SAND: 2, BlockData.BlockType.STONE: 2},
				BlockData.BlockType.DIRT, 3
			),
			Recipe.new(
				{BlockData.BlockType.WOOD: 1, BlockData.BlockType.DIRT: 1},
				BlockData.BlockType.TORCH, 2
			),
		]
		_initialized = true
	return _recipes


static func can_craft(recipe: Recipe) -> bool:
	for block_type in recipe.ingredients:
		var needed: int = recipe.ingredients[block_type]
		if InventoryManager.get_block_count(block_type) < needed:
			return false
	return true


static func craft(recipe: Recipe) -> bool:
	if not can_craft(recipe):
		return false

	for block_type in recipe.ingredients:
		var count: int = recipe.ingredients[block_type]
		InventoryManager.remove_block(block_type, count)

	InventoryManager.add_block(recipe.result_type, recipe.result_count)
	return true
