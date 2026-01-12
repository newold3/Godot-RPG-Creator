@tool
class_name InputTextBase
extends RequestInputFromUser

## Color for the Shift Lock active state
const ACTIVE_SHIFT_COLOR: Color = Color("ffa900")
## Color for the Shift Lock inactive state
const INACTIVE_SHIFT_COLOR: Color = Color.GRAY

var is_shift_pressed: bool = false
var _last_state_was_upper: bool = false

var _caps_orig_font_color: Color
var _caps_orig_outline_color: Color
var _caps_orig_stacked_colors: Array[Color] = []
var _caps_settings_captured: bool = false


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		ControllerManager.caps_lock_changed.connect(_update_caps_lock_label)
		_update_keyboard_visuals()


func get_class() -> String:
	return "SelectTextsScene"


func set_data(config: Dictionary) -> void:
	super(config)
	_update_keyboard_visuals()


func _process(delta: float) -> void:
	if not started: return
	
	var current_shift = Input.is_key_pressed(KEY_SHIFT)
	var current_upper_state = _should_be_upper()
	
	if current_shift != is_shift_pressed or current_upper_state != _last_state_was_upper:
		is_shift_pressed = current_shift
		_update_keyboard_visuals()
	
	super(delta)


## Overriding button press logic
func _on_button_pressed(button: BaseButton) -> void:
	if button == bloq_shift:
		var new_state_is_upper: bool = !ControllerManager.is_caps_lock_on
		var force_val: int = 2 if new_state_is_upper else 1
		_update_keyboard_visuals(force_val)
		play_fx(select_fx)
		_animate_button_click(button)
		ControllerManager.toggle_os_caps_lock.call_deferred()
		return

	super(button)


## The "Source of Truth" combines Global Caps Lock and Local Shift
func _should_be_upper() -> bool:
	if Engine.is_editor_hint(): return true
	return ControllerManager.is_caps_lock_on != is_shift_pressed


func _update_caps_lock_label(value: bool) -> void:
	## Updates the visual state of the Caps Lock label, managing its outline stack.
	if not is_instance_valid(bloq_shift):
		return

	var label = _find_label(bloq_shift)
	if not label:
		return

	if "label_settings" in label and label.label_settings:
		_manage_caps_label_settings(label, value)
	else:
		label.modulate = ACTIVE_SHIFT_COLOR if value else Color.WHITE


func _manage_caps_label_settings(label: Label, is_active: bool) -> void:
	## Captures and applies high-contrast gray or active colors to the shift label.
	var settings = label.label_settings
	
	if not _caps_settings_captured:
		label.label_settings = settings.duplicate()
		settings = label.label_settings
		
		_caps_orig_font_color = settings.font_color
		_caps_orig_outline_color = settings.outline_color
		
		_caps_orig_stacked_colors.clear()
		for i in range(settings.stacked_outline_count):
			_caps_orig_stacked_colors.append(settings.get_stacked_outline_color(i))
			
		_caps_settings_captured = true

	if is_active:
		settings.font_color = ACTIVE_SHIFT_COLOR
		settings.outline_color = _caps_orig_outline_color
		
		for i in range(settings.stacked_outline_count):
			settings.set_stacked_outline_color(i, _caps_orig_stacked_colors[i])
	else:
		var text_gray = Color(0.8, 0.8, 0.8, 1.0)
		var outline_gray = Color(0.2, 0.2, 0.2, 0.6)
		
		settings.font_color = text_gray
		settings.outline_color = outline_gray
		
		for i in range(settings.stacked_outline_count):
			settings.set_stacked_outline_color(i, outline_gray)


func _update_keyboard_visuals(force_state: int = 0) -> void:
	var should_be_upper: bool
	
	match force_state:
		1: should_be_upper = false
		2: should_be_upper = true
		_: should_be_upper = _should_be_upper()
		
	_last_state_was_upper = should_be_upper
	
	_update_caps_lock_label(ControllerManager.is_caps_lock_on)

	
	for button in buttons:
		if !is_instance_valid(button): continue
		if button == back_button or button == ok_button or button == space_button or button == bloq_shift:
			continue
			
		var label = _find_label(button)
		if label and button.name.length() == 1:
			label.text = button.name.to_upper() if should_be_upper else button.name.to_lower()
	
	_update_label()


func _start_animation() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.2, 1.5)
	modulate.a = 0.0
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", position.y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).from(position.y + 40)
	t.tween_property(self, "modulate:a", 1.0, 0.4)
	await t.finished


func _modulate_opacity(color: Color) -> void:
	propagate_call("set", ["modulate", color])


func _end_animation() -> void:
	GameManager.set_cursor_manipulator(GameManager.MANIPULATOR_MODES.NONE)
	GameManager.force_hide_cursor()
	pivot_offset = size * 0.5
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.4, 0.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_method(_modulate_opacity, Color.WHITE, Color.TRANSPARENT, 0.6)
	t.tween_property(self, "position:y", position.y - 20, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


func get_text() -> Variant:
	return "".join(buffer)
