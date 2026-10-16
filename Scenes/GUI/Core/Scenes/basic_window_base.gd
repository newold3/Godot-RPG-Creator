@tool
class_name BasicWindowBase
extends PanelContainer

enum WindowMode {
	BORDERS,
	TEXTURE,
}

@export var window_mode: WindowMode = WindowMode.BORDERS:
	set(val):
		window_mode = val
		notify_property_list_changed()
		queue_redraw()

@export_group("Texture")
@export var texture_style: StyleBoxTexture:
	set(val):
		_disconnect_style(texture_style)
		texture_style = val
		_connect_style(texture_style)
		queue_redraw()

@export_group("Styles")
@export var background_style: StyleBoxFlat:
	set(val):
		_disconnect_style(background_style)
		background_style = val
		_connect_style(background_style)
		_apply_corner_radius(background_style, corner_radius)
		queue_redraw()

@export var border_style: StyleBoxFlat:
	set(val):
		_disconnect_style(border_style)
		border_style = val
		_connect_style(border_style)
		_apply_border_width()
		_apply_corner_radius(border_style, corner_radius)
		queue_redraw()

@export var exterior_style: StyleBoxFlat:
	set(val):
		_disconnect_style(exterior_style)
		exterior_style = val
		_connect_style(exterior_style)
		_apply_corner_radius(exterior_style, corner_radius)
		queue_redraw()

@export var interior_style: StyleBoxFlat:
	set(val):
		_disconnect_style(interior_style)
		interior_style = val
		_connect_style(interior_style)
		_apply_corner_radius(interior_style, maxi(0, corner_radius - border_width))
		queue_redraw()

@export_group("Border & Radius")
@export_range(0, 64) var border_width: int = 8:
	set(val):
		border_width = val
		_apply_border_width()
		_apply_corner_radii()
		queue_redraw()

@export_range(0, 64) var corner_radius: int = 16:
	set(val):
		corner_radius = val
		_apply_corner_radii()
		queue_redraw()

@export_group("Content Margins")
@export_range(0, 128, 1.0, "or_greater") var content_margin_left: float = 14.0:
	set(val):
		content_margin_left = val
		_apply_content_margins()

@export_range(0, 128, 1.0, "or_greater") var content_margin_top: float = 14.0:
	set(val):
		content_margin_top = val
		_apply_content_margins()

@export_range(0, 128, 1.0, "or_greater") var content_margin_right: float = 14.0:
	set(val):
		content_margin_right = val
		_apply_content_margins()

@export_range(0, 128, 1.0, "or_greater") var content_margin_bottom: float = 14.0:
	set(val):
		content_margin_bottom = val
		_apply_content_margins()

var interior_inset: int:
	get:
		return border_width
	set(val):
		border_width = val

var central_border_width: int:
	get:
		return border_width
	set(val):
		border_width = val


func _validate_property(property: Dictionary) -> void:
	if window_mode == WindowMode.TEXTURE:
		if property.name in [
			"Styles",
			"background_style",
			"border_style",
			"exterior_style",
			"interior_style",
			"Border & Radius",
			"border_width",
			"corner_radius"
		]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif window_mode == WindowMode.BORDERS:
		if property.name in [
			"Texture",
			"texture_style"
		]:
			property.usage = PROPERTY_USAGE_NO_EDITOR


func _ready() -> void:
	_connect_style(texture_style)
	_connect_style(background_style)
	_connect_style(border_style)
	_connect_style(exterior_style)
	_connect_style(interior_style)
	_apply_all_properties()


func _connect_style(style: StyleBox) -> void:
	if style and not style.changed.is_connected(queue_redraw):
		style.changed.connect(queue_redraw)


func _disconnect_style(style: StyleBox) -> void:
	if style and style.changed.is_connected(queue_redraw):
		style.changed.disconnect(queue_redraw)


func _apply_corner_radius(style: StyleBoxFlat, radius: int) -> void:
	if style:
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_right = radius
		style.corner_radius_bottom_left = radius


func _apply_corner_radii() -> void:
	_apply_corner_radius(background_style, corner_radius)
	_apply_corner_radius(border_style, corner_radius)
	_apply_corner_radius(exterior_style, corner_radius)
	var int_radius: int = maxi(0, corner_radius - border_width)
	_apply_corner_radius(interior_style, int_radius)


func _apply_border_width() -> void:
	if border_style:
		border_style.border_width_left = border_width
		border_style.border_width_top = border_width
		border_style.border_width_right = border_width
		border_style.border_width_bottom = border_width


func _apply_content_margins() -> void:
	var style: StyleBox = null
	if has_theme_stylebox_override("panel"):
		style = get_theme_stylebox("panel")
	if not style:
		style = StyleBoxEmpty.new()
		add_theme_stylebox_override("panel", style)
	
	style.content_margin_left = content_margin_left
	style.content_margin_top = content_margin_top
	style.content_margin_right = content_margin_right
	style.content_margin_bottom = content_margin_bottom
	queue_sort()


func _apply_all_properties() -> void:
	_apply_border_width()
	_apply_corner_radii()
	_apply_content_margins()


func _draw() -> void:
	var base_rect = Rect2(Vector2.ZERO, size)
	if base_rect.size.x <= 0 or base_rect.size.y <= 0:
		return
	
	if window_mode == WindowMode.TEXTURE:
		if texture_style:
			draw_style_box(texture_style, base_rect)
	else:
		if background_style:
			draw_style_box(background_style, base_rect)
			
		if border_style:
			draw_style_box(border_style, base_rect)
			
		if exterior_style:
			draw_style_box(exterior_style, base_rect)
			
		if interior_style:
			var interior_rect = base_rect.grow(-border_width)
			if interior_rect.size.x > 0 and interior_rect.size.y > 0:
				draw_style_box(interior_style, interior_rect)
