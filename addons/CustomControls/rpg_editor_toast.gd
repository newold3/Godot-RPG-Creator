@tool
class_name RPGEditorToast
extends Window

## Floating notification system for the editor.
## Uses a borderless Window to guarantee it renders above all other dialogs.


## Array of active toasts.
static var active_toasts: Array = []

var _panel: PanelContainer
var _label: Label
var _tween: Tween
var _target_y: int


## Shows a floating notification in the bottom-right corner of the active editor window.
## @param message String - The text to display.
static func show_message(message: String) -> void:
	if not Engine.is_editor_hint():
		return
	
	for i in range(active_toasts.size() - 1, -1, -1):
		if not is_instance_valid(active_toasts[i]) or active_toasts[i].is_queued_for_deletion():
			active_toasts.remove_at(i)
	
	var toast = RPGEditorToast.new()
	var base_control = EditorInterface.get_base_control()
	base_control.get_tree().root.add_child(toast)
	
	toast.setup(message)
	
	var offset = int(toast.size.y) + 10 
	for t in active_toasts:
		if is_instance_valid(t):
			t.shift_up(offset)
	
	active_toasts.append(toast)
	toast.animate_in()


func _init() -> void:
	borderless = true
	transparent = true
	transparent_bg = true
	unfocusable = true
	always_on_top = true
	wrap_controls = true
	mouse_passthrough = true
	
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.16, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.6, 1.0, 1.0) 
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.WHITE)
	_panel.add_child(_label)


## Configures the initial state and position of the notification.
## @param message String - The text to display on the label.
func setup(message: String) -> void:
	_label.text = message
	
	_panel.reset_size()
	size = _panel.size
	
	var editor_window = EditorInterface.get_base_control().get_window()
	var screen_pos = editor_window.position
	var screen_size = editor_window.size
	
	var start_x = screen_pos.x + screen_size.x + 20
	var start_y = screen_pos.y + screen_size.y - size.y - 30
	
	position = Vector2i(start_x, start_y)
	_target_y = start_y
	
	_panel.modulate.a = 0.0


## Starts the sequence: slide in, fade in, wait, float up, and fade out.
func animate_in() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true)
	
	var editor_window = EditorInterface.get_base_control().get_window()
	var target_x = editor_window.position.x + editor_window.size.x - size.x - 30
	
	_tween.tween_property(self, "position:x", int(target_x), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	_tween.chain().tween_interval(3.0)
	
	_tween.chain().tween_property(self, "position:y", _target_y - 40, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	_tween.chain().tween_callback(queue_free)


## Moves the notification up to make room for a new one.
## @param amount int - The vertical distance to shift.
func shift_up(amount: int) -> void:
	_target_y -= amount
	var current_tween = create_tween()
	current_tween.tween_property(self, "position:y", _target_y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
