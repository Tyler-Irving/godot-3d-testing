extends Node
## Day/night cycle system.
##
## Rotates the DirectionalLight3D around the X axis to simulate the sun
## moving across the sky. Adjusts sky colors and light properties to
## create sunrise, midday, sunset, and nighttime atmospheres.
##
## ===== 3D CONCEPT: LIGHT COLOR & ENERGY =====
## DirectionalLight3D simulates the sun. Its rotation determines shadow
## direction, light_energy controls brightness, and light_color sets the tint.
## During sunset we shift to warm orange; at night, dim blue moonlight.
##
## The ProceduralSkyMaterial has separate top/horizon colors that we lerp
## between presets to match the time of day.
## ========================================

@export var day_length := 180.0  # Seconds for a full day cycle
@export var start_time := 0.25   # Start at morning (0=midnight, 0.25=sunrise, 0.5=noon)

## References set by main.gd
var sun_light: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var environment: Environment

## Current time of day: 0.0 = midnight, 0.5 = noon, 1.0 = next midnight
var time_of_day := 0.25

## Color presets for different times of day
const SKY_TOP_DAY := Color(0.35, 0.55, 0.85)
const SKY_TOP_SUNSET := Color(0.4, 0.3, 0.55)
const SKY_TOP_NIGHT := Color(0.05, 0.05, 0.15)

const SKY_HORIZON_DAY := Color(0.65, 0.78, 0.9)
const SKY_HORIZON_SUNSET := Color(0.9, 0.5, 0.3)
const SKY_HORIZON_NIGHT := Color(0.08, 0.08, 0.18)

const SUN_COLOR_DAY := Color(1.0, 0.95, 0.85)
const SUN_COLOR_SUNSET := Color(1.0, 0.6, 0.3)
const SUN_COLOR_NIGHT := Color(0.3, 0.35, 0.5)

const SUN_ENERGY_DAY := 1.2
const SUN_ENERGY_NIGHT := 0.15

const AMBIENT_DAY := Color(0.6, 0.65, 0.75)
const AMBIENT_NIGHT := Color(0.1, 0.1, 0.2)


func _ready() -> void:
	time_of_day = start_time


func _process(delta: float) -> void:
	if not sun_light or not sky_material:
		return

	# Advance time
	time_of_day += delta / day_length
	if time_of_day >= 1.0:
		time_of_day -= 1.0

	_update_sun()
	_update_sky()
	_update_ambient()


func _update_sun() -> void:
	# Rotate the sun around the X axis. Full rotation = full day.
	# At time 0.25 (sunrise), sun is at the horizon (0°).
	# At time 0.5 (noon), sun is overhead (90°).
	# At time 0.75 (sunset), sun is at the other horizon (180°).
	var sun_angle := (time_of_day - 0.25) * TAU  # Full 360° rotation
	sun_light.rotation.x = sun_angle

	# Sun intensity and color based on time of day
	var day_factor := _get_day_factor()

	sun_light.light_energy = lerpf(SUN_ENERGY_NIGHT, SUN_ENERGY_DAY, day_factor)

	# Blend color: night → sunset → day → sunset → night
	var sunset_factor := _get_sunset_factor()
	var base_color := SUN_COLOR_NIGHT.lerp(SUN_COLOR_DAY, day_factor)
	sun_light.light_color = base_color.lerp(SUN_COLOR_SUNSET, sunset_factor)

	# Disable shadows at night (performance + looks better)
	sun_light.shadow_enabled = day_factor > 0.1


func _update_sky() -> void:
	var day_factor := _get_day_factor()
	var sunset_factor := _get_sunset_factor()

	# Sky top color
	var top_base := SKY_TOP_NIGHT.lerp(SKY_TOP_DAY, day_factor)
	sky_material.sky_top_color = top_base.lerp(SKY_TOP_SUNSET, sunset_factor)

	# Sky horizon color
	var horizon_base := SKY_HORIZON_NIGHT.lerp(SKY_HORIZON_DAY, day_factor)
	sky_material.sky_horizon_color = horizon_base.lerp(SKY_HORIZON_SUNSET, sunset_factor)

	# Ground colors follow horizon
	sky_material.ground_horizon_color = sky_material.sky_horizon_color


func _update_ambient() -> void:
	if not environment:
		return

	var day_factor := _get_day_factor()
	environment.ambient_light_color = AMBIENT_NIGHT.lerp(AMBIENT_DAY, day_factor)
	environment.ambient_light_energy = lerpf(0.15, 0.3, day_factor)


## How "daytime" it is: 0.0 at night, 1.0 at noon.
## Uses a smooth curve so transitions are gradual.
func _get_day_factor() -> float:
	# Sun is above horizon roughly from time 0.2 to 0.8
	# Peak daylight at 0.5
	var noon_distance := absf(time_of_day - 0.5)
	if time_of_day < 0.2 or time_of_day > 0.8:
		return 0.0
	return smoothstep(0.3, 0.0, noon_distance)


## How "sunset/sunrise" it is: peaks at dawn and dusk.
func _get_sunset_factor() -> float:
	# Sunrise around 0.2-0.3, sunset around 0.7-0.8
	var sunrise := 1.0 - clampf(absf(time_of_day - 0.25) / 0.08, 0.0, 1.0)
	var sunset := 1.0 - clampf(absf(time_of_day - 0.75) / 0.08, 0.0, 1.0)
	return maxf(sunrise, sunset)
