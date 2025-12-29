@tool
extends Control

@export var label_text: String : set = _set_label_text
@export var text_gradient: GradientTexture2D : set = _set_label_gradient
@export var horizontal_align: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER : set = _set_horizontal_align
@export var vertical_align: VerticalAlignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER: set = _set_vertical_align
@onready var button_name: Label = %ButtonName
@onready var outline: Label = %Outline


func _ready() -> void:
	if Engine.is_editor_hint():
		item_rect_changed.connect(_update_labels)
		item_rect_changed.connect(button_name.adjust_text_fit)
	_set_label_gradient(text_gradient)
	_fix_label(3)
	_start()


func _process(_delta: float) -> void:
	button_name.position = Vector2.ZERO
	outline.position = Vector2.ZERO


func _fix_label(repeats: int = 0) -> void:
	if not is_inside_tree(): return
	
	if  Engine.is_editor_hint():
		await RenderingServer.frame_post_draw

	_update_labels()
	await RenderingServer.frame_post_draw
	button_name.adjust_text_fit()
	if repeats > 0:
		await RenderingServer.frame_post_draw
		if is_inside_tree():
			_fix_label(repeats - 1)


func _start() -> void:
	button_name.material = button_name.material.duplicate()
	outline.label_settings = outline.label_settings.duplicate_deep()
	_fix_label(3)


func _set_label_text(value: String) -> void:
	label_text = value
	if Engine.is_editor_hint():
		_fix_label(3)
	else:
		_update_labels()


func _set_label_gradient(value: GradientTexture2D) -> void:
	text_gradient = value
	if is_node_ready():
		button_name.get_material().set_shader_parameter("gradient_texture", value)


func _on_button_name_font_size_changed(new_size: int) -> void:
	if is_node_ready():
		outline.set("theme_override_font_sizes/font_size", new_size)
		if outline.label_settings:
			outline.label_settings.font_size = new_size


func _update_labels() -> void:
	if is_node_ready():
		button_name.horizontal_alignment = horizontal_align
		button_name.vertical_alignment = vertical_align
		button_name.set_deferred("size", size)
		button_name.pivot_offset = size / 2
		button_name.text = ""
		button_name.text = label_text
		button_name.get_material().set_shader_parameter("size", size)
		button_name.position = Vector2.ZERO
		outline.horizontal_alignment = horizontal_align
		outline.vertical_alignment = vertical_align
		outline.set_deferred("size", size)
		outline.pivot_offset = size / 2
		outline.text = label_text
		outline.position = Vector2.ZERO


func _set_horizontal_align(value: HorizontalAlignment):
	horizontal_align = value
	_update_labels()


func _set_vertical_align(value: VerticalAlignment):
	vertical_align = value
	_update_labels()
