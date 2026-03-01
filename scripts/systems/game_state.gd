extends Node
## Autoload singleton for save/load and global game state.
##
## Saves the entire world (all chunk block data), player position/inventory,
## and world seed to a JSON file. JSON is human-readable and easy to debug.

const SAVE_PATH := "user://tiny_world_save.json"

var world_seed := 42

signal game_state_loaded
signal game_state_saved


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Save the full game state to disk.
func save_game(world_node: Node, player_node: Node) -> void:
	var save_data := {}

	# World seed
	save_data["world_seed"] = world_seed

	# Player data
	if player_node:
		save_data["player"] = {
			"position": _vec3_to_array(player_node.global_position),
			"rotation_y": player_node.rotation.y,
		}

	# Inventory data
	save_data["inventory"] = {}
	for block_type in InventoryManager.inventory:
		save_data["inventory"][str(block_type)] = InventoryManager.inventory[block_type]
	save_data["selected_slot"] = InventoryManager.selected_slot

	# World block data — save all modified chunk data
	var chunks_data := {}
	if world_node.has_method("get_save_data"):
		chunks_data = world_node.get_save_data()
	save_data["chunks"] = chunks_data

	# Torch positions
	if world_node.has_method("get_torch_positions"):
		var torch_positions: Array = world_node.get_torch_positions()
		save_data["torches"] = []
		for pos in torch_positions:
			save_data["torches"].append(_vec3i_to_array(pos))

	# Write to file
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		game_state_saved.emit()
		print("Game saved.")
	else:
		push_error("Failed to save game: could not open file")


## Load game state from disk. Returns the save data dictionary.
func load_game() -> Dictionary:
	if not has_save_file():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_error("Failed to parse save file: %s" % json.get_error_message())
		return {}

	var data: Dictionary = json.data
	game_state_loaded.emit()
	print("Game loaded.")
	return data


## Apply loaded data to the game systems.
func apply_save_data(data: Dictionary, world_node: Node, player_node: Node) -> void:
	if data.is_empty():
		return

	# Restore world seed
	if data.has("world_seed"):
		world_seed = int(data["world_seed"])

	# Restore inventory
	if data.has("inventory"):
		InventoryManager.inventory.clear()
		for key in data["inventory"]:
			InventoryManager.inventory[int(key)] = int(data["inventory"][key])
		InventoryManager.inventory_changed.emit(0, 0)

	if data.has("selected_slot"):
		InventoryManager.selected_slot = int(data["selected_slot"])
		InventoryManager.hotbar_selection_changed.emit(InventoryManager.selected_slot)

	# Restore world block data
	if data.has("chunks") and world_node.has_method("apply_save_data"):
		world_node.apply_save_data(data["chunks"])

	# Restore torches
	if data.has("torches") and world_node.has_method("restore_torches"):
		var torch_positions: Array[Vector3i] = []
		for arr in data["torches"]:
			torch_positions.append(Vector3i(int(arr[0]), int(arr[1]), int(arr[2])))
		world_node.restore_torches(torch_positions)

	# Restore player position
	if data.has("player") and player_node:
		var pdata: Dictionary = data["player"]
		if pdata.has("position"):
			var pos: Array = pdata["position"]
			player_node.global_position = Vector3(pos[0], pos[1], pos[2])
		if pdata.has("rotation_y"):
			player_node.rotation.y = pdata["rotation_y"]


func delete_save() -> void:
	if has_save_file():
		DirAccess.remove_absolute(SAVE_PATH)
		print("Save file deleted.")


static func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _vec3i_to_array(v: Vector3i) -> Array:
	return [v.x, v.y, v.z]
