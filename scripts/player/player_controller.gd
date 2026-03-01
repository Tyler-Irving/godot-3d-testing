extends CharacterBody3D
## First-person player controller: movement, jumping, gravity.
##
## ===== 3D CONCEPT: CharacterBody3D =====
## CharacterBody3D is for player-controlled characters. Unlike RigidBody3D
## (physics-simulated), YOU control the movement directly — it won't bounce
## or slide on its own.
##
## The key method is move_and_slide(): you set the `velocity` property,
## call move_and_slide(), and Godot handles collision response (sliding along
## walls, stopping at floors, etc.). It's very similar to 2D's CharacterBody2D.
##
## is_on_floor() returns true if the last move_and_slide() detected ground below.
## This is how we know when the player can jump.
##
## ===== 3D CONCEPT: TRANSFORM3D & BASIS =====
## Every Node3D has a `transform` (Transform3D) containing:
##   - origin: the position (Vector3)
##   - basis: a 3x3 matrix encoding rotation and scale
##
## The basis has 3 column vectors:
##   - basis.x → the node's local right direction
##   - basis.y → the node's local up direction
##   - basis.z → the node's local forward direction (actually backward: +Z)
##
## In Godot, -Z is "forward" for a camera/character.
## So `transform.basis.z` points backward, and `-transform.basis.z` points forward.
## ========================================

@export var move_speed := 5.0        # Units per second
@export var jump_velocity := 6.0     # Initial upward velocity when jumping
@export var gravity := 20.0          # Downward acceleration (units/sec²)
@export var mouse_sensitivity := 0.002  # Radians per pixel of mouse movement

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var _mouse_captured := true


func _ready() -> void:
	# Capture the mouse cursor so it doesn't leave the game window.
	# CAPTURED = invisible and locked to center of window.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# Use _input instead of _unhandled_input for mouse look.
	# _unhandled_input won't receive MouseMotion events if any Control node
	# (like the HUD) exists in the scene — UI nodes consume input first.
	if event is InputEventMouseMotion and _mouse_captured:
		_handle_mouse_look(event)

	# Escape to toggle mouse capture
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_mouse_capture()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement()
	move_and_slide()


## Apply gravity every frame. Accumulates downward velocity.
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


## Jump when on the ground and spacebar is pressed.
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


## WASD movement relative to where the player is facing.
func _handle_movement() -> void:
	# Get the input direction as a 2D vector (WASD → x/y values of -1, 0, or 1)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Convert 2D input to 3D movement direction relative to the player's facing.
	# We use the player node's basis (not the camera's) so looking up/down
	# doesn't affect movement speed — you always walk parallel to the ground.
	#
	# transform.basis.z is the player's backward direction (+Z)
	# transform.basis.x is the player's right direction (+X)
	# input_dir.y is forward/back, input_dir.x is left/right
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		# Instant stop when no input (no momentum/inertia)
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)


## Rotate the player and camera based on mouse movement.
func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	# Horizontal mouse movement → rotate the whole player body around Y axis.
	# This is yaw (looking left/right).
	rotate_y(-event.relative.x * mouse_sensitivity)

	# Vertical mouse movement → rotate just the camera pivot around X axis.
	# This is pitch (looking up/down). We rotate the pivot, not the body,
	# so the body stays upright and movement stays horizontal.
	camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)

	# Clamp the pitch to prevent flipping upside down.
	# ±89 degrees — looking straight up/down without going past vertical.
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x,
		deg_to_rad(-89),
		deg_to_rad(89)
	)


func _toggle_mouse_capture() -> void:
	if _mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_mouse_captured = false
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = true
