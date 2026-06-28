@tool
extends Label

## Maximum font size allowed for the label.
@export var max_font_size: int = 100

## Minimum font size allowed for the label.
@export var min_font_size: int = 1

var _parent: Control
var _last_text: String = ""
var _last_parent_size: Vector2 = Vector2.ZERO


#region Lifecycle Methods
## Initializes the label settings and applies the initial autosize.
func _ready() -> void:
	_parent = get_parent() as Control
	clip_text = true # Prevent the label from expanding its parent container
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
		
	var parent_size: Vector2 = _parent.size
	if parent_size.x <= 0 or parent_size.y <= 0 or text.is_empty():
		return
		
	var current_font: Font = label_settings.font if label_settings and label_settings.font else get_theme_font("font")
	var low: int = min_font_size
	var high: int = max_font_size
	var best: int = low
	
	while low <= high:
		var mid: int = int((low + high) / 2.0)
		var text_size: Vector2 = current_font.get_string_size(text, horizontal_alignment, -1, mid)
		if text_size.x <= parent_size.x and text_size.y <= parent_size.y:
			best = mid
			low = mid + 1
		else:
			high = mid - 1
			
	if label_settings:
		label_settings.font_size = best
	else:
		add_theme_font_size_override("font_size", best)
	
	set_deferred("size", parent_size)
	position = Vector2.ZERO
#endregion
