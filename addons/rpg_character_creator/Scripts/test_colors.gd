@tool
extends Node2D

@export var current_palete : Texture : set = set_texture
@export_file var current_colors : String : set = set_colors

@export var index: int : set = set_index


var colors: Array = []


func set_texture(value: Texture) -> void:
	current_palete = value
	
	update()


func set_colors(value: String) -> void:
	var f = FileAccess.open(value, FileAccess.READ)
	var json = f.get_as_text()
	f.close()
	
	current_colors = value
	
	var data = JSON.parse_string(json)
	
	colors = data.items
	
	update()


func set_index(value: int) -> void:
	index = max(-1, min(value, colors.size() - 1))
	
	update()


func update() -> void:
	if !get_node_or_null("%OriginalColor"):
		return
		
	if current_palete and colors and colors.size() > index and index != -1:
		var color = colors[index].colors
		print("Color Selected:")
		print(colors[index])
		print()
		var color_count = color.size()
		var margin = 2
		var w = 20 * color_count + margin * color_count
		var h = 20
		var img1 = Image.create(w, h, false, Image.FORMAT_RGBA8)
		var img2 = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for i in range(0, color_count, 2):
			var c1 = current_palete.get_image().get_pixel(int(color[i]), 0)
			var c2 = Color(int(color[i+1]))
			var x = i * 20 + i * margin
			img1.fill_rect(Rect2i(x, 0, 20, 20), c1)
			img2.fill_rect(Rect2i(x, 0, 20, 20), c2)
		%OriginalColor.texture = ImageTexture.create_from_image(img1)
		%SwapColor.texture = ImageTexture.create_from_image(img2)
	else:
		%OriginalColor.texture = null
		%SwapColor.texture = null
