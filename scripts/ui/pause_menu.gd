extends Control
## Pause menu with new world confirmation dialog.
## Triggered by 'N' key for new world.

var _confirm_dialog: Panel = null
var _is_showing := false

signal new_world_confirmed


func _ready() -> void:
	visible = false
	_build_confirm_dialog()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("new_world") and not _is_showing:
		_show_confirm()
		get_viewport().set_input_as_handled()


func _build_confirm_dialog() -> void:
	_confirm_dialog = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.set_corner_radius_all(8)
	_confirm_dialog.add_theme_stylebox_override("panel", style)
	_confirm_dialog.size = Vector2(320, 160)
	_confirm_dialog.position = Vector2(-160, -80)
	_confirm_dialog.anchors_preset = Control.PRESET_CENTER
	add_child(_confirm_dialog)

	# Warning text
	var label := Label.new()
	label.text = "Create a new world?\nAll unsaved changes will be lost!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 20)
	label.size = Vector2(320, 60)
	label.add_theme_font_size_override("font_size", 16)
	_confirm_dialog.add_child(label)

	# Button container
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(60, 100)
	hbox.size = Vector2(200, 40)
	hbox.add_theme_constant_override("separation", 20)
	_confirm_dialog.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "New World"
	yes_btn.custom_minimum_size = Vector2(90, 36)
	yes_btn.pressed.connect(_on_confirm_yes)
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Cancel"
	no_btn.custom_minimum_size = Vector2(90, 36)
	no_btn.pressed.connect(_on_confirm_no)
	hbox.add_child(no_btn)


func _show_confirm() -> void:
	visible = true
	_is_showing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hide_confirm() -> void:
	visible = false
	_is_showing = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_confirm_yes() -> void:
	_hide_confirm()
	new_world_confirmed.emit()


func _on_confirm_no() -> void:
	_hide_confirm()
