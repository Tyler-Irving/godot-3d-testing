extends Control
## Crafting menu UI — toggled with 'C' key.
## Shows all recipes with ingredient costs and a Craft button.

var _recipe_rows: Array[HBoxContainer] = []
var _craft_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	_build_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_crafting"):
		visible = not visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_refresh_craftable()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Semi-transparent background panel
	var bg := Panel.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	bg_style.set_corner_radius_all(8)
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.anchors_preset = Control.PRESET_CENTER
	bg.size = Vector2(400, 300)
	bg.position = Vector2(-200, -150)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "Crafting"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 30)
	bg.add_child(title)

	# Recipe list
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(15, 50)
	vbox.size = Vector2(370, 240)
	vbox.add_theme_constant_override("separation", 8)
	bg.add_child(vbox)

	for i in CraftingSystem.recipes.size():
		var recipe: CraftingSystem.Recipe = CraftingSystem.recipes[i]
		var row := _create_recipe_row(recipe, i)
		vbox.add_child(row)
		_recipe_rows.append(row)


func _create_recipe_row(recipe: CraftingSystem.Recipe, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Ingredient list
	var ingredients_text := ""
	var first := true
	for block_type in recipe.ingredients:
		if not first:
			ingredients_text += " + "
		var count: int = recipe.ingredients[block_type]
		ingredients_text += "%s x%d" % [BlockData.get_block_name(block_type), count]
		first = false

	var ingredients_label := Label.new()
	ingredients_label.text = ingredients_text
	ingredients_label.add_theme_font_size_override("font_size", 13)
	ingredients_label.custom_minimum_size.x = 180
	row.add_child(ingredients_label)

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", 16)
	row.add_child(arrow)

	# Result with color swatch
	var result_color := ColorRect.new()
	result_color.color = BlockData.get_color(recipe.result_type)
	result_color.custom_minimum_size = Vector2(16, 16)
	row.add_child(result_color)

	var result_label := Label.new()
	result_label.text = "%s x%d" % [BlockData.get_block_name(recipe.result_type), recipe.result_count]
	result_label.add_theme_font_size_override("font_size", 13)
	row.add_child(result_label)

	# Craft button
	var btn := Button.new()
	btn.text = "Craft"
	btn.custom_minimum_size = Vector2(60, 28)
	btn.pressed.connect(_on_craft_pressed.bind(index))
	row.add_child(btn)
	_craft_buttons.append(btn)

	return row


func _on_craft_pressed(recipe_index: int) -> void:
	var recipe: CraftingSystem.Recipe = CraftingSystem.recipes[recipe_index]
	CraftingSystem.craft(recipe)
	_refresh_craftable()


func _refresh_craftable() -> void:
	for i in _craft_buttons.size():
		var recipe: CraftingSystem.Recipe = CraftingSystem.recipes[i]
		_craft_buttons[i].disabled = not CraftingSystem.can_craft(recipe)
