@tool
extends Window

var data1
var data2
var data3

var current_selection: Dictionary

const PALETTE_COLOR_BUTTON = preload("res://addons/CustomControls/palette_color_button.tscn")

signal update_palette_requested(index: int, target: TextureRect, palette: Dictionary)


func _ready() -> void:
	close_requested.connect(hide)
	%PaletteContainer.draw.connect(draw_cursors)
	size_changed.connect(%PaletteContainer.queue_redraw)


func fast_refresh() -> void:
	set_data(data1, data2, data3)


func set_data(obj1, obj2, obj3) -> void:
	data1 = obj1 if obj1 is Dictionary else null
	data2 = obj2 if obj2 is Dictionary else null
	data3 = obj3 if obj3 is Dictionary else null
	update_buttons()


func clear() -> void:
	title = TranslationManager.tr("none")
	data1 = null
	data2 = null
	data3 = null
	for i in range(1, 4):
		var container = get_node("%%ColorContainer%s" % i)
		var container2 = get_node("%%PresetsContainer%s" % i)
		for child in container.get_children():
			child.get_parent().remove_child(child)
			child.queue_free()
		for child in container2.get_children():
			child.get_parent().remove_child(child)
			child.queue_free()
		container.size.y = 0
		get_node("%%HSlider%sa" % i).set_editable(false)
		get_node("%%Palette%s" % i).set_disabled(true)
	
	%PaletteContainer.queue_redraw()


func update_buttons():
	for i in range(1, 4):
		var container = get_node("%%ColorContainer%s" % i)
		var container2 = get_node("%%PresetsContainer%s" % i)
		for child in container.get_children():
			child.get_parent().remove_child(child)
			child.queue_free()
		for child in container2.get_children():
			child.get_parent().remove_child(child)
			child.queue_free()
		container.size.y = 0
		
		var current_data = get("data%s" % i)
		if current_data:
			for j in current_data.data.size():
				var palette = current_data.data[j]
				var img = Image.create(1, 1, true, Image.FORMAT_RGBA8)
				img.set_pixel(0, 0, Color(int(palette.color)))
				var b = PALETTE_COLOR_BUTTON.instantiate()
				b.icon = ImageTexture.create_from_image(img)
				b.pressed.connect(_on_palette_button_pressed.bind(b, i))
				container.add_child(b)
			
			var node = get_node("%%HSlider%sa" % i)
			node.set_value(current_data.palette.lightness)
			node.set_editable(true)
			node = get_node("%%Palette%s" % i)
			node.set_disabled(false)
		else:
			var node = get_node("%%HSlider%sa" % i)
			node.set_editable(false)
			node = get_node("%%Palette%s" % i)
			node.set_disabled(true)

		if current_data and container.get_child_count() > current_data.palette.item_selected:
			if current_data.palette.item_selected != -1:
				var b = container.get_child(current_data.palette.item_selected)
				b.pressed.emit()
			else:
				var real_colors = current_data.palette.custom_colors
				fill_custom_gradient(i, real_colors, real_colors)
	
	size.y = 0
	%PaletteContainer.queue_redraw()
	
	#await get_tree().process_frame
	#await get_tree().process_frame
	#await get_tree().process_frame
	#
	#size = %MainContainer.size.y + 40
	#
	#await get_tree().process_frame
	#%PaletteContainer.queue_redraw()


func get_gradient(current_data_color: Dictionary) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray([])
	colors.resize(256)
	
	if current_data_color.colors.size() > 0:
		for i in range(0, current_data_color.colors.size(), 2):
			var index = int(current_data_color.colors[i])
			var color = Color(int(current_data_color.colors[i+1]))
			colors[index] = color
		
	return colors


func _on_palette_button_pressed(button: Button, data_index: int) -> void:
	var current_data = get("data%s" % data_index)
	var current_color = current_data.data[button.get_index()]
	
	current_data.palette.item_selected = button.get_index()
	current_data.palette.current_gradient = get_gradient(current_color)
	current_data.palette.custom_colors = current_color
	
	update_palette_requested.emit(data_index, current_data.target, current_data.palette)
	
	var real_colors = current_color.duplicate(true)
	fill_custom_gradient(data_index, current_color, real_colors)


func fill_custom_gradient(data_index: int, current_color: Dictionary, real_colors: Dictionary) -> void:
	var panel_id = "%%PresetsContainer%s" % data_index
	var panel = get_node(panel_id)
	for child in panel.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for i in range(0, current_color.colors.size(), 2):
		var b: ColorPickerButton = ColorPickerButton.new()
		var color_id = int(current_color.colors[i + 1])
		if color_id == 0:
			continue
		var color = Color(color_id)
		b.set_pick_color(color)
		b.custom_minimum_size = Vector2i(32, 32)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.color_changed.connect(_on_using_custom_color.bind(b, data_index))
		b.set_meta("real_colors", real_colors)
		b.focus_mode = Control.FOCUS_NONE
		panel.add_child(b)
	
	%PaletteContainer.queue_redraw()


func _on_using_custom_color(color: Color, button: ColorPickerButton, data_index: int) -> void:
	var current_data = get("data%s" % data_index)
	var current_color = button.get_meta("real_colors")
	var index = button.get_index() * 2 + 3
	current_color.colors[index] = color.to_rgba32()
	
	current_data.palette.item_selected = -1
	current_data.palette.current_gradient = get_gradient(current_color)
	current_data.palette.custom_colors = current_color
	update_palette_requested.emit(data_index, current_data.target, current_data.palette)
	
	%PaletteContainer.queue_redraw()


func prepare_signal(data_index: int) -> void:
	var current_data = get("data%s" % data_index)
	if !current_data:
		return
	update_palette_requested.emit(data_index, current_data.target, current_data.palette)
	
	%PaletteContainer.queue_redraw()


func _on_h_slider_1a_value_changed(value: float) -> void:
	data1.palette.lightness = value
	prepare_signal(1)


func _on_h_slider_2a_value_changed(value: float) -> void:
	data2.palette.lightness = value
	prepare_signal(2)


func _on_h_slider_3a_value_changed(value: float) -> void:
	data3.palette.lightness = value
	prepare_signal(3)


func draw_cursors() -> void:
	for i in range(1, 4, 1):
		var current_data = get("data%s" % i)
		var container = get_node("%%ColorContainer%s" % i)
		
		if current_data:
			var b
			if current_data.palette.item_selected != -1:
				b = container.get_child(current_data.palette.item_selected)
			else:
				b = get_node("%%PresetsContainer%s" % i).get_parent()
				
			var r = b.get_global_rect()
			r.position -= Vector2(2, 2)
			r.size += Vector2(4, 4)
			%PaletteContainer.draw_rect(r, Color.ORANGE, false, 3)


func fill_colors(colors: Array) -> void:
	var nodes = [%Palette1, %Palette2, %Palette3]
	
	for node in nodes:
		node.clear()
		node.add_item("All colors in palette...")
	
	for color in colors:
		var img = Image.create(20, 20, true, Image.FORMAT_RGB8)
		img.fill(Color(int(color.color)))
		var tex = ImageTexture.create_from_image(img)
		for node in nodes:
			node.add_icon_item(tex, color.id)
			node.set_item_metadata(node.get_item_count() - 1, color)



func _on_all_colors_in_palette_item_selected(index: int, data_index: int) -> void:
	if index == 0:
		return
		
	var nodes = [%Palette1, %Palette2, %Palette3]
	nodes[data_index].select(0)
	
	var current_color = nodes[data_index].get_item_metadata(index)
	
	data_index += 1
	
	var current_data = get("data%s" % data_index)
	
	if !current_data: return
	
	var real_color = current_data.data[0].duplicate(true)
	
	for i in range(0, real_color.colors.size(), 2):
		if current_color.colors.size() > i+1:
			real_color.colors[i+1] = current_color.colors[i+1]
		else:
			break
	
	current_data.palette.item_selected = -1
	current_data.palette.current_gradient = get_gradient(real_color)
	current_data.palette.custom_colors = real_color
	
	update_palette_requested.emit(data_index, current_data.target, current_data.palette)

	fill_custom_gradient(data_index, real_color, real_color)
	
	await get_tree().process_frame
	
	%PaletteContainer.queue_redraw()
