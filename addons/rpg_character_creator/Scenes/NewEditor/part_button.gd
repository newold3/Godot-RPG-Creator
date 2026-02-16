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
var is_selected: bool = false

signal pressed()
signal selected(button: HeroEditorPartButton)
signal save(part_id: String, item_id: String, tex: HeroEditorPartButton)

static var buttons: Array[HeroEditorPartButton] = []


func _init() -> void:
	focus_mode = FOCUS_CLICK


func _ready() -> void:
	if not self in buttons:
		buttons.append(self)
	tree_exiting.connect(func(): if self in buttons: buttons.erase(self))
	selected.connect(_on_selected)
	var neighbors = ["focus_neighbor_left", "focus_neighbor_top", "focus_neighbor_right", "focus_neighbor_bottom", "focus_next", "focus_previous"]
	for key in neighbors:
		set(key, get_path())


func _on_selected(button_selected: HeroEditorPartButton) -> void:
	for b in buttons:
		if b != button_selected:
			b.is_selected = false


func _draw() -> void:
	var current_style: StyleBox = background_style

	if (is_selected or has_focus()) and selected_style:
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
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				select()
				accept_event()
				pressed.emit()


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

	var first_valid_tex: Texture = _textures[0]
	if not first_valid_tex:
		return

	var final_image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	for t: Texture in _textures:
		if not t: continue
		var raw_img = t.get_image()
		var src_rect = Rect2i(_region) if _region.has_area() else Rect2i(0, 0, raw_img.get_width(), raw_img.get_height())
		if src_rect.position.x >= raw_img.get_width() or src_rect.position.y >= raw_img.get_height():
			continue

		var max_w = raw_img.get_width() - src_rect.position.x
		var max_h = raw_img.get_height() - src_rect.position.y
		src_rect.size.x = min(src_rect.size.x, max_w)
		src_rect.size.y = min(src_rect.size.y, max_h)
		
		if src_rect.size.x <= 0 or src_rect.size.y <= 0:
			continue

		var cut_img = raw_img.get_region(src_rect)
		
		var used_rect = cut_img.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			continue
			
		var trimmed_img = cut_img.get_region(used_rect)

		var w = float(trimmed_img.get_width())
		var h = float(trimmed_img.get_height())
		var max_side = 52.0
		var min_side = 32.0
		var current_max = max(w, h)
		var scale_factor = 1.0
		var needs_resize = false
		var interp_mode = Image.INTERPOLATE_NEAREST
		
		if current_max > max_side:
			scale_factor = max_side / current_max
			needs_resize = true
		elif current_max < min_side:
			scale_factor = min_side / current_max
			needs_resize = true
			
		if needs_resize:
			var new_w = max(1, int(w * scale_factor))
			var new_h = max(1, int(h * scale_factor))
			trimmed_img.resize(new_w, new_h, interp_mode)
			
		var dest_x = int((64 - trimmed_img.get_width()) / 2.0)
		var dest_y = int((64 - trimmed_img.get_height()) / 2.0)
		
		final_image.blend_rect(trimmed_img, Rect2i(0, 0, trimmed_img.get_width(), trimmed_img.get_height()), Vector2i(dest_x, dest_y))

	var final_texture = ImageTexture.create_from_image(final_image)

	node.texture = final_texture


func get_texture_rect() -> TextureRect:
	return %Texture


## Programmatically selects the item by grabbing focus.
func select() -> void:
	grab_focus()
	is_selected = true
	selected.emit(self)


func hide_save_button() -> void:
	$Save.visible = false


func _on_save_pressed() -> void:
	if not %Save.visible: return
	save.emit(part_id, item_id, self)
	
	var t = create_tween()
	t.tween_property(self, "modulate", Color("#60de6e"), 0.1)
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
