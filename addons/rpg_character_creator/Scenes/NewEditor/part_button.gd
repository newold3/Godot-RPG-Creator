@tool
class_name HeroEditorPartButton
extends Control

## Background style for the normal state.
@export var background_style: StyleBox
## Background style when the item has focus.
@export var selected_style: StyleBox
## Background style when the mouse is hovering over the item.
@export var hover_style: StyleBox

var _is_hovering: bool = false
var part_id: String = ""
var item_id: String = ""

signal pressed()

static var buttons: Array[Control] = []


func _init() -> void:
	focus_mode = FOCUS_ALL


func _draw() -> void:
	var current_style: StyleBox = background_style

	if has_focus() and selected_style:
		current_style = selected_style
	elif _is_hovering and hover_style:
		current_style = hover_style

	var draw_rect: Rect2 = Rect2(Vector2.ZERO, size)

	if current_style:
		draw_style_box(current_style, draw_rect)

		var margin_left: float = current_style.content_margin_left
		var margin_top: float = current_style.content_margin_top
		var margin_right: float = current_style.content_margin_right
		var margin_bottom: float = current_style.content_margin_bottom

		draw_rect.position += Vector2(margin_left, margin_top)
		draw_rect.size -= Vector2(margin_left + margin_right, margin_top + margin_bottom)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			grab_focus()
			pressed.emit()
			accept_event()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_is_hovering = true
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			_is_hovering = false
			queue_redraw()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT:
			queue_redraw()


func set_main_material(mat: ShaderMaterial) -> void:
	%Texture.material = mat


func set_shader_colors(g1: PackedColorArray, g2: PackedColorArray, g3: PackedColorArray) -> void:
	var main_material = %Texture.material
	if main_material:
		main_material.set_shader_parameter("palette1", g1)
		main_material.set_shader_parameter("palette2", g2)
		main_material.set_shader_parameter("palette3", g3)


## Updates the textures and region, forcing a redraw.
func set_textures(_textures: Array[Texture], _region: Rect2 = Rect2()) -> void:
	var node = %Texture
	
	if _textures.is_empty():
		node.texture = null
		return

	if _textures.size() == 1:
		var tex = _textures[0]
		if _region.has_area():
			var atlas = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = _region
			node.texture = atlas
		else:
			node.texture = tex
		return

	var first_valid_tex: Texture2D = _textures[0]
	if not first_valid_tex:
		return

	var final_image: Image = first_valid_tex.get_image().duplicate()
	
	for i in range(1, _textures.size()):
		var tex = _textures[i]
		if tex:
			var layer_img = tex.get_image()
			final_image.blend_rect(
				layer_img, 
				Rect2(Vector2.ZERO, layer_img.get_size()), 
				Vector2.ZERO
			)

	var final_texture = ImageTexture.create_from_image(final_image)

	if _region.has_area():
		var atlas = AtlasTexture.new()
		atlas.atlas = final_texture
		atlas.region = _region
		node.texture = atlas
	else:
		node.texture = final_texture


## Programmatically selects the item by grabbing focus.
func select() -> void:
	grab_focus()
