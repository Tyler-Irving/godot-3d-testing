extends Camera3D
## Player camera: handles the RayCast3D for block targeting.
##
## ===== 3D CONCEPT: Camera3D =====
## Camera3D is what the player sees through. Key properties:
##   - fov: Field of view angle (75° is standard FPS)
##   - near/far: Clipping planes — objects closer than `near` or farther
##     than `far` won't be rendered. Keep `near` small (0.05) for close
##     objects, `far` large enough to see the whole world.
##   - current: if true, this camera is the active one. Only one camera
##     can be active at a time per viewport.
##
## ===== 3D CONCEPT: RayCast3D =====
## A raycast shoots an invisible line from one point in a direction and
## reports what it hits. It's like asking "what 3D object is in front of me?"
##
## For block targeting, we cast a ray from the camera position forward.
## The ray returns:
##   - The collision point (where exactly the ray hit)
##   - The collision normal (which face of the block was hit)
##   - The collider (which chunk's StaticBody3D was hit)
##
## Using the collision point and normal, we can figure out which block
## was targeted and which adjacent position to place a new block.
## ========================================

## How far away blocks can be targeted (in world units = meters = blocks)
@export var interaction_range := 6.0

## Signals to tell other systems what we're looking at
signal block_targeted(block_pos: Vector3i, face_normal: Vector3i, hit_point: Vector3)
signal block_untargeted

var _ray_cast: RayCast3D

## Currently targeted block position (world coordinates), or null
var targeted_block: Variant = null
var targeted_face_normal := Vector3i.ZERO


func _ready() -> void:
	# Create the raycast as a child of the camera.
	# It points forward (-Z in local space) with length = interaction_range.
	_ray_cast = RayCast3D.new()
	_ray_cast.target_position = Vector3(0, 0, -interaction_range)
	_ray_cast.enabled = true
	add_child(_ray_cast)


func _physics_process(_delta: float) -> void:
	_update_block_target()


## Check what block the raycast is pointing at.
func _update_block_target() -> void:
	if _ray_cast.is_colliding():
		var hit_point: Vector3 = _ray_cast.get_collision_point()
		var hit_normal: Vector3 = _ray_cast.get_collision_normal()

		# Calculate which block was hit.
		# The hit point is on the surface of a block face. To find the block,
		# we step slightly INTO the block (opposite the normal) and floor
		# the coordinates to get integer block position.
		#
		# Why subtract normal * 0.01? Because the hit point is exactly on the
		# face boundary. Floating point imprecision means floor() might give
		# us the wrong block. Nudging inward guarantees we get the right one.
		var block_pos_float: Vector3 = hit_point - hit_normal * 0.01
		var block_pos := Vector3i(
			floori(block_pos_float.x),
			floori(block_pos_float.y),
			floori(block_pos_float.z)
		)

		var face := Vector3i(
			roundi(hit_normal.x),
			roundi(hit_normal.y),
			roundi(hit_normal.z)
		)

		if targeted_block == null or targeted_block != block_pos or targeted_face_normal != face:
			targeted_block = block_pos
			targeted_face_normal = face
			block_targeted.emit(block_pos, face, hit_point)
	else:
		if targeted_block != null:
			targeted_block = null
			targeted_face_normal = Vector3i.ZERO
			block_untargeted.emit()
