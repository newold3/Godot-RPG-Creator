@tool
extends Window


## Slider for Hue shift. Expected range: -180.0 to 180.0.
@export var hue_slider: Slider
@export var hue_spinbox: SpinBox
@export var result_hue_strip: TextureRect


## Slider for Saturation shift. Expected range: -100.0 to 100.0.
@export var saturation_slider: Slider
@export var saturation_spinbox: SpinBox


## Slider for Lightness/Value shift. Expected range: -100.0 to 100.0.
@export var brightness_slider: Slider
@export var brightness_spinbox: SpinBox


## Dropdown to select which color range to edit.
@export var channel_option: OptionButton


## Checkbox to enable "Colorize" mode (Monochromatic tint).
@export var colorize_checkbox: CheckBox


## Holds the immutable source colors.
var _original_colors: Array[Color] = []


## Holds the processed colors ready for display.
var _display_colors: Array[Color] = []


var busy: bool = false


## Stores HSB adjustments for each channel (Normal Mode).
## Keys: 0=Master, 1=Reds, etc.
var _channel_adjustments: Dictionary = {}
var _current_channel_index: int = 0


## Stores logic for Colorize Mode.
var _colorize_enabled: bool = false


signal colors_changed(colors: Array[Color])


func _ready() -> void:
	close_requested.connect(_on_cancel_button_pressed)
	
	if hue_slider:
		hue_slider.value_changed.connect(_on_parameters_changed)
	if saturation_slider:
		saturation_slider.value_changed.connect(_on_parameters_changed)
	if brightness_slider:
		brightness_slider.value_changed.connect(_on_parameters_changed)
		
	if hue_spinbox:
		hue_spinbox.value_changed.connect(_on_spinbox_value_changed)
	if saturation_spinbox:
		saturation_spinbox.value_changed.connect(_on_spinbox_value_changed)
	if brightness_spinbox:
		brightness_spinbox.value_changed.connect(_on_spinbox_value_changed)
		
	if channel_option:
		_setup_channels()
		channel_option.item_selected.connect(_on_channel_selected)
	
	if colorize_checkbox:
		colorize_checkbox.toggled.connect(_on_colorize_toggled)
		
	_reset_adjustments()


func _setup_channels() -> void:
	channel_option.clear()
	channel_option.add_item("Master")   # 0
	channel_option.add_item("Reds")     # 1
	channel_option.add_item("Yellows")  # 2
	channel_option.add_item("Greens")   # 3
	channel_option.add_item("Cyans")    # 4
	channel_option.add_item("Blues")    # 5
	channel_option.add_item("Magentas") # 6
	channel_option.select(0)


func _reset_adjustments() -> void:
	for i in range(7):
		_channel_adjustments[i] = { "h": 0.0, "s": 0.0, "b": 0.0 }


func set_colors(colors: Array[Color]) -> void:
	_original_colors = colors.duplicate()
	_update_colors()


func get_modified_colors() -> Array[Color]:
	return _display_colors


func _on_colorize_toggled(toggled: bool) -> void:
	_colorize_enabled = toggled
	channel_option.disabled = toggled
	
	_set_sliders_block_signals(true)
	
	if toggled:
		# Set defaults for Colorize mode (Red, Saturation 50%, Normal Brightness)
		# Mapping: Hue -180 (Red), Sat 0 (50% sat), Bright 0
		hue_slider.value = -180 
		saturation_slider.value = 0 # 0 maps to 50% saturation in our remapping logic below
		brightness_slider.value = 0
	else:
		# Restore Master channel values
		_current_channel_index = 0
		channel_option.select(0)
		var data = _channel_adjustments[0]
		hue_slider.value = data.h
		saturation_slider.value = data.s
		brightness_slider.value = data.b

	_sync_spinboxes_to_sliders()
	_set_sliders_block_signals(false)
	
	_update_colors()


func _on_channel_selected(index: int) -> void:
	# Save previous
	_channel_adjustments[_current_channel_index].h = hue_slider.value
	_channel_adjustments[_current_channel_index].s = saturation_slider.value
	_channel_adjustments[_current_channel_index].b = brightness_slider.value
	
	_current_channel_index = index
	var data = _channel_adjustments[index]
	
	_set_sliders_block_signals(true)
	hue_slider.value = data.h
	saturation_slider.value = data.s
	brightness_slider.value = data.b
	_sync_spinboxes_to_sliders()
	_set_sliders_block_signals(false)
	
	_update_colors()


func _set_sliders_block_signals(blocked: bool) -> void:
	if hue_slider: hue_slider.set_block_signals(blocked)
	if saturation_slider: saturation_slider.set_block_signals(blocked)
	if brightness_slider: brightness_slider.set_block_signals(blocked)
	if hue_spinbox: hue_spinbox.set_block_signals(blocked)
	if saturation_spinbox: saturation_spinbox.set_block_signals(blocked)
	if brightness_spinbox: brightness_spinbox.set_block_signals(blocked)


func _sync_spinboxes_to_sliders() -> void:
	if hue_spinbox: hue_spinbox.set_value_no_signal(hue_slider.value)
	if saturation_spinbox: saturation_spinbox.set_value_no_signal(saturation_slider.value)
	if brightness_spinbox: brightness_spinbox.set_value_no_signal(brightness_slider.value)


func _on_parameters_changed(_value: float) -> void:
	if busy: return
	busy = true
	_sync_spinboxes_to_sliders()
	
	if not _colorize_enabled:
		_channel_adjustments[_current_channel_index].h = hue_slider.value
		_channel_adjustments[_current_channel_index].s = saturation_slider.value
		_channel_adjustments[_current_channel_index].b = brightness_slider.value
	
	busy = false
	_update_colors()


func _on_spinbox_value_changed(_value: float) -> void:
	if busy: return
	busy = true
	
	if hue_slider: hue_slider.set_value_no_signal(hue_spinbox.value)
	if saturation_slider: saturation_slider.set_value_no_signal(saturation_spinbox.value)
	if brightness_slider: brightness_slider.set_value_no_signal(brightness_spinbox.value)
	
	if not _colorize_enabled:
		_channel_adjustments[_current_channel_index].h = hue_spinbox.value
		_channel_adjustments[_current_channel_index].s = saturation_spinbox.value
		_channel_adjustments[_current_channel_index].b = brightness_spinbox.value
	
	busy = false
	_update_colors()


func _update_shader_visuals(colorize_h: float = 0.0, colorize_s: float = 0.0) -> void:
	if !result_hue_strip: return
	var mat = result_hue_strip.material as ShaderMaterial
	if !mat: return

	mat.set_shader_parameter("colorize_mode", _colorize_enabled)

	if _colorize_enabled:
		mat.set_shader_parameter("target_hue", colorize_h)
		mat.set_shader_parameter("target_sat", colorize_s)
	else:
		var offsets: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for i in range(7):
			offsets[i] = _channel_adjustments[i].h / 360.0
		mat.set_shader_parameter("hue_offsets", offsets)


func _update_colors() -> void:
	_display_colors.clear()
	
	if _colorize_enabled:
		# --- COLORIZE MODE LOGIC ---
		# Map sliders to absolute values.
		# Hue: Slider (-180 to 180) -> Normalized (0.0 to 1.0)
		var target_h = (hue_slider.value + 180.0) / 360.0
		
		# Saturation: Slider (-100 to 100) -> Normalized (0.0 to 1.0)
		# -100 = 0% sat (Gray), 0 = 50% sat, 100 = 100% sat (Vivid)
		var target_s = (saturation_slider.value + 100.0) / 200.0
		
		# Brightness: Slider (-100 to 100) -> Factor
		var b_shift = brightness_slider.value / 100.0
		
		_update_shader_visuals(target_h, target_s)
		
		for color: Color in _original_colors:
			# Get luminosity (V or luminance)
			var v = color.v # Or use color.get_luminance() for perception
			
			# Apply brightness shift
			v = clampf(v + b_shift, 0.0, 1.0)
			
			# Create new color with fixed Hue/Sat and original Value
			_display_colors.append(Color.from_hsv(target_h, target_s, v, color.a))
			
	else:
		# --- NORMAL MODE LOGIC ---
		_update_shader_visuals()
		var m = _channel_adjustments[0]
		
		for color: Color in _original_colors:
			var total_h = m.h
			var total_s = m.s
			var total_b = m.b
			
			var ch_id = _get_color_channel_id(color.h)
			var ch = _channel_adjustments[ch_id]
			
			if ch.h != 0.0 or ch.s != 0.0 or ch.b != 0.0:
				total_h += ch.h
				total_s += ch.s
				total_b += ch.b
			
			var new_h = fposmod(color.h + (total_h / 360.0), 1.0)
			var new_s = clampf(color.s + (total_s / 100.0), 0.0, 1.0)
			var new_v = clampf(color.v + (total_b / 100.0), 0.0, 1.0)
			
			_display_colors.append(Color.from_hsv(new_h, new_s, new_v, color.a))
	
	colors_changed.emit(_display_colors)


func _get_color_channel_id(hue: float) -> int:
	var h_deg = hue * 360.0
	if h_deg >= 325.0 or h_deg < 35.0: return 1
	if h_deg >= 35.0 and h_deg < 95.0: return 2
	if h_deg >= 95.0 and h_deg < 155.0: return 3
	if h_deg >= 155.0 and h_deg < 215.0: return 4
	if h_deg >= 215.0 and h_deg < 275.0: return 5
	if h_deg >= 275.0 and h_deg < 325.0: return 6
	return 1


func _on_ok_button_pressed() -> void:
	colors_changed.emit(_display_colors)
	queue_free()


func _on_cancel_button_pressed() -> void:
	colors_changed.emit(_original_colors)
	queue_free()
