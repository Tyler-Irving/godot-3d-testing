extends HBoxContainer
## Hotbar UI: shows 5 block type slots at the bottom of the screen.
## Phase 1 version: basic colored squares with selection highlight.

const SLOT_SIZE := 48
const SLOT_MARGIN := 4

var _slots: Array[Panel] = []
var _count_labels: Array[Label] = []
var _selected_index := 0


func _ready() -> void:
	# Build the hotbar slots
	for i in 5:
		var block_type: int = InventoryManager.hotbar_slots[i]
		var slot := _create_slot(block_type, i)
		add_child(slot)
		_slots.append(slot)

	# Listen for selection changes
	InventoryManager.hotbar_selection_changed.connect(_on_selection_changed)
	InventoryManager.inventory_changed.connect(_on_inventory_changed)

	# Initialize selection highlight
	_update_selection()
	_update_counts()


func _create_slot(block_type: int, index: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# Background style
	var style := StyleBoxFlat.new()
	style.bg_color = BlockData.get_color(block_type)
	style.border_color = Color(0.3, 0.3, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	# Count label
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.text = ""
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(label)
	_count_labels.append(label)

	# Name label (small, at top)
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.anchors_preset = Control.PRESET_FULL_RECT
	name_label.text = BlockData.get_block_name(block_type)
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(name_label)

	return panel


func _update_selection() -> void:
	for i in _slots.size():
		var style: StyleBoxFlat = _slots[i].get_theme_stylebox("panel")
		if i == _selected_index:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
		else:
			style.border_color = Color(0.3, 0.3, 0.3, 0.8)
			style.set_border_width_all(2)


func _update_counts() -> void:
	for i in 5:
		var block_type: int = InventoryManager.hotbar_slots[i]
		var count := InventoryManager.get_block_count(block_type)
		_count_labels[i].text = "x%d" % count


func _on_selection_changed(slot_index: int) -> void:
	_selected_index = slot_index
	_update_selection()


func _on_inventory_changed(_block_type: int, _new_count: int) -> void:
	_update_counts()
