extends Node
## Autoload singleton managing the player's block inventory and hotbar.

## inventory[block_type] = count
var inventory: Dictionary = {}

## Currently selected hotbar slot (0-4)
var selected_slot := 0

## What block type is in each hotbar slot
var hotbar_slots: Array[int] = [
	BlockData.BlockType.DIRT,
	BlockData.BlockType.GRASS,
	BlockData.BlockType.STONE,
	BlockData.BlockType.SAND,
	BlockData.BlockType.WOOD,
]

signal inventory_changed(block_type: int, new_count: int)
signal hotbar_selection_changed(slot_index: int)


func _ready() -> void:
	# Start with some blocks for each hotbar type
	for block_type in hotbar_slots:
		inventory[block_type] = 50


func _input(event: InputEvent) -> void:
	# Number keys 1-5 to select hotbar slot
	for i in 5:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			selected_slot = i
			hotbar_selection_changed.emit(selected_slot)
			return

	# Scroll wheel to cycle hotbar
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				selected_slot = (selected_slot - 1 + 5) % 5
				hotbar_selection_changed.emit(selected_slot)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				selected_slot = (selected_slot + 1) % 5
				hotbar_selection_changed.emit(selected_slot)


func get_selected_block_type() -> int:
	return hotbar_slots[selected_slot]


func get_block_count(block_type: int) -> int:
	return inventory.get(block_type, 0)


func has_block(block_type: int) -> bool:
	return get_block_count(block_type) > 0


func add_block(block_type: int, count: int = 1) -> void:
	inventory[block_type] = inventory.get(block_type, 0) + count
	inventory_changed.emit(block_type, inventory[block_type])


func remove_block(block_type: int, count: int = 1) -> bool:
	var current := get_block_count(block_type)
	if current < count:
		return false
	inventory[block_type] = current - count
	inventory_changed.emit(block_type, inventory[block_type])
	return true


## Get all block types the player has at least 1 of
func get_all_owned_types() -> Array[int]:
	var types: Array[int] = []
	for block_type in inventory:
		if inventory[block_type] > 0:
			types.append(block_type)
	return types


## Reset inventory to defaults
func reset() -> void:
	inventory.clear()
	selected_slot = 0
	for block_type in hotbar_slots:
		inventory[block_type] = 50
	inventory_changed.emit(0, 0)  # Generic refresh signal
	hotbar_selection_changed.emit(selected_slot)
