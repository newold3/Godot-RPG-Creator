@tool
extends Control

## The text to be displayed on the label and its outline
@export var label_text: String : set = _set_label_text

## The gradient texture applied to the main label text
@export var text_gradient: GradientTexture2D : set = _set_label_gradient

## The horizontal alignment for both the main label and outline
@export var horizontal_align: HorizontalAlignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER : set = _set_horizontal_align

## The vertical alignment for both the main label and outline
@export var vertical_align: VerticalAlignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER: set = _set_vertical_align

## The minimum font size allowed for the auto-fit logic
@export_range(6, 500, 1) var min_font_size: int = 6 :
	set(value):
		min_font_size = value
		_update_labels()

## The maximum font size allowed for the auto-fit logic
@export_range(6, 500, 1) var max_font_size: int = 500 :
	set(value):
		max_font_size = value
		_update_labels()

## Forces a specific font size, ignoring auto-fit if greater than -1
@export_range(-1, 500, 1) var force_text_size: int = -1 :
	set(value):
		force_text_size = value
		_update_labels()


@onready var button_name: Label = %ButtonName
@onready var outline: Label = %Outline



#region Lifecycle Functions
## Initializes the node, connects signals, and triggers initial label setup
func _ready() -> void:
	if Engine.is_editor_hint():
		if not item_rect_changed.is_connected(_on_rect_changed):
			item_rect_changed.connect(_on_rect_changed)
	_set_label_gradient(text_gradient)
	_fix_label(3)
	_start()



## Intermediary function to handle rect changes securely without breaking connections
func _on_rect_changed() -> void:
	_update_labels()
	button_name.adjust_text_fit()



## Keeps the main label firmly anchored to the top-left corner
func _process(_delta: float) -> void:
	if button_name and button_name.position != Vector2.ZERO:
		button_name.position = Vector2.ZERO
#endregion



#region Label Management
## Duplicates materials and settings to ensure unique instances for this node
func _start() -> void:
	button_name.material = button_name.material.duplicate()
	outline.label_settings = outline.label_settings.duplicate_deep()
	outline.set_anchors_preset(PRESET_FULL_RECT)
	_fix_label(3)



## Forces a complete recalculation of the label sizes and triggers text adjustment
func _fix_label(repeats: int = 0) -> void:
	if not is_inside_tree(): return
	
	if Engine.is_editor_hint():
		await RenderingServer.frame_post_draw

	_update_labels()
	await RenderingServer.frame_post_draw
	button_name.adjust_text_fit()
	
	if repeats > 0:
		await RenderingServer.frame_post_draw
		if is_inside_tree():
			_fix_label(repeats - 1)
	
	_update_size()



## Updates the text, alignment, and sizing properties of both labels to match settings
func _update_labels() -> void:
	if is_node_ready():
		if button_name.min_font_size != min_font_size:
			button_name.min_font_size = min_font_size
		if button_name.max_font_size != max_font_size:
			button_name.max_font_size = max_font_size
		if button_name.force_text_size != force_text_size:
			button_name.force_text_size = force_text_size
		if button_name.horizontal_alignment != horizontal_align:
			button_name.horizontal_alignment = horizontal_align
		if button_name.vertical_alignment != vertical_align:
			button_name.vertical_alignment = vertical_align
			
		if button_name.text != label_text:
			button_name.text = label_text
			
		button_name.get_material().set_shader_parameter("size", size)
		
		if outline.horizontal_alignment != horizontal_align:
			outline.horizontal_alignment = horizontal_align
		if outline.vertical_alignment != vertical_align:
			outline.vertical_alignment = vertical_align
			
		if outline.text != label_text:
			outline.text = label_text



## Adjusts the control's minimum size to match the calculated requirements of the child label
func _update_size() -> void:
	if is_node_ready():
		var s = button_name.get_minimum_size() if not button_name.text.is_empty() else Vector2(-1, -1)
		if custom_minimum_size != s:
			custom_minimum_size = s
#endregion



#region Setters and Signals
## Setter for the label text that correctly triggers recalculations
func _set_label_text(value: String) -> void:
	label_text = value
	if Engine.is_editor_hint():
		_fix_label(3)
	else:
		_update_labels()



## Setter for the text gradient parameter passed to the shader
func _set_label_gradient(value: GradientTexture2D) -> void:
	text_gradient = value
	if is_node_ready():
		button_name.get_material().set_shader_parameter("gradient_texture", value)



## Setter for the horizontal alignment property
func _set_horizontal_align(value: HorizontalAlignment) -> void:
	horizontal_align = value
	_update_labels()



## Setter for the vertical alignment property
func _set_vertical_align(value: VerticalAlignment) -> void:
	vertical_align = value
	_update_labels()



## Responds to font size changes from the child label and synchronizes the outline
func _on_button_name_font_size_changed(new_size: int) -> void:
	if is_node_ready():
		var current_outline_size = outline.get("theme_override_font_sizes/font_size")
		if current_outline_size != new_size:
			outline.set("theme_override_font_sizes/font_size", new_size)
			
		if outline.label_settings and outline.label_settings.font_size != new_size:
			outline.label_settings.font_size = new_size
			
		if outline.pivot_offset != button_name.pivot_offset:
			outline.pivot_offset = button_name.pivot_offset
			
		call_deferred("_update_size")
#endregion
