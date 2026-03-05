@tool
extends Control
class_name PaintableCanvas

## Defines the type of effect this mask will trigger in-game.
@export_enum("None", "Water", "Reflection") var mask_type: String = "None"

## Defines the current size of the painting brush.
@export var brush_size: int = 20

## Defines the color applied when painting on the mask.
@export var brush_color: Color = Color.BLACK

## Minimum allowed width and height for the canvas to prevent errors.
@export var min_canvas_size: Vector2 = Vector2(64.0, 64.0)

## Maximum allowed width and height for the canvas to prevent memory issues.
@export var max_canvas_size: Vector2 = Vector2(4096.0, 4096.0)

var mask_image: Image
var _mask_texture: ImageTexture
var _preview_pos: Vector2 = Vector2.ZERO
var _show_preview: bool = false
var _is_preview_erasing: bool = false
var _is_drawing_stroke: bool = false
var _last_paint_pos: Vector2 = Vector2.ZERO
var _resize_dirty: bool = false
var _last_resize_time: int = 0
var _resize_delay_ms: int = 300


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		"name": "mask_image",
		"type": TYPE_OBJECT,
		"class_name": "Image",
		"usage": PROPERTY_USAGE_STORAGE
	})
	return properties


func _ready() -> void:
	clip_contents = true
	_initialize_image()
	
	if not item_rect_changed.is_connected(_on_item_rect_changed):
		item_rect_changed.connect(_on_item_rect_changed)


func _process(_delta: float) -> void:
	if _resize_dirty and Time.get_ticks_msec() - _last_resize_time > _resize_delay_ms:
		_apply_resize()


func _initialize_image() -> void:
	var clamped_size: Vector2i = _get_clamped_size(size)
	
	if mask_image == null or mask_image.is_empty():
		mask_image = Image.create_empty(clamped_size.x, clamped_size.y, false, Image.FORMAT_RGBA8)
		mask_image.fill(Color(0, 0, 0, 0))
		
	_mask_texture = ImageTexture.create_from_image(mask_image)
	queue_redraw()


func _on_item_rect_changed() -> void:
	var clamped_size: Vector2 = Vector2(
		clampf(size.x, min_canvas_size.x, max_canvas_size.x),
		clampf(size.y, min_canvas_size.y, max_canvas_size.y)
	)
	
	if size != clamped_size:
		size = clamped_size
		return
		
	_resize_dirty = true
	_last_resize_time = Time.get_ticks_msec()


func _apply_resize() -> void:
	_resize_dirty = false
	var new_size: Vector2i = _get_clamped_size(size)
	
	if mask_image and not mask_image.is_empty():
		var old_image := mask_image.duplicate() as Image
		mask_image = Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
		mask_image.fill(Color(0, 0, 0, 0))
		
		var blend_rect := Rect2i(0, 0, mini(old_image.get_width(), new_size.x), mini(old_image.get_height(), new_size.y))
		mask_image.blend_rect(old_image, blend_rect, Vector2i.ZERO)
	else:
		mask_image = Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
		mask_image.fill(Color(0, 0, 0, 0))
		
	_mask_texture = ImageTexture.create_from_image(mask_image)
	queue_redraw()


func _get_clamped_size(current_size: Vector2) -> Vector2i:
	var x: int = clampi(int(current_size.x), int(min_canvas_size.x), int(max_canvas_size.x))
	var y: int = clampi(int(current_size.y), int(min_canvas_size.y), int(max_canvas_size.y))
	return Vector2i(x, y)


func _draw() -> void:
	if _mask_texture:
		draw_texture(_mask_texture, Vector2.ZERO)
		
	if _show_preview:
		var preview_color: Color = Color.RED if _is_preview_erasing else Color.BLUE
		draw_arc(_preview_pos, float(brush_size), 0.0, TAU, 32, preview_color, 2.0)
		draw_circle(_preview_pos, float(brush_size), Color(preview_color.r, preview_color.g, preview_color.b, 0.1))


func clear_history() -> void:
	if mask_image:
		mask_image.fill(Color(0, 0, 0, 0))
		if _mask_texture:
			_mask_texture.update(mask_image)
		queue_redraw()


func begin_stroke(local_pos: Vector2, is_painting: bool) -> void:
	_is_drawing_stroke = true
	_last_paint_pos = local_pos
	_draw_circle_on_image(local_pos, brush_size, not is_painting)
	
	if _mask_texture:
		_mask_texture.update(mask_image)
	queue_redraw()


func continue_stroke(local_pos: Vector2, is_painting: bool) -> void:
	if not _is_drawing_stroke:
		begin_stroke(local_pos, is_painting)
		return
		
	var dist: float = _last_paint_pos.distance_to(local_pos)
	var steps: int = maxi(1, int(dist / (brush_size * 0.25)))
	
	for i in range(steps + 1):
		var t: float = float(i) / steps
		var pos: Vector2 = _last_paint_pos.lerp(local_pos, t)
		_draw_circle_on_image(pos, brush_size, not is_painting)
		
	_last_paint_pos = local_pos
	
	if _mask_texture:
		_mask_texture.update(mask_image)
	queue_redraw()


func end_stroke() -> void:
	_is_drawing_stroke = false


func _draw_circle_on_image(center: Vector2, radius: int, is_erasing: bool) -> void:
	if mask_image == null or mask_image.is_empty():
		return
		
	var img_rect := Rect2i(0, 0, mask_image.get_width(), mask_image.get_height())
	var local_pos := Vector2i(center)
	var bounds := Rect2i(local_pos.x - radius, local_pos.y - radius, radius * 2, radius * 2)
	
	var color: Color = Color(0, 0, 0, 0) if is_erasing else brush_color
	
	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			var point := Vector2i(x, y)
			if img_rect.has_point(point):
				if Vector2(local_pos).distance_to(Vector2(point)) <= radius:
					mask_image.set_pixelv(point, color)


func update_preview(pos: Vector2, show: bool, is_erasing: bool) -> void:
	_preview_pos = pos
	_show_preview = show
	_is_preview_erasing = is_erasing
	queue_redraw()
