extends Node3D
## Main scene script: wires together world, player, environment, day/night,
## save/load, and all UI systems.

@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $Player
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var hud: CanvasLayer = $HUD

var day_night: Node = null


func _ready() -> void:
	# Wire up the player interaction system
	var interaction: Node3D = player.get_node("PlayerInteraction")
	var camera: Camera3D = player.get_node("CameraPivot/Camera3D")
	interaction.setup(world, camera)

	# Set up day/night cycle
	_setup_day_night()

	# Connect pause menu "new world" signal
	var pause_menu: Control = hud.get_node("PauseMenu")
	if pause_menu.has_signal("new_world_confirmed"):
		pause_menu.new_world_confirmed.connect(_on_new_world)

	# Load existing save or start fresh
	if GameState.has_save_file():
		var data := GameState.load_game()
		if not data.is_empty():
			GameState.apply_save_data(data, world, player)
			print("Loaded existing save.")
		else:
			_spawn_player_default()
	else:
		_spawn_player_default()

	print("Tiny World 3D")
	print("WASD=move, Space=jump, Mouse=look, Escape=release mouse")
	print("Left click (hold)=mine, Right click=place, 1-5/scroll=select block")
	print("C=crafting, N=new world")
	print("Game auto-saves on quit.")


func _spawn_player_default() -> void:
	player.position = Vector3(32, 30, 32)


func _setup_day_night() -> void:
	# Create the day/night cycle controller
	var dnc_script := preload("res://scripts/systems/day_night_cycle.gd")
	day_night = dnc_script.new()
	day_night.name = "DayNightCycle"
	day_night.sun_light = sun
	day_night.environment = world_env.environment

	# Get the sky material from the environment
	var sky: Sky = world_env.environment.sky
	if sky and sky.sky_material is ProceduralSkyMaterial:
		day_night.sky_material = sky.sky_material

	add_child(day_night)


func _on_new_world() -> void:
	# Delete save and regenerate
	GameState.delete_save()
	InventoryManager.reset()

	# Randomize world seed
	var new_seed := randi()
	world.world_seed = new_seed
	world.generator.set_seed(new_seed)
	GameState.world_seed = new_seed

	world.generate_world()
	_spawn_player_default()
	print("New world generated with seed: %d" % new_seed)


func _notification(what: int) -> void:
	# Auto-save when the game is about to close
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game(world, player)
		get_tree().quit()
