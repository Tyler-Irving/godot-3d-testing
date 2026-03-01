extends Node3D
## Handles block placement and destruction in response to player input.
##
## This script lives on the player and connects to the camera's targeting
## signals. It talks to the world to place/destroy blocks and to the
## inventory manager to track block counts.
##
## For Phase 1, we have simplified interaction: instant place/destroy.
## Phase 2 will add the mining timer and visual feedback.

@export var interaction_range := 6.0

var _world: Node = null
var _camera: Camera3D = null

## The block we're currently looking at (from the camera raycast)
var _targeted_block: Variant = null
var _targeted_face: Vector3i = Vector3i.ZERO

## Visual highlight for the targeted block
var _highlight_mesh: MeshInstance3D = null


func _ready() -> void:
	# Create the wireframe highlight box shown on the targeted block.
	# We'll use an ImmediateMesh to draw wireframe lines around the block.
	_highlight_mesh = MeshInstance3D.new()
	_highlight_mesh.visible = false

	# Create a material for the highlight — bright white, unlit, on top of everything
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true  # Render on top of other geometry
	_highlight_mesh.material_override = mat

	# We'll add this to the scene tree at a higher level so it moves independently
	# from the player. Deferred because the tree might not be fully ready yet.
	call_deferred("_setup_highlight")


func _setup_highlight() -> void:
	# Add highlight to the world root so it stays at the block position
	get_tree().current_scene.add_child(_highlight_mesh)
	_build_highlight_cube()


func setup(world: Node, camera: Camera3D) -> void:
	_world = world
	_camera = camera

	# Connect to camera targeting signals
	if _camera:
		_camera.block_targeted.connect(_on_block_targeted)
		_camera.block_untargeted.connect(_on_block_untargeted)


func _unhandled_input(event: InputEvent) -> void:
	# Left click — destroy block
	if event.is_action_pressed("destroy_block") and _targeted_block != null:
		_destroy_block()

	# Right click — place block
	if event.is_action_pressed("place_block") and _targeted_block != null:
		_place_block()


func _on_block_targeted(block_pos: Vector3i, face_normal: Vector3i, _hit_point: Vector3) -> void:
	_targeted_block = block_pos
	_targeted_face = face_normal

	# Move and show the highlight
	if _highlight_mesh:
		# Position it at the block, slightly expanded to sit outside the block surface
		_highlight_mesh.global_position = Vector3(block_pos)
		_highlight_mesh.visible = true


func _on_block_untargeted() -> void:
	_targeted_block = null
	_targeted_face = Vector3i.ZERO
	if _highlight_mesh:
		_highlight_mesh.visible = false


func _destroy_block() -> void:
	if _world == null or _targeted_block == null:
		return

	var pos: Vector3i = _targeted_block
	var block_type: int = _world.get_block_at_world_pos(pos.x, pos.y, pos.z)

	if block_type == BlockData.BlockType.AIR:
		return

	# Remove the block (set to air)
	_world.set_block_at_world_pos(pos.x, pos.y, pos.z, BlockData.BlockType.AIR)

	# Add to inventory (Phase 3 will use InventoryManager, for now just print)
	if InventoryManager:
		InventoryManager.add_block(block_type, 1)


func _place_block() -> void:
	if _world == null or _targeted_block == null:
		return

	# Place position = targeted block + face normal
	# If you're looking at the top face of a block, the normal is (0,1,0),
	# so we place one block above the targeted block.
	var place_pos: Vector3i = _targeted_block + _targeted_face

	# Check that the place position is air (don't overwrite existing blocks)
	var existing: int = _world.get_block_at_world_pos(place_pos.x, place_pos.y, place_pos.z)
	if existing != BlockData.BlockType.AIR:
		return

	# Check that we're not placing inside the player
	var player := get_parent() as CharacterBody3D
	if player:
		var player_pos := player.global_position
		# Player occupies roughly a 1x2x1 column
		var player_min := Vector3i(floori(player_pos.x - 0.3), floori(player_pos.y - 0.1), floori(player_pos.z - 0.3))
		var player_max := Vector3i(floori(player_pos.x + 0.3), floori(player_pos.y + 1.7), floori(player_pos.z + 0.3))
		if (place_pos.x >= player_min.x and place_pos.x <= player_max.x and
			place_pos.y >= player_min.y and place_pos.y <= player_max.y and
			place_pos.z >= player_min.z and place_pos.z <= player_max.z):
			return  # Would clip into player

	# Get the selected block type from inventory
	var block_type: int = InventoryManager.get_selected_block_type()

	# Check if player has this block in inventory (Phase 1: unlimited blocks)
	if not InventoryManager.has_block(block_type):
		return

	InventoryManager.remove_block(block_type, 1)
	_world.set_block_at_world_pos(place_pos.x, place_pos.y, place_pos.z, block_type)


## Build a wireframe cube mesh for block highlighting.
## Uses an ImmediateMesh with LINE primitives to draw 12 edges of a cube.
func _build_highlight_cube() -> void:
	var mesh := ImmediateMesh.new()

	# Slightly larger than 1x1x1 so it wraps around the block
	var offset := -0.005
	var size := 1.01

	# The 8 corners of the highlight cube
	var corners := [
		Vector3(offset, offset, offset),
		Vector3(size, offset, offset),
		Vector3(size, size, offset),
		Vector3(offset, size, offset),
		Vector3(offset, offset, size),
		Vector3(size, offset, size),
		Vector3(size, size, size),
		Vector3(offset, size, size),
	]

	# 12 edges of a cube (pairs of corner indices)
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],  # Front face
		[4, 5], [5, 6], [6, 7], [7, 4],  # Back face
		[0, 4], [1, 5], [2, 6], [3, 7],  # Connecting edges
	]

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge in edges:
		mesh.surface_add_vertex(corners[edge[0]])
		mesh.surface_add_vertex(corners[edge[1]])
	mesh.surface_end()

	_highlight_mesh.mesh = mesh
