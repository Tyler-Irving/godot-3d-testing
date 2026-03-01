extends Node3D
## Main scene script: sets up the world, player, environment, and lighting.
##
## ===== 3D CONCEPT: WorldEnvironment =====
## WorldEnvironment controls global rendering settings:
##   - Sky: what's above the world (procedural sky, HDR skybox, etc.)
##   - Ambient light: fills shadows so they're not pitch black
##   - Fog: fades distant objects (hides world edges)
##   - Tonemap: how HDR colors map to the screen
##
## ===== 3D CONCEPT: DirectionalLight3D =====
## Simulates sunlight — infinitely far away, rays are parallel.
## All objects in the scene receive light from the same direction.
## The `rotation` of the light determines the sun angle.
## Shadow mapping creates shadows from this light.
## ========================================

@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	# Wire up the player interaction system to the world and camera
	var interaction: Node3D = player.get_node("PlayerInteraction")
	var camera: Camera3D = player.get_node("CameraPivot/Camera3D")
	interaction.setup(world, camera)

	# Position the player above the terrain so they don't spawn inside blocks.
	# The terrain base height is ~20 blocks, so spawn at Y=25 to be safe.
	# Center of the world: 2 chunks * 16 blocks = 32, so center at x=32, z=32.
	player.position = Vector3(32, 30, 32)

	print("Tiny World 3D — Phase 1")
	print("WASD to move, Space to jump, Mouse to look around")
	print("Left click to destroy blocks, Right click to place blocks")
	print("1-5 or scroll wheel to change block type")
	print("Escape to release/capture mouse")
