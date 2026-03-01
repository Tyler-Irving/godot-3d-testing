extends CanvasLayer
## Main HUD: crosshair + hotbar display.
##
## CanvasLayer renders UI on top of the 3D scene.
## All UI elements use Control nodes (2D) that overlay the 3D viewport.

@onready var crosshair: Control = $Crosshair
@onready var hotbar: Control = $Hotbar


func _ready() -> void:
	pass
