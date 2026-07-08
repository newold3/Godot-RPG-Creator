@tool
extends Label

## Maximum font size allowed for the label.
@export var max_font_size: int = 100

## Minimum font size allowed for the label.
@export var min_font_size: int = 1

## If true, scales the node to fit the parent when the minimum font size still exceeds bounds.
@export var allow_scaling: bool = false

@export var auto_align_center: bool = true

var _parent: Control
var _last_text: String = ""
var _last_parent_size: Vector2 = Vector2.ZERO


#region Lifecycle Methods
## Initializes the label settings and applies the initial autosize.
func _ready() -> void:
	_parent = get_parent() as Control
	_setup_label_settings()
	_update_font_size.call_deferred()


## Checks for changes in text or parent size every frame to recalculate the font size if needed.
func _process(_delta: float) -> void:
	if not _parent:
		return
		
	if text != _last_text or _parent.size != _last_parent_size:
		_last_text = text
		_last_parent_size = _parent.size
		_update_font_size()
#endregion


#region Autosize Logic
## Ensures the label has a unique LabelSettings instance if it exists.
func _setup_label_settings() -> void:
	if label_settings:
		label_settings = label_settings.duplicate()


## Calculates the maximum font size that fits the text inside the parent container bounds.
func _update_font_size() -> void:
	if not _parent:
		return
	
	custom_minimum_size = Vector2.ZERO
		
	var parent_size: Vector2 = _parent.size
	
	if parent_size.x <= 0 or parent_size.y <= 0 or text.is_empty():
		return
		
	var current_font: Font = label_settings.font if label_settings and label_settings.font else get_theme_font("font")
	var low: int = min_font_size
	var high: int = max_font_size
	var best: int = low
	
	var current_text: String = tr(text)
	
	while low <= high:
		var mid: int = int((low + high) / 2.0)
		var text_size: Vector2 = current_font.get_multiline_string_size(current_text, horizontal_alignment, parent_size.x, mid)
		
		if text_size.x <= parent_size.x and text_size.y <= parent_size.y:
			best = mid
			low = mid + 1
		else:
			high = mid - 1
			
	if label_settings:
		label_settings.font_size = best
	else:
		add_theme_font_size_override("font_size", best)
		
	scale = Vector2.ONE
	
	_resize_and_repos.call_deferred()


## Resizes the label to match the final text size and correctly centers it using anchors.
func _resize_and_repos() -> void:
	size = Vector2.ZERO
	pivot_offset = size / 2.0
	
	if allow_scaling and _parent:
		var current_text = tr(text)
		var current_font: Font = label_settings.font if label_settings and label_settings.font else get_theme_font("font")
		var current_font_size: int
		if label_settings:
			current_font_size = label_settings.font_size
		else:
			current_font_size = get_theme_font_size("font_size")
		
		
		var final_text_size: Vector2 = current_font.get_multiline_string_size(current_text, horizontal_alignment, _parent.size.x, current_font_size)
		var scale_x: float = 1.0
		var scale_y: float = 1.0
		
		if size.x > _parent.size.x:
			scale_x = _parent.size.x / final_text_size.x
			
		if final_text_size.y > _parent.size.y:
			scale_y = _parent.size.y / final_text_size.y
			
		scale = Vector2(scale_x, scale_y)
	
	if not _parent is Container and auto_align_center:
		set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
#endregion
