extends Node
## Autoload singleton for save/load and global game state.
##
## Phase 1: Minimal stub. Phase 4 will add full save/load functionality.

const SAVE_PATH := "user://tiny_world_save.dat"

var world_seed := 42

signal game_state_loaded
signal game_state_saved


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
