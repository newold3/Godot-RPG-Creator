@tool
class_name ToastManager
extends Node

## Enumerator defining the screen position for the toast
enum ToastPos {
	TOP_LEFT,
	TOP_CENTER,
	TOP_RIGHT,
	MIDDLE_LEFT,
	MIDDLE_CENTER,
	MIDDLE_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_CENTER,
	BOTTOM_RIGHT
}

var active_toasts: Array[PanelContainer] = []
var toast_canvas: CanvasLayer



## Initializes the dedicated canvas layer for toasts and attaches it to the scene root
func _ready() -> void:
	toast_canvas = CanvasLayer.new()
	toast_canvas.layer = 128
	get_tree().root.call_deferred("add_child", toast_canvas)



## Shows a floating notification dynamically generated in a specific screen position
func show_message(message: String, pos: ToastPos = ToastPos.BOTTOM_RIGHT) -> void:
	for i in range(active_toasts.size() - 1, -1, -1):
		if not is_instance_valid(active_toasts[i]) or active_toasts[i].is_queued_for_deletion():
			active_toasts.remove_at(i)
	var toast = PanelContainer.new()
	_setup_toast_ui(toast, message, pos)
	if is_instance_valid(toast_canvas):
		toast_canvas.add_child(toast)
	var shift_dir = -1.0
	if pos == ToastPos.TOP_LEFT or pos == ToastPos.TOP_CENTER or pos == ToastPos.TOP_RIGHT:
		shift_dir = 1.0
	var offset = (float(toast.size.y) + 10.0) * shift_dir
	for t in active_toasts:
		if is_instance_valid(t) and t.get_meta("pos_id", ToastPos.BOTTOM_RIGHT) == pos:
			_shift_toast_up(t, offset)
	active_toasts.append(toast)
	_animate_toast_in(toast)



## Configures the internal nodes, base styling, and calculates starting coordinates
func _setup_toast_ui(toast: PanelContainer, message: String, pos: ToastPos) -> void:
	toast.top_level = true
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_meta("pos_id", pos)
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
	toast.add_theme_stylebox_override("panel", style)
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.text = message
	toast.add_child(label)
	toast.reset_size()
	toast.size = toast.get_minimum_size()
	var width = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height = ProjectSettings.get_setting("display/window/size/viewport_height")
	var screen_size = Vector2(width, height)
	var start_x = 0.0
	var start_y = 0.0
	var target_x = 0.0
	var target_y = 0.0
	match pos:
		ToastPos.TOP_LEFT:
			target_x = 30.0
			target_y = 30.0
			start_x = -toast.size.x - 20.0
			start_y = target_y
		ToastPos.TOP_CENTER:
			target_x = (screen_size.x - toast.size.x) / 2.0
			target_y = 30.0
			start_x = target_x
			start_y = -toast.size.y - 20.0
		ToastPos.TOP_RIGHT:
			target_x = screen_size.x - toast.size.x - 30.0
			target_y = 30.0
			start_x = screen_size.x + 20.0
			start_y = target_y
		ToastPos.MIDDLE_LEFT:
			target_x = 30.0
			target_y = (screen_size.y - toast.size.y) / 2.0
			start_x = -toast.size.x - 20.0
			start_y = target_y
		ToastPos.MIDDLE_CENTER:
			target_x = (screen_size.x - toast.size.x) / 2.0
			target_y = (screen_size.y - toast.size.y) / 2.0
			start_x = target_x
			start_y = target_y + 20.0
		ToastPos.MIDDLE_RIGHT:
			target_x = screen_size.x - toast.size.x - 30.0
			target_y = (screen_size.y - toast.size.y) / 2.0
			start_x = screen_size.x + 20.0
			start_y = target_y
		ToastPos.BOTTOM_LEFT:
			target_x = 30.0
			target_y = screen_size.y - toast.size.y - 30.0
			start_x = -toast.size.x - 20.0
			start_y = target_y
		ToastPos.BOTTOM_CENTER:
			target_x = (screen_size.x - toast.size.x) / 2.0
			target_y = screen_size.y - toast.size.y - 30.0
			start_x = target_x
			start_y = screen_size.y + 20.0
		ToastPos.BOTTOM_RIGHT, _:
			target_x = screen_size.x - toast.size.x - 30.0
			target_y = screen_size.y - toast.size.y - 30.0
			start_x = screen_size.x + 20.0
			start_y = target_y
	toast.position = Vector2(start_x, start_y)
	toast.modulate.a = 0.0
	toast.set_meta("target_x", target_x)
	toast.set_meta("target_y", target_y)



## Starts the sequence: slide in, fade in, wait, float up, and fade out
func _animate_toast_in(toast: PanelContainer) -> void:
	var tween = toast.create_tween().set_parallel(true)
	var target_x = toast.get_meta("target_x")
	var target_y = toast.get_meta("target_y")
	tween.tween_property(toast, "position", Vector2(target_x, target_y), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(toast, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_interval(3.0)
	tween.chain().tween_property(toast, "position:y", target_y - 40.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(toast, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(toast.queue_free)



## Moves the notification up or down to make room for a new one based on its start position
func _shift_toast_up(toast: PanelContainer, amount: float) -> void:
	var new_target = toast.get_meta("target_y") + amount
	toast.set_meta("target_y", new_target)
	if toast.has_meta("shift_tween"):
		var old_tween = toast.get_meta("shift_tween")
		if is_instance_valid(old_tween):
			old_tween.kill()
	var current_tween = toast.create_tween()
	toast.set_meta("shift_tween", current_tween)
	current_tween.tween_property(toast, "position:y", new_target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
