extends Node3D
## Handles block placement and destruction in response to player input.
##
## Phase 2: Mining requires holding left-click for a short duration.
## The targeted block visually shrinks as it's being mined, then pops.

@export var interaction_range := 6.0
@export var mine_time := 0.4  # Seconds to hold click to break a block

var _world: Node = null
var _camera: Camera3D = null

## The block we're currently looking at (from the camera raycast)
var _targeted_block: Variant = null
var _targeted_face: Vector3i = Vector3i.ZERO

## Visual highlight for the targeted block
var _highlight_mesh: MeshInstance3D = null

## Mining state
var _is_mining := false
var _mining_block: Variant = null  # Which block we started mining
var _mining_progress := 0.0       # 0.0 to 1.0

## Mining feedback — a shrinking cube shown over the block being mined
var _mining_visual: MeshInstance3D = null
var _mining_material: StandardMaterial3D = null


func _ready() -> void:
	_highlight_mesh = MeshInstance3D.new()
	_highlight_mesh.visible = false

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_highlight_mesh.material_override = mat

	# Mining visual — a colored cube that shrinks as you mine
	_mining_visual = MeshInstance3D.new()
	_mining_visual.visible = false
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE
	_mining_visual.mesh = box_mesh

	_mining_material = StandardMaterial3D.new()
	_mining_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mining_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mining_visual.material_override = _mining_material

	call_deferred("_setup_highlight")


func _setup_highlight() -> void:
	get_tree().current_scene.add_child(_highlight_mesh)
	get_tree().current_scene.add_child(_mining_visual)
	_build_highlight_cube()


func setup(world: Node, camera: Camera3D) -> void:
	_world = world
	_camera = camera

	if _camera:
		_camera.block_targeted.connect(_on_block_targeted)
		_camera.block_untargeted.connect(_on_block_untargeted)


func _input(event: InputEvent) -> void:
	# Right click — place block (instant)
	if event.is_action_pressed("place_block") and _targeted_block != null:
		_place_block()


func _process(delta: float) -> void:
	# Mining: hold left click to break blocks over time
	if Input.is_action_pressed("destroy_block") and _targeted_block != null:
		if not _is_mining or _mining_block != _targeted_block:
			# Start mining a new block
			_start_mining()
		else:
			# Continue mining
			_mining_progress += delta / mine_time
			_update_mining_visual()
			if _mining_progress >= 1.0:
				_finish_mining()
	else:
		if _is_mining:
			_cancel_mining()


func _start_mining() -> void:
	_is_mining = true
	_mining_block = _targeted_block
	_mining_progress = 0.0

	if _world and _mining_block != null:
		var pos: Vector3i = _mining_block
		var block_type: int = _world.get_block_at_world_pos(pos.x, pos.y, pos.z)
		_mining_material.albedo_color = BlockData.get_color(block_type)
		_mining_material.albedo_color.a = 0.6

	_update_mining_visual()


func _finish_mining() -> void:
	if _world == null or _mining_block == null:
		_cancel_mining()
		return

	var pos: Vector3i = _mining_block
	var block_type: int = _world.get_block_at_world_pos(pos.x, pos.y, pos.z)

	if block_type == BlockData.BlockType.AIR:
		_cancel_mining()
		return

	_world.set_block_at_world_pos(pos.x, pos.y, pos.z, BlockData.BlockType.AIR)
	if InventoryManager:
		InventoryManager.add_block(block_type, 1)

	_cancel_mining()


func _cancel_mining() -> void:
	_is_mining = false
	_mining_block = null
	_mining_progress = 0.0
	_mining_visual.visible = false


func _update_mining_visual() -> void:
	if _mining_block == null:
		_mining_visual.visible = false
		return

	_mining_visual.visible = true
	var pos := Vector3(_mining_block) + Vector3(0.5, 0.5, 0.5)
	# Shrink the block as mining progresses (1.0 → 0.2 scale)
	var scale_val := lerpf(1.02, 0.2, _mining_progress)
	_mining_visual.global_position = pos
	_mining_visual.scale = Vector3(scale_val, scale_val, scale_val)

	# Flash the alpha to give feedback
	_mining_material.albedo_color.a = 0.3 + 0.3 * sin(_mining_progress * TAU * 3.0)


func _on_block_targeted(block_pos: Vector3i, face_normal: Vector3i, _hit_point: Vector3) -> void:
	_targeted_block = block_pos
	_targeted_face = face_normal

	if _highlight_mesh:
		_highlight_mesh.global_position = Vector3(block_pos)
		_highlight_mesh.visible = true


func _on_block_untargeted() -> void:
	_targeted_block = null
	_targeted_face = Vector3i.ZERO
	if _highlight_mesh:
		_highlight_mesh.visible = false
	if _is_mining:
		_cancel_mining()


func _place_block() -> void:
	if _world == null or _targeted_block == null:
		return

	var place_pos: Vector3i = _targeted_block + _targeted_face

	var existing: int = _world.get_block_at_world_pos(place_pos.x, place_pos.y, place_pos.z)
	if existing != BlockData.BlockType.AIR:
		return

	# Don't place blocks inside the player
	var player := get_parent() as CharacterBody3D
	if player:
		var player_pos := player.global_position
		var player_min := Vector3i(floori(player_pos.x - 0.3), floori(player_pos.y - 0.1), floori(player_pos.z - 0.3))
		var player_max := Vector3i(floori(player_pos.x + 0.3), floori(player_pos.y + 1.7), floori(player_pos.z + 0.3))
		if (place_pos.x >= player_min.x and place_pos.x <= player_max.x and
			place_pos.y >= player_min.y and place_pos.y <= player_max.y and
			place_pos.z >= player_min.z and place_pos.z <= player_max.z):
			return

	var block_type: int = InventoryManager.get_selected_block_type()

	if not InventoryManager.has_block(block_type):
		return

	InventoryManager.remove_block(block_type, 1)
	_world.set_block_at_world_pos(place_pos.x, place_pos.y, place_pos.z, block_type)


## Build wireframe cube for block highlighting.
func _build_highlight_cube() -> void:
	var mesh := ImmediateMesh.new()
	var offset := -0.005
	var s := 1.01

	var corners := [
		Vector3(offset, offset, offset), Vector3(s, offset, offset),
		Vector3(s, s, offset), Vector3(offset, s, offset),
		Vector3(offset, offset, s), Vector3(s, offset, s),
		Vector3(s, s, s), Vector3(offset, s, s),
	]

	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge in edges:
		mesh.surface_add_vertex(corners[edge[0]])
		mesh.surface_add_vertex(corners[edge[1]])
	mesh.surface_end()

	_highlight_mesh.mesh = mesh
