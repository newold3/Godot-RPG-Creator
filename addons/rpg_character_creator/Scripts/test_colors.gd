@tool
extends Node2D

## The current palette texture.
@export var current_palete: Texture : set = set_texture

## The path to the color configuration file.
@export_file var current_colors: String : set = set_colors

## The index of the currently selected color.
@export var index: int : set = set_index

var colors: Array = []



## Sets the current palette texture and updates the view.
func set_texture(value: Texture) -> void:
	current_palete = value
	update()



## Reads the color data from the specified path, supporting packed archives.
func set_colors(value: String) -> void:
	current_colors = value
	var json = ZipMediaLoader.get_text_content(value)
	
	if json.is_empty():
		colors = []
		update()
		return
	
	var data = JSON.parse_string(json)
	
	if data and data.has("items"):
		colors = data.items
	else:
		colors = []
	
	update()



## Sets the color index safely within bounds.
func set_index(value: int) -> void:
	index = max(-1, min(value, colors.size() - 1))
	update()



## Updates the visual representation of the original and swapped colors.
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
