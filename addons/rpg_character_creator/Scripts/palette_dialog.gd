@tool
class_name LPCPaletteDialog
extends Window


var colors_data: Dictionary
var current_data: Dictionary

var using_custom_primary_colors: bool = false
var using_custom_secondary_colors: bool = false
var using_custom_fixed_colors: bool = false

var refresh_timer: float = 0.0

var mouse_is_over_me: bool = false


const PALETTE_BUTTON = preload("res://addons/rpg_character_creator/Scenes/palette_button.tscn")


signal refresh_item(colors_data: Dictionary)
signal hightlight_color(part_id: String, palette_id: int, color_id: int)
signal input_action_requested(event: InputEvent)
signal palette_changed(part_id: String, palettes: Dictionary)
signal part_changed(part_id: String)


func refresh_copy_paste_buttons() -> void:
	var paste_button_disabled = not "character_palette_color" in StaticEditorVars.CLIPBOARD
	%PastePrimaryColors.set_disabled(%PresetButton1.is_disabled() or paste_button_disabled)
	%PasteSecondaryColors.set_disabled(%PresetButton2.is_disabled() or paste_button_disabled)
	%PasteFixedColors.set_disabled(%PresetButton3.is_disabled() or paste_button_disabled)
	%CopyPrimaryColors.set_disabled(%PresetButton1.is_disabled())
	%CopySecondaryColors.set_disabled(%PresetButton2.is_disabled())
	%CopyFixedColors.set_disabled(%PresetButton3.is_disabled())


func _ready() -> void:
	fill_part_list()
	set_connections()
	hide()
	
	mouse_entered.connect(RPGDialogFunctions._on_dialog_mouse_entered.bind(self, true))
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		var buttons = [%PresetButton1, %PresetButton2, %PresetButton3]
		for button in buttons:
			button.text = tr("All colors in palette...")


func fill_part_list() -> void:
	var node: OptionButton = %PartListOptions
	node.clear()
	
	var body_parts = [
		"body", "head", "eyes", "wings", "tail", "horns", "hair", "hairadd",
		"ears", "nose", "facial", "add1", "add2", "add3"
	]
	for item: String in body_parts:
		node.add_item(item.capitalize())
		node.set_item_metadata(-1, item)
	
	var gear_parts = [
		"mask", "hat", "glasses", "suit", "jacket", "shirt", "gloves", "belt",
		"pants", "shoes", "back", "mainhand", "offhand", "ammo"
	]
	for item: String in gear_parts:
		node.add_item(item.capitalize())
		node.set_item_metadata(-1, item)


func is_color_dialog_visible() -> bool:
	return false


func get_color_dialog() -> Window:
	return null


func set_connections() -> void:
	close_requested.connect(hide)
	%MainCanvas.draw.connect(_on_canvas_draw)
	var items = [%PresetButton1, %PresetButton2, %PresetButton3]
	items[0].item_selected.connect(_on_all_presets_item_selected.bind("primary_colors", items[0]))
	items[1].item_selected.connect(_on_all_presets_item_selected.bind("secondary_colors", items[1]))
	items[2].item_selected.connect(_on_all_presets_item_selected.bind("fixed_colors", items[2]))
	for item in items:
		var popup = item.get_popup()
		popup.visibility_changed.connect(_on_popup_visibility_changed.bind(popup))
	items = [%HSlider1, %HSlider2, %HSlider3]
	for i in items.size():
		items[i].value_changed.connect(_on_lighten_value_changed.bind(i+1))
	
	%PartListOptions.item_selected.connect(
		func(index: int):
			var text: String = %PartListOptions.get_item_metadata(index)
			part_changed.emit(text)
	)
	
	var popup: Window = %PartListOptions.get_popup()
	popup.visibility_changed.connect(_on_popup_visibility_changed.bind(popup, Vector2i(0, -24)))


func _on_lighten_value_changed(value: float, index: int) -> void:
	if current_data:
		var palette_id = "palette%s" % index
		current_data[palette_id].lightness = value
	
	refresh_timer = 0.07
	
	emit_palette_changed()


func _on_popup_visibility_changed(popup: PopupMenu, offset: Vector2i = Vector2.ZERO):
	if popup.visible:
		var viewport_size = DisplayServer.screen_get_size()
		if position.x + size.x + popup.size.x < viewport_size.x - 10:
			popup.position.x = position.x + size.x
		else:
			popup.position.x = position.x - popup.size.x
		popup.position += offset


func _process(delta: float) -> void:
	if !visible: return
	
	if gui_disable_input:
		set_disable_input(false)
		
	if refresh_timer > 0.0:
		refresh_timer -= delta
		if refresh_timer <= 0.0:
			refresh_timer = 0.0
			refresh_item.emit(current_data)
	
	%MainCanvas.queue_redraw()
	if size.y > 600:
		set_deferred("size", Vector2i(size.x, 0))


func set_data_colors(colors: Dictionary) -> void:
	colors_data = colors
	var nodes = [%PresetButton1, %PresetButton2, %PresetButton3]
	
	for node in nodes:
		node.clear()
		node.add_item(tr("All colors in palette..."))
		node.set_item_disabled(node.get_item_count() - 1, true)
	
	var f = FileAccess.open("res://addons/rpg_character_creator/Data/ColorMaps/color_list.json", FileAccess.READ)
	var json = f.get_as_text()
	f.close()
	var color_list = JSON.parse_string(json)
	
	for category_id in color_list.keys():
		for node: OptionButton in nodes:
			node.add_separator(category_id.to_upper())
	
		color_list[category_id].sort()
		
		for key in color_list[category_id]:
			var color = colors_data.items[key]
			var img = Image.create(20, 20, true, Image.FORMAT_RGB8)
			img.fill(Color(int(color.color)))
			var tex = ImageTexture.create_from_image(img)
			for node in nodes:
				node.add_icon_item(tex, color.name)
				node.set_item_metadata(node.get_item_count() - 1, key)
	
	for node in nodes:
		node.select(0)


func clear_color_container() -> void:
	var containers = [%PrimaryColorContainer, %SecondaryColorContainer, %FixedColorContainer]
	for container in containers:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()


func set_data(data: Dictionary) -> void:
	current_data = data
	title = TranslationManager.tr("Colors for \"%s\"") % data.part_id.to_pascal_case()
	clear_color_container()
	fill_presets(%PresetContainer1, "primary_colors", "palette1")
	fill_presets(%PresetContainer2, "secondary_colors", "palette2")
	fill_presets(%PresetContainer3, "fixed_colors", "palette3")
	
	for i in %PartListOptions.get_item_count():
		var text = %PartListOptions.get_item_metadata(i)
		if text == data.part_id:
			%PartListOptions.select(i)
			break
	
	emit_palette_changed()


func emit_palette_changed() -> void:
	palette_changed.emit(current_data.part_id, {
		"blend_color1": current_data.palette1.blend_color,
		"blend_color2": current_data.palette2.blend_color,
		"blend_color3": current_data.palette3.blend_color,
		"lightness1": current_data.palette1.lightness,
		"lightness2": current_data.palette2.lightness,
		"lightness3": current_data.palette3.lightness,
		"palette1": current_data.palette1.colors,
		"palette2": current_data.palette2.colors,
		"palette3": current_data.palette3.colors
	})


func fill_presets(container: HFlowContainer, color_key: String, palette_key: String) -> void:
	size.y = 0
	
	var colors = current_data.colors[color_key]

	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	if colors.is_empty():
		var container_parent = container.get_parent().get_parent()
		container_parent.propagate_call("set_editable", [false])
		container_parent.propagate_call("set_disabled", [true])
		
		return
	
	var palette1_setted: bool = false
	var palette2_setted: bool = false
	var palette3_setted: bool = false
	
	for color_id in colors:
		var current_color = colors_data.items[color_id]
		var node = PALETTE_BUTTON.instantiate()
		var item_id = container.get_child_count()
		node.can_be_selected = true
		node.tooltip_text = "[title]Color Name[/title]\n" + current_color.name
		node.target = select_preset_color.bind(container, node, item_id, color_id, color_key, palette_key)
		node.pressed.connect(func(target: Callable): target.call())
		container.add_child(node)
		node.color = Color(int(current_color.color))
		
		if palette_key == "palette1":
			if current_data.palette1.item_selected == item_id:
				node.select(true)
				palette1_setted = true
				using_custom_primary_colors = false
		elif palette_key == "palette2":
			if current_data.palette2.item_selected == item_id:
				node.select(true)
				palette2_setted = true
				using_custom_secondary_colors = false
		elif palette_key == "palette3":
			if current_data.palette3.item_selected == item_id:
				node.select(true)
				palette3_setted = true
				using_custom_fixed_colors = false

	if palette_key == "palette1" and !palette1_setted:
		if current_data.palette1.item_selected == -2 or current_data.palette1.colors:
			fill_edit_colors(color_key, current_data.palette1.colors)
			using_custom_primary_colors = true
		else:
			using_custom_primary_colors = false
	elif palette_key == "palette2" and !palette2_setted:
		if current_data.palette2.item_selected == -2 or current_data.palette2.colors:
			fill_edit_colors(color_key, current_data.palette2.colors)
			using_custom_secondary_colors = true
		else:
			using_custom_secondary_colors = false
	elif palette_key == "palette3" and !palette3_setted:
		if current_data.palette3.item_selected == -2 or current_data.palette2.colors:
			fill_edit_colors(color_key, current_data.palette3.colors)
			using_custom_fixed_colors = true
		else:
			using_custom_fixed_colors = false
	
	%PresetButton1.set_disabled(%PresetContainer1.get_child_count() == 0 and %PrimaryColorContainer.get_child_count() == 0)
	%PresetButton2.set_disabled(%PresetContainer2.get_child_count() == 0 and %SecondaryColorContainer.get_child_count() == 0)
	%PresetButton3.set_disabled(%PresetContainer3.get_child_count() == 0 and %FixedColorContainer.get_child_count() == 0)
	
	%HSlider1.set_editable(not %PresetButton1.is_disabled())
	%HSlider2.set_editable(not %PresetButton2.is_disabled())
	%HSlider3.set_editable(not %PresetButton3.is_disabled())
	
	%PrimaryFineTune.set_disabled(%PresetButton1.is_disabled())
	%SecondaryFineTune.set_disabled(%PresetButton2.is_disabled())
	%FixedFineTune.set_disabled(%PresetButton3.is_disabled())
	
	refresh_copy_paste_buttons()
	
	%MainCanvas.queue_redraw()
	
	#wrap_controls = true
	update_window_size(4)
	
	
func update_window_size(step: int) -> void:
	if !is_inside_tree():
		return
		
	#await get_tree().process_frame
	#size.y = get_contents_minimum_size().y
	#if step > 0:
		#update_window_size(step - 1)
	#else:
		#pass
		##wrap_controls = false



func _on_all_presets_item_selected(item_id: int, color_key: String, node: OptionButton) -> void:
	if item_id == 0:
		return
	
	var preset_Button = %PresetButton1 \
		if color_key == "primary_colors" \
		else %PresetButton2 if color_key == "secondary_colors" \
		else %PresetButton3
	
	preset_Button.select(0)
		
	var key = node.get_item_metadata(item_id)
	var colors = colors_data.items[key].colors.duplicate()
	
	var palette_id = "palette1" \
		if color_key == "primary_colors" \
		else "palette2" if color_key == "secondary_colors" \
		else "palette3"
	
	colors.resize(current_data[palette_id].colors.size())
	for i in colors.size():
		if colors[i] == null:
			colors[i] = current_data[palette_id].colors[i]
	
	for i in range(0, colors.size(), 2):
		current_data[palette_id].colors[i+1] = colors[i+1]
	
	fill_edit_colors(color_key, current_data[palette_id].colors)
	
	current_data[palette_id].item_selected = -2
	
	var preset_container = %PresetContainer1 \
		if color_key == "primary_colors" \
		else %PresetContainer2 if color_key == "secondary_colors" \
		else %PresetContainer3
	
	for child in preset_container.get_children():
		child.deselect()
	
	if color_key == "primary_colors":
		using_custom_primary_colors = true
	elif color_key == "secondary_colors":
		using_custom_secondary_colors = true
	else:
		using_custom_fixed_colors = true
	
	%MainCanvas.queue_redraw()
	
	refresh_timer = 0.07
	
	emit_palette_changed()


func fill_edit_colors(color_key: String, colors: Array) -> void:
	var container = %PrimaryColorContainer \
		if color_key == "primary_colors" \
		else %SecondaryColorContainer if color_key == "secondary_colors" \
		else %FixedColorContainer
	
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	for i in range(2, colors.size(), 2):
		var color = Color(int(colors[i+1]))

		var node = PALETTE_BUTTON.instantiate()
		var item_id = container.get_child_count()
		node.can_be_selected = false
		node.target = item_id
		node.pressed.connect(_open_color_dialog.bind(color_key, colors, i + 1))
		node.mouse_entered.connect(highlight_color_selected.bind(item_id, current_data.part_id, color_key))
		node.mouse_exited.connect(unhighlight_color_selected.bind(item_id, current_data.part_id, color_key))
		container.add_child(node)
		node.color = color


func highlight_color_selected(item_id: int, part_id: String, color_key: String) -> void:
		
	var palette_id = "palette1" \
		if color_key == "primary_colors" \
		else "palette2" if color_key == "secondary_colors" \
		else "palette3"
		
	var color_index = current_data[palette_id].colors[item_id * 2 + 2]
	
	hightlight_color.emit(part_id, int(palette_id), color_index)


func unhighlight_color_selected(item_id: int, part_id: String, color_key: String) -> void:
		
	var palette_id = "palette1" \
		if color_key == "primary_colors" \
		else "palette2" if color_key == "secondary_colors" \
		else "palette3"
		
	var color_index = -1
	
	hightlight_color.emit(part_id, int(palette_id), color_index)


func _open_color_dialog(item_id: int, color_key: String, colors: Array, color_index: int) -> void:
	unhighlight_color_selected(item_id, current_data.part_id, color_key)
	
	var path = "res://addons/CustomControls/Dialogs/select_color.tscn"
	var color_dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
		
	color_dialog.color_selected.connect(_on_color_dialog_color_selected.bind(color_key, item_id), CONNECT_ONE_SHOT)
	color_dialog.preview_color.connect(_on_color_dialog_preview_color.bind(color_key, item_id))
	
	var color = Color(int(colors[color_index]))
	color_dialog.set_color(color)


func _on_color_dialog_color_selected(color: Color, color_key: String, item_id: int) -> void:
	var palette_id = "palette1" \
		if color_key == "primary_colors" \
		else "palette2" if color_key == "secondary_colors" \
		else "palette3"
		
	current_data[palette_id].item_selected = -2
	current_data[palette_id].colors[item_id * 2 + 3] = color.to_rgba32()
	
	var container = %PrimaryColorContainer \
		if color_key == "primary_colors" \
		else %SecondaryColorContainer if color_key == "secondary_colors" \
		else %FixedColorContainer
	
	container.get_child(item_id).color = color
	
	var preset_container = %PresetContainer1 \
		if color_key == "primary_colors" \
		else %PresetContainer2 if color_key == "secondary_colors" \
		else %PresetContainer3
	
	if color_key == "primary_colors":
		using_custom_primary_colors = true
	elif color_key == "secondary_colors":
		using_custom_secondary_colors = true
	else:
		using_custom_fixed_colors = true
	
	%MainCanvas.queue_redraw()
	
	for child in preset_container.get_children():
		child.deselect()
	
	refresh_timer = 0.07
	
	emit_palette_changed()
	
	DisplayServer.window_move_to_foreground(get_window_id())
	grab_focus()
	await get_tree().process_frame
	DisplayServer.window_move_to_foreground(get_window_id())
	grab_focus()


func _on_color_dialog_preview_color(color: Color, color_key: String, item_id: int) -> void:
	var part_id = current_data.part_id
	
	var palette_id = "palette1" \
		if color_key == "primary_colors" \
		else "palette2" if color_key == "secondary_colors" \
		else "palette3"
	
	current_data[palette_id].colors[item_id * 2 + 3] = color.to_rgba32()
	
	refresh_timer = 0.01


func select_preset_color(container: HFlowContainer, palette_node: Control, item_id: int, color_id: String, color_key: String, palette_key: String) -> void:
	for child in container.get_children():
		if child != palette_node:
			child.deselect()
	
	current_data[palette_key].item_selected = item_id
	current_data[palette_key].blend_color = colors_data.items[color_id].color
	current_data[palette_key].colors = colors_data.items[color_id].colors.duplicate()
	fill_edit_colors(color_key, current_data[palette_key].colors)
	
	if palette_key == "palette1":
		using_custom_primary_colors = false
	elif palette_key == "palette2":
		using_custom_secondary_colors = false
	else:
		using_custom_fixed_colors = false
	
	%MainCanvas.queue_redraw()
	
	refresh_timer = 0.07
	
	emit_palette_changed()


func _on_canvas_draw():
	var node = %MainCanvas
	
	if using_custom_primary_colors:
		var target = %PrimaryColorContainer
		if target.get_child_count() != 0:
			var rect = target.get_global_rect()
			node.draw_rect(rect, Color(0.86, 0.395, 0.218), false, 2, true)
			rect.position += Vector2(2, 2)
			rect.size -= Vector2(4, 4)
			node.draw_rect(rect, Color(0.391, 0.149, 0.053), false, 2, true)
	
	if using_custom_secondary_colors:
		var target = %SecondaryColorContainer
		if target.get_child_count() != 0:
			var rect = target.get_global_rect()
			node.draw_rect(rect, Color(0.86, 0.395, 0.218), false, 2, true)
			rect.position += Vector2(2, 2)
			rect.size -= Vector2(4, 4)
			node.draw_rect(rect, Color(0.391, 0.149, 0.053), false, 2, true)
	
	if using_custom_fixed_colors:
		var target = %FixedColorContainer
		if target.get_child_count() != 0:
			var rect = target.get_global_rect()
			node.draw_rect(rect, Color(0.86, 0.395, 0.218), false, 2, true)
			rect.position += Vector2(2, 2)
			rect.size -= Vector2(4, 4)
			node.draw_rect(rect, Color(0.391, 0.149, 0.053), false, 2, true)


func hide_all() -> void:
	visible = false


func _open_fine_tune_dialog(colors: Array[Color], part: int) -> void:
	var path = "res://addons/CustomControls/Dialogs/fine_tune_palette_colors.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.set_colors(colors)
	dialog.colors_changed.connect(_on_dialog_color_changed.bind(part))


func _on_dialog_color_changed(colors: Array[Color], part: int) -> void:
	# Identificamos qué paleta estamos tocando según el ID de la parte (1, 2 o 3)
	var palette_key: String = "palette%s" % part
	var color_key: String = ""
	var preset_container: HFlowContainer = null
	
	match part:
		1:
			color_key = "primary_colors"
			preset_container = %PresetContainer1
			using_custom_primary_colors = true
		2:
			color_key = "secondary_colors"
			preset_container = %PresetContainer2
			using_custom_secondary_colors = true
		3:
			color_key = "fixed_colors"
			preset_container = %PresetContainer3
			using_custom_fixed_colors = true
	
	# Deseleccionamos cualquier preset activo, ya que ahora estamos en modo "custom"
	current_data[palette_key].item_selected = -2
	for child in preset_container.get_children():
		child.deselect()

	# Mapeamos los colores modificados (Array[Color]) de vuelta al array de enteros (rgba32)
	# La estructura raw_data coincide con la lógica de fill_edit_colors:
	# Los índices 3, 5, 7, etc. contienen los valores de color.
	var raw_data = current_data[palette_key].colors
	
	for i in range(colors.size()):
		var target_index = 3 + (i * 2)
		if target_index < raw_data.size():
			raw_data[target_index] = colors[i].to_rgba32()
	
	# Actualizamos los botones visuales (ColorRects) con los nuevos valores
	fill_edit_colors(color_key, raw_data)
	
	# Forzamos el redibujado
	%MainCanvas.queue_redraw()
	
	# Programamos la actualización del sprite del personaje
	refresh_timer = 0.01 
	emit_palette_changed()


func _extract_colors_from_palette(palette_key: String) -> Array[Color]:
	var extracted_colors: Array[Color] = []
	var raw_data = current_data[palette_key].colors
	for i in range(2, raw_data.size(), 2):
		var color_int = raw_data[i + 1]
		extracted_colors.append(Color(int(color_int)))
		
	return extracted_colors


func _on_primary_fine_tune_pressed() -> void:
	var colors: Array[Color] = _extract_colors_from_palette("palette1")
	_open_fine_tune_dialog(colors, 1)


func _on_secondary_fine_tune_pressed() -> void:
	var colors: Array[Color] = _extract_colors_from_palette("palette2")
	_open_fine_tune_dialog(colors, 2)


func _on_fixed_fine_tune_pressed() -> void:
	var colors: Array[Color] = _extract_colors_from_palette("palette3")
	_open_fine_tune_dialog(colors, 3)


func _copy_palette_to_clipboard(type: int) -> void:
	var palette_key = "palette%s" % type
	
	var source_colors: Array[Color] = _extract_colors_from_palette(palette_key)
	StaticEditorVars.CLIPBOARD.character_palette_color = source_colors
	
	refresh_copy_paste_buttons()


func _paste_palette_from_clipboard(type: int) -> void:
	if not "character_palette_color" in StaticEditorVars.CLIPBOARD:
		return
		
	var clipboard: Array[Color] = StaticEditorVars.CLIPBOARD.character_palette_color
	var palette_key = "palette%s" % type
	var color_key = ""
	match type:
		1: color_key = "primary_colors"
		2: color_key = "secondary_colors"
		3: color_key = "fixed_colors"
	var raw_data = current_data[palette_key].colors
	var pasted_count = 0
	var available_slots = (raw_data.size() - 2) / 2
	var limit = min(clipboard.size(), available_slots)
	for i in range(limit):
		var target_index = 3 + (i * 2)
		raw_data[target_index] = clipboard[i].to_rgba32()
		pasted_count += 1
	
	if pasted_count > 0:
		fill_edit_colors(color_key, raw_data)
		
		current_data[palette_key].item_selected = -2
		var preset_container = get_node("%%PresetContainer%s" % type)
		if preset_container:
			for child in preset_container.get_children():
				child.deselect()
		
		if type == 1: using_custom_primary_colors = true
		elif type == 2: using_custom_secondary_colors = true
		elif type == 3: using_custom_fixed_colors = true
		
		%MainCanvas.queue_redraw()
		refresh_timer = 0.07
		emit_palette_changed()


func _on_copy_primary_colors_pressed() -> void:
	_copy_palette_to_clipboard(1)


func _on_paste_primary_colors_pressed() -> void:
	_paste_palette_from_clipboard(1)


func _on_copy_secondary_colors_pressed() -> void:
	_copy_palette_to_clipboard(2)


func _on_paste_secondary_colors_pressed() -> void:
	_paste_palette_from_clipboard(2)


func _on_copy_fixed_colors_pressed() -> void:
	_copy_palette_to_clipboard(3)


func _on_paste_fixed_colors_pressed() -> void:
	_paste_palette_from_clipboard(3)
