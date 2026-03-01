class_name TorchManager
extends Node3D
## Manages torch block light sources.
##
## ===== 3D CONCEPT: OmniLight3D =====
## OmniLight3D emits light in all directions from a point, like a light bulb
## or torch. Key properties:
##   - omni_range: how far the light reaches
##   - light_energy: brightness
##   - light_color: tint color
##   - shadow_enabled: whether it casts shadows (expensive!)
##
## We disable shadows on torches for performance — many small shadow-casting
## lights is very GPU-heavy. The visual effect is still great without shadows.
## ========================================

## Dictionary mapping Vector3i world position to OmniLight3D node
var _torch_lights: Dictionary = {}

## Flicker state per torch
var _flicker_time: Dictionary = {}


func add_torch(world_pos: Vector3i) -> void:
	if _torch_lights.has(world_pos):
		return

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)  # Warm orange
	light.light_energy = 1.5
	light.omni_range = 8.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false  # Too expensive for many torches
	light.position = Vector3(world_pos) + Vector3(0.5, 0.5, 0.5)

	add_child(light)
	_torch_lights[world_pos] = light
	_flicker_time[world_pos] = randf() * TAU  # Random phase offset


func remove_torch(world_pos: Vector3i) -> void:
	if not _torch_lights.has(world_pos):
		return

	_torch_lights[world_pos].queue_free()
	_torch_lights.erase(world_pos)
	_flicker_time.erase(world_pos)


func has_torch(world_pos: Vector3i) -> bool:
	return _torch_lights.has(world_pos)


func clear_all() -> void:
	for pos in _torch_lights:
		_torch_lights[pos].queue_free()
	_torch_lights.clear()
	_flicker_time.clear()


func _process(delta: float) -> void:
	# Animate all torch flickers
	for pos in _torch_lights:
		_flicker_time[pos] += delta * 8.0  # Flicker speed
		var t: float = _flicker_time[pos]
		# Combine multiple sine waves for organic flicker
		var flicker := 1.0 + 0.1 * sin(t * 3.7) + 0.05 * sin(t * 7.3) + 0.08 * sin(t * 11.1)
		_torch_lights[pos].light_energy = 1.5 * flicker
