@tool
class_name TimerScene
extends Control

enum SCREEN_POSITION {TOP_LEFT, TOP_CENTER, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT, CUSTOM}
enum TITLE_HORIZONTAL_ALIGN {SAME_AS_TIMER, LEFT, CENTER, RIGHT}

@export_group("Basic Configuration")
## Name displayed above the timer
@export var timer_name: String = "": set = _set_timer_name
## Choose horizontal alignment for the title
@export var timer_name_align: TITLE_HORIZONTAL_ALIGN = TITLE_HORIZONTAL_ALIGN.SAME_AS_TIMER: set = _set_title_alignment
## Color tint applied to the timer name text
@export var timer_name_modulate: Color = Color.WHITE: set = _set_timer_title_color
## Strength of the color modulation mix (0.0 = no effect, 1.0 = full effect)
@export_range(0.0, 1.0, 0.01) var timer_name_modulate_mix_strength: float = 0.5: set = _set_timer_name_modulate_mix_strength
## play or stop the animation in the editor
@export var play_timer_in_editor: bool = true: set = _set_play_animation_in_the_editor
## Play or stop sounds in the editor
@export var play_sounds_in_editor: bool = true: set = _set_play_sounds_in_the_editor


@export_group("Position")
## Position of the timer on screen (predefined locations or custom)
@export var screen_position: SCREEN_POSITION = SCREEN_POSITION.TOP_CENTER: set = _set_screen_position
## Custom position when screen_position is set to CUSTOM
@export var custom_position: Vector2 = Vector2.ZERO: set = _set_custom_position
## Horizontal margin offset from the screen edge
@export var margin_horizontal: float = 0.0: set = _set_margin_horizontal
## Vertical margin offset from the screen edge
@export var margin_vertical: float = 0.0: set = _set_margin_vertical


@export_group("Background")
## Whether to show the background texture behind the timer
@export var show_background: bool = true: set = _set_show_background
## Texture used as background for the timer display
@export var background_texture: Texture2D: set = _set_background_texture
## Width of the background in pixels (Option only available when the timer position is "CUSTOM".)
@export_range(0, 5000) var background_width: int = 0: set = _set_background_width
## Height of the background in pixels (Option only available when the timer position is "CUSTOM".)
@export_range(0, 320) var background_height: int = 0: set = _set_background_height


@export_group("Text Style")
## Font used for the timer text
@export var text_font: Font: set = _set_text_font
## Size of the title text in pixels
@export var timer_title_text_size: int = 24: set = _set_timer_title_text_size
## Size of the timer text in pixels
@export var timer_text_size: int = 24: set = _set_timer_text_size
## Gradient texture applied to the timer text
@export var text_gradient: Texture2D: set = _set_text_gradient
## Size of the text outline in pixels (0 = no outline)
@export_range(0, 32, 1) var text_outline_size: int = 0: set = _set_text_outline_size
## Color of the text outline
@export var text_outline_color: Color = Color.BLACK: set = _set_text_outline_color


@export_group("Timer Format")
## Format for the text: HH ->  hours, MM -> minutes, SS -> seconds, MS -> milliseconds, TS -> Total time in seconds
@export var timer_format: String = "HH : MM : SS": set = _set_timer_format


@export_group("Animations And Sounds")
## Sound played when the timer starts
@export var start_fx: AudioStream: set = _set_start_fx
## Sound played when the timer runs out
@export var timeout_fx: AudioStream: set = _set_timeout_fx
## Sound played when the timer is ending
@export var warning_fx: AudioStream: set = _set_warning_fx
## Sound played every second while the timer is active (1 tick by second)
@export var tick_fx: AudioStream: set = _set_tick_fx
## Start of warning (in seconds)
@export var warning_start_time: int = 10: set = _set_warning_start_time
## Curve representing the interval and intensity of the volume between warning sounds
@export var warning_curve: Curve: set = _set_warning_curve
## Enables the timer to flash after a specified time.
@export var enable_blink_animation: bool = true: set = _set_enable_blink_animation
## Specifies the second at which the flashing will begin.
@export var blink_animation_start_time: int = 10: set = _set_blink_animation_start_time
## Curve representing the blink rate
@export var blink_speed_curve: Curve: set = _set_blink_speed_curve


@onready var timer_title: Label = %TimerTitle
@onready var timer_title_back: Label = %TimerTitleBack
@onready var background: TextureRect = $Background
@onready var timer_label_back: Label = %TimerLabelBack
@onready var timer_label: Label = %TimerLabel

# New nodes for audio and animations
@onready var audio_player: AudioStreamPlayer
@onready var warning_audio_player: AudioStreamPlayer
@onready var tick_audio_player: AudioStreamPlayer
@onready var blink_timer: Timer
@onready var warning_timer: Timer
@onready var tick_timer: Timer

var id: int
var max_time: float # time in seconds
var current_time: float # time in seconds
var is_running: bool = false
var is_paused: bool = false
var warning_triggered: bool = false
var blink_animation_triggered: bool = false
var is_blinking: bool = false
var warning_sound_playing: bool = false

var _in_editor_timer: int = 30

var font_base = "res://Assets/Fonts/Cinzel-Bold.ttf"
var text_gradient_base = "res://Scenes/TimerScenes/Resources/default_timer_text_gradient.tres"
var default_background = "res://Scenes/TimerScenes/Resources/default_background.tres"
var default_curve = "res://Scenes/TimerScenes/Resources/default_timer_curve.tres"

var busy: bool = false

func _ready() -> void:
	# Create audio and timer nodes dynamically
	_setup_audio_and_timers()
	
	timer_label.item_rect_changed.connect(_update_text_shader_size)
	timer_title.item_rect_changed.connect(_update_text_shader_size)
	
	if Engine.is_editor_hint() and play_timer_in_editor:
		start(_in_editor_timer)
	else:
		timer_label.text = "0"
		timer_label_back.text = "0"
		_update_position()

func _setup_audio_and_timers() -> void:
	# Create AudioStreamPlayer for main effects
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SE"
	add_child(audio_player)
	
	# Create AudioStreamPlayer for warning sounds
	warning_audio_player = AudioStreamPlayer.new()
	warning_audio_player.bus = "SE"
	add_child(warning_audio_player)
	
	# Create AudioStreamPlayer for clock ticks
	tick_audio_player = AudioStreamPlayer.new()
	tick_audio_player.bus = "SE"
	add_child(tick_audio_player)
	
	# Create Timer to control blinking
	blink_timer = Timer.new()
	add_child(blink_timer)
	blink_timer.timeout.connect(_on_blink_timer_timeout)
	
	# Create Timer to control repeated warnings
	warning_timer = Timer.new()
	add_child(warning_timer)
	warning_timer.timeout.connect(_on_warning_timer_timeout)
	
	# Create Timer to control repeated ticks
	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	add_child(tick_timer)
	tick_timer.timeout.connect(_on_tick_timer_timeout)

#region Setters
func _set_timer_name(value: String) -> void:
	timer_name = value
	if timer_title:
		timer_title.text = value
		timer_title_back.text = value
		_update_position()


func _set_title_alignment(alignment: TITLE_HORIZONTAL_ALIGN) -> void:
	timer_name_align = alignment
	
	if timer_title and timer_label:
		match alignment:
			TITLE_HORIZONTAL_ALIGN.SAME_AS_TIMER:
				timer_title.horizontal_alignment = timer_label.horizontal_alignment
				timer_title_back.horizontal_alignment = timer_label.horizontal_alignment
			TITLE_HORIZONTAL_ALIGN.LEFT:
				timer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				timer_title_back.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			TITLE_HORIZONTAL_ALIGN.CENTER:
				timer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				timer_title_back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			TITLE_HORIZONTAL_ALIGN.RIGHT:
				timer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				timer_title_back.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _set_timer_title_color(value: Color) -> void:
	timer_name_modulate = value
	if timer_title:
		timer_title.set("instance_shader_parameters/modulate", timer_name_modulate)

func _set_timer_name_modulate_mix_strength(value: float) -> void:
	timer_name_modulate_mix_strength = value
	if timer_title:
		timer_title.set("instance_shader_parameters/mix_amount", timer_name_modulate_mix_strength)

func _set_play_animation_in_the_editor(value: bool) -> void:
	play_timer_in_editor = value
	if Engine.is_editor_hint():
		if value and not is_running:
			start(_in_editor_timer)
		elif not value:
			stop()

func _set_play_sounds_in_the_editor(value: bool) -> void:
	play_sounds_in_editor = value

func _set_show_background(value: bool):
	show_background = value
	if background:
		background.self_modulate.a = 1.0 if value else 0.0

func _set_background_texture(value: Texture2D):
	background_texture = value
	if background and value:
		background.texture = value

func _set_background_height(value: int) -> void:
	background_height = value
	if background and screen_position == SCREEN_POSITION.CUSTOM:
		background.size.y = value
		_update_position()

func _set_background_width(value: int) -> void:
	background_width = value
	if background and screen_position == SCREEN_POSITION.CUSTOM:
		background.size.x = value
		_update_position()

func _set_text_font(value: Font):
	text_font = value
	if timer_label:
		timer_label.add_theme_font_override("font", value)
		timer_label_back.add_theme_font_override("font", value)
		timer_title.add_theme_font_override("font", value)
		timer_title_back.add_theme_font_override("font", value)
		_update_position()

func _set_timer_text_size(value: int) -> void:
	timer_text_size = value
	if timer_label:
		timer_label.size = Vector2.ZERO
		timer_label.add_theme_font_size_override("font_size", value)
		timer_label_back.add_theme_font_size_override("font_size", value)
		call_deferred("_update_position")

func _set_timer_title_text_size(value: int) -> void:
	timer_title_text_size = value
	if timer_title:
		timer_title.size = Vector2.ZERO
		timer_title.add_theme_font_size_override("font_size", value)
		timer_title_back.add_theme_font_size_override("font_size", value)
		call_deferred("_update_position")


func _set_text_gradient(value: Texture2D):
	text_gradient = value
	if timer_label and value:
		var mat = timer_label.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("gradient_texture", value)

func _update_text_shader_size() -> void:
	if busy: return
	
	if timer_label:
		var mat = timer_label.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("instance_shader_parameters/size", timer_label.size)
	
	busy = true
	_update_position()
	busy = false

func _set_text_outline_size(value: int):
	text_outline_size = value
	if timer_label_back:
		timer_label_back.add_theme_constant_override("outline_size", value)
		timer_title_back.add_theme_constant_override("outline_size", value)

func _set_text_outline_color(value: Color):
	text_outline_color = value
	if timer_label_back:
		timer_label_back.add_theme_color_override("font_outline_color", value)
		timer_label_back.set_meta("original_color", value)

func _set_timer_format(value: String):
	timer_format = value
	_update_timer_display()

func _set_screen_position(value: SCREEN_POSITION):
	screen_position = value
	
	if timer_label:
		var current_position = SCREEN_POSITION.keys()[screen_position].to_lower()
		var labels: Array
		if timer_name_align == TITLE_HORIZONTAL_ALIGN.SAME_AS_TIMER:
			labels = [timer_label, timer_label_back, timer_title, timer_title_back]
		else:
			labels = [timer_label, timer_label_back]
		var align = HORIZONTAL_ALIGNMENT_CENTER
		if "left" in current_position:
			align = HORIZONTAL_ALIGNMENT_LEFT
		elif "right" in current_position:
			align = HORIZONTAL_ALIGNMENT_RIGHT
		
		for label: Label in labels:
			label.horizontal_alignment = align
			
		_update_position()

func _set_custom_position(value: Vector2):
	custom_position = value
	if screen_position == SCREEN_POSITION.CUSTOM:
		_update_position()

func _set_margin_horizontal(value: float):
	margin_horizontal = value
	_update_position()

func _set_margin_vertical(value: float):
	margin_vertical = value
	_update_position()

# Setters for Animations And Sounds
func _set_start_fx(value: AudioStream) -> void:
	start_fx = value
	# No immediate update needed, used when timer starts

func _set_timeout_fx(value: AudioStream) -> void:
	timeout_fx = value
	# No immediate update needed, used when timer ends

func _set_warning_fx(value: AudioStream) -> void:
	warning_fx = value
	# If there is an active warning, update the stream
	if warning_sound_playing and warning_audio_player:
		warning_audio_player.stream = warning_fx

func _set_tick_fx(value: AudioStream) -> void:
	tick_fx = value
	if tick_audio_player:
		tick_audio_player.stream = tick_fx

func _set_warning_start_time(value: int) -> void:
	warning_start_time = value
	# If timer is running, check if warning needs to be activated/deactivated
	if is_running and not Engine.is_editor_hint():
		if current_time <= warning_start_time and not warning_triggered:
			_play_warning_feedback()
			warning_triggered = true
		elif current_time > warning_start_time and warning_triggered:
			_stop_warning_effects()
			warning_triggered = false

func _set_warning_curve(value: Curve) -> void:
	warning_curve = value
	# The curve will be applied in the next warning cycle

func _set_enable_blink_animation(value: bool) -> void:
	enable_blink_animation = value
	
	if not value:
		# Disable blinking immediately
		if blink_timer:
			blink_timer.stop()
		_restore_normal_appearance()
	elif is_running and current_time <= blink_animation_start_time and blink_animation_triggered:
		# Reactivate blinking if it should be active
		_start_blink_animation()

func _set_blink_animation_start_time(value: int) -> void:
	blink_animation_start_time = value
	# If timer is running, check if blinking needs to be activated/deactivated
	if is_running and enable_blink_animation and not Engine.is_editor_hint():
		if current_time <= blink_animation_start_time and not blink_animation_triggered:
			_start_blink_animation()
			blink_animation_triggered = true
		elif current_time > blink_animation_start_time and blink_animation_triggered:
			if blink_timer:
				blink_timer.stop()
			_restore_normal_appearance()
			blink_animation_triggered = false

func _set_blink_speed_curve(value: Curve) -> void:
	blink_speed_curve = value
	# The curve will be applied in the next blinking cycle

# Helper methods
func _update_all_properties():
	_set_show_background(show_background)
	_set_background_texture(background_texture)
	_set_text_font(text_font)
	_set_timer_text_size(timer_text_size)
	_set_timer_title_text_size(timer_title_text_size)
	_set_text_gradient(text_gradient)
	_set_text_outline_size(text_outline_size)
	_set_text_outline_color(text_outline_color)
	# Apply animation and sound properties
	_set_start_fx(start_fx)
	_set_timeout_fx(timeout_fx)
	_set_warning_fx(warning_fx)
	_set_warning_start_time(warning_start_time)
	_set_warning_curve(warning_curve)
	_set_enable_blink_animation(enable_blink_animation)
	_set_blink_animation_start_time(blink_animation_start_time)
	_set_blink_speed_curve(blink_speed_curve)
	_update_position()
	_update_timer_display()

func _update_position():
	if not is_inside_tree():
		return
	
	timer_title.size = Vector2.ZERO
	timer_label.size = Vector2.ZERO
	timer_title_back.size = Vector2.ZERO
	timer_label_back.size = Vector2.ZERO
		
	var viewport_size = size
	
	timer_title.size.x = max(timer_title.size.x, timer_label.size.x)
	timer_label.size.x = max(timer_title.size.x, timer_label.size.x)
	timer_title_back.size.x = timer_title.size.x
	timer_label_back.size.x = timer_label.size.x
	
	var maximun_height: int
	if not timer_title.text.is_empty():
		maximun_height = timer_title.size.y + timer_label.size.y + 5 + margin_vertical * 2
	else:
		maximun_height = timer_label.size.y + 5 + margin_vertical * 2
	
	if screen_position != SCREEN_POSITION.CUSTOM:
		background.size.y = maximun_height
		background.size.x = viewport_size.x
		background.position.x = 0
		background.position.y = 0 if screen_position < 3 else viewport_size.y - background.size.y
	else:
		background.size.y = max(background_height, maximun_height)
		background.size.x = max(background_width, timer_label.size.x) + margin_horizontal * 2 + 5
		background.position = custom_position
		
	# Calculate position
	var current_position = SCREEN_POSITION.keys()[screen_position].to_lower()
	var timer_title_size = timer_title.size if not timer_title.text.is_empty() else Vector2.ZERO
	
	if screen_position != SCREEN_POSITION.CUSTOM:
		var x = 0
		var y = margin_vertical
		if "left" in current_position:
			x = margin_horizontal
			timer_title.position = Vector2(x, y)
		elif "right" in current_position:
			x = viewport_size.x - margin_horizontal
			timer_title.position = Vector2(x, y) - Vector2(timer_title.size.x, 0)
		else:
			x = viewport_size.x * 0.5
			timer_title.position = Vector2(x, y) + Vector2(-timer_title.size.x * 0.5, 2.5)
	else:
		var x = margin_horizontal
		var y = margin_vertical
		if "left" in current_position:
			x = margin_horizontal
			timer_title.position = Vector2(x, y)
		elif "right" in current_position:
			x = background.size.x - margin_horizontal
			timer_title.position = Vector2(x, y) - Vector2(timer_title.size.x, 0)
		else:
			x = background.size.x * 0.5
			timer_title.position = Vector2(x, y) + Vector2(-timer_title.size.x * 0.5, 2.5)
		
	timer_label.position = timer_title.position + Vector2(0, timer_title_size.y + 2.5)
	timer_label_back.position = timer_label.position
	timer_title_back.position = timer_title.position


func _update_timer_display():
	if not timer_label or not timer_label_back:
		return
		
	var formatted_time: String
	var total_seconds = int(current_time)
	var milliseconds = int((current_time - total_seconds) * 100)
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = int(total_seconds % 60)
	var hours: int = (minutes / 60.0)
	minutes = minutes % 60
	
	formatted_time = timer_format
	formatted_time = formatted_time.replace("HH", str(hours))
	formatted_time = formatted_time.replace("MM", str(minutes))
	formatted_time = formatted_time.replace("SS", str(seconds))
	formatted_time = formatted_time.replace("MS", str(milliseconds))
	formatted_time = formatted_time.replace("TS", str(total_seconds))
	
	timer_label.text = formatted_time
	timer_label_back.text = formatted_time
#endregion

func _process(delta: float) -> void:
	if is_paused or not is_running:
		return
		
	current_time -= delta
	GameManager.update_timer_time(id, current_time)
	_update_timer_display()
	
	# Check if timer has finished
	if current_time <= 0:
		_on_timer_timeout()
		return
	
	# Activate sound warning
	if current_time <= warning_start_time and not warning_triggered:
		_play_warning_feedback()
		warning_triggered = true
	
	# Activate blink animation
	if enable_blink_animation and current_time <= blink_animation_start_time and not blink_animation_triggered:
		_start_blink_animation()
		blink_animation_triggered = true

#func _physics_process(_delta: float) -> void:
	#if is_running and GameManager.current_map:
		#GameManager.current_map.refresh_events()

func _on_timer_timeout() -> void:
	is_running = false
	current_time = 0
	GameManager.update_timer_time(id, current_time)
	_update_timer_display()
	_stop_warning_effects()
	_play_timeout_sound()
	
	if not Engine.is_editor_hint():
		pass
	else:
		await get_tree().create_timer(2.5).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		start(_in_editor_timer)

func _play_warning_feedback() -> void:
	if warning_fx and warning_audio_player:
		warning_audio_player.stream = warning_fx
		warning_sound_playing = true
		_play_warning_sound()

func _play_warning_sound() -> void:
	if not warning_audio_player:
		return

	# Calculate volume based on curve if available
	var volume_db = 0.0
	if warning_curve:
		var progress = 1.0 - (current_time / warning_start_time)
		var curve_value = warning_curve.sample(progress)
		volume_db = linear_to_db(curve_value)
	
	warning_audio_player.volume_db = volume_db
	if (Engine.is_editor_hint and play_sounds_in_editor) or not Engine.is_editor_hint():
		warning_audio_player.stop()
		warning_audio_player.play()
	
	if warning_timer and current_time > 0:
		var next_interval = _calculate_interval(0.1, 1.0, warning_curve)
		warning_timer.wait_time = next_interval
		warning_timer.start()

func _play_tick_sound() -> void:
	if not tick_audio_player:
		return
		
	if tick_audio_player.stream != tick_fx:
		tick_audio_player.stream = tick_fx
		
	if tick_audio_player:
		tick_audio_player.stop()
		tick_audio_player.play()


func _calculate_interval(min_value: float, max_value: float, curve: Curve) -> float:
	# Calculate interval based on curve and remaining time
	var base_interval = max_value # Base interval starts at maximum
	
	if curve and warning_start_time > 0:
		var progress = 1.0 - (current_time / warning_start_time)
		var curve_value = curve.sample(progress)
		# Accelerate progressively between max_value and min_value
		base_interval = clamp(max_value - (curve_value * (max_value - min_value)), min_value, max_value)
	else:
		# No curve, accelerate linearly based on remaining time
		var progress = 1.0 - (current_time / warning_start_time) if warning_start_time > 0 else 0.0
		base_interval = clamp(max_value - (progress * (max_value - min_value)), min_value, max_value)
	
	return base_interval

func _on_warning_timer_timeout() -> void:
	if warning_sound_playing and current_time > 0:
		_play_warning_sound()

func _on_tick_timer_timeout() -> void:
	if current_time > 0:
		_play_tick_sound()


func _start_blink_animation() -> void:
	if not blink_timer:
		return

	# Calculate initial blink speed
	var blink_interval = 0.5 # Default half second
	if blink_speed_curve:
		blink_interval = _calculate_interval(0.1, 1.0, blink_speed_curve)
	
	blink_timer.wait_time = blink_interval
	blink_timer.start()

func _check_meta_colors() -> void:
	if not timer_label.has_meta("original_color"):
		timer_label.set_meta("original_color", timer_label.get("instance_shader_parameters/modulate"))
	if not timer_label_back.has_meta("original_color"):
		timer_label_back.set_meta("original_color", text_outline_color)

func _on_blink_timer_timeout() -> void:
	if not enable_blink_animation or current_time <= 0:
		return
	
	# Toggle visibility
	is_blinking = !is_blinking
	_check_meta_colors()
	var blink_alpha = 0.3
	var timer_label_color = timer_label.get_meta("original_color")
	timer_label_color.a = blink_alpha if is_blinking else timer_label_color.a
	
	#timer_label_back.modulate.a = blink_alpha if is_blinking else timer_label_back.get_meta("original_color").a
	#timer_label.set("instance_shader_parameters/modulate", timer_label_color)
	
	# Update blink speed based on curve
	if blink_speed_curve and current_time > 0:
		var blink_interval = _calculate_interval(0.1, 1.0, blink_speed_curve)
		blink_timer.wait_time = blink_interval
		
		var t = create_tween()
		t.set_loops(2)
		t.set_speed_scale(2.0)
		t.set_parallel()
		t.tween_property(timer_label_back, "modulate:a", blink_alpha, blink_interval)
		t.tween_property(timer_label, "instance_shader_parameters/modulate:a", blink_alpha, blink_interval)
		t.tween_property(timer_label_back, "modulate:a", timer_label_back.get_meta("original_color").a, blink_interval).set_delay(blink_interval)
		t.tween_property(timer_label, "instance_shader_parameters/modulate:a", timer_label.get_meta("original_color").a, blink_interval).set_delay(blink_interval)
		t.set_parallel(false)


func _play_start_sound() -> void:
	if (Engine.is_editor_hint and play_sounds_in_editor) or not Engine.is_editor_hint():
		if start_fx and audio_player:
			audio_player.stream = start_fx
			audio_player.play()

func _play_audio_tick() -> void:
	if (Engine.is_editor_hint and play_sounds_in_editor) or not Engine.is_editor_hint():
		if tick_timer:
			tick_timer.start()


func _play_timeout_sound() -> void:
	if (Engine.is_editor_hint and play_sounds_in_editor) or not Engine.is_editor_hint():
		if timeout_fx and audio_player:
			audio_player.stream = timeout_fx
			audio_player.play()

func _stop_warning_effects() -> void:
	warning_sound_playing = false
	if warning_timer:
		warning_timer.stop()
	if warning_audio_player:
		warning_audio_player.stop()
	if blink_timer:
		blink_timer.stop()
	
	_restore_normal_appearance()

func _stop_tick_effects() -> void:
	if tick_timer:
		tick_timer.stop()


func _restore_normal_appearance() -> void:
	# Restore normal appearance
	if timer_label and timer_label_back and timer_title and timer_title_back:
		_check_meta_colors()
		timer_label.set("instance_shader_parameters/modulate", timer_label.get_meta("original_color"))
		timer_label_back.modulate.a = timer_label_back.get_meta("original_color").a


func _check_timer_state_after_time_change() -> void:
	if not is_running:
		return
	
	# Check if timer has finished after change
	if current_time <= 0:
		_on_timer_timeout()
		return
	
	# ============ WARNING HANDLING ============
	# Check if warning should be activated or deactivated
	if current_time <= warning_start_time:
		# Warning should be active
		if not warning_triggered:
			_play_warning_feedback()
			warning_triggered = true
	else:
		# Warning should be inactive
		if warning_triggered:
			_stop_warning_effects()
			warning_triggered = false
	
	# ============ BLINK ANIMATION HANDLING ============
	# Check if blink animation should be activated or deactivated
	if enable_blink_animation and current_time <= blink_animation_start_time:
		# Blink should be active
		if not blink_animation_triggered:
			_start_blink_animation()
			blink_animation_triggered = true
	else:
		# Blink should be inactive
		if blink_animation_triggered:
			if blink_timer:
				blink_timer.stop()
			_restore_normal_appearance()
			blink_animation_triggered = false
	
	# Update time display
	_update_timer_display()


#region Public Methods
func set_config(timer_id: int, timer_new_name: String, config: Dictionary) -> void:
	id = timer_id
	timer_name = timer_new_name
	show_background = config.get("show_background", true)
	var background_size = config.get("background_size", Vector2(0, 0))
	background_width = background_size.x
	background_height = background_size.y
	var background_path = config.get("timer_background", default_background)
	var tex = null if not ResourceLoader.exists(background_path) else load(background_path)
	background_texture = tex
	timer_name_align = config.get("title_align", 2)
	timer_name_modulate = config.get("title_modulate", Color("#9da9d5"))
	timer_name_modulate_mix_strength = config.get("title_modulate_mix_amount", 0.42)
	timer_format = config.get("timer_text_format", "HHh : MMm : SSs")
	custom_position = config.get("custom_position", Vector2.ZERO)
	var margin = config.get("margin", Vector2(20, 2))
	margin_horizontal = margin.x
	margin_vertical = margin.y
	screen_position = config.get("position_index", 1)
	var text_font_path = config.get("timer_font", font_base)
	text_font = null if not ResourceLoader.exists(text_font_path) else load(text_font_path)
	timer_text_size = config.get("timer_font_size", 48)
	timer_title_text_size = config.get("title_font_size", 32)
	text_outline_size = config.get("outline_size", 8)
	text_outline_color = config.get("outline_color", Color.BLACK)
	var text_gradient_path = config.get("text_gradient", text_gradient_base)
	var gradient = null if not ResourceLoader.exists(text_gradient_path) else load(text_gradient_path)
	text_gradient = gradient
	var start_fx_path = config.get("start_fx", "")
	start_fx = null if not ResourceLoader.exists(start_fx_path) else load(start_fx_path)
	var timeout_fx_path = config.get("timeout_fx", "")
	timeout_fx = null if not ResourceLoader.exists(timeout_fx_path) else load(timeout_fx_path)
	var warning_fx_path = config.get("warning_fx", "")
	warning_fx = null if not ResourceLoader.exists(warning_fx_path) else load(warning_fx_path)
	var tick_fx_path = config.get("tick_fx", "")
	tick_fx = null if not ResourceLoader.exists(tick_fx_path) else load(tick_fx_path)
	warning_start_time = config.get("warning_start_time", 10)
	var warning_curve_path = config.get("warning_curve", default_curve)
	warning_curve = null if not ResourceLoader.exists(warning_curve_path) else load(warning_curve_path)
	enable_blink_animation = config.get("enable_blink", true)
	blink_animation_start_time = config.get("blink_start_time", 10)
	var blink_curve_path = config.get("blink_curve", default_curve)
	blink_speed_curve = null if not ResourceLoader.exists(blink_curve_path) else load(blink_curve_path)
	
	_update_position()


func get_time() -> float:
	return current_time

func start(time: float) -> void:
	if time <= 0: return
	
	is_running = true
	max_time = time
	current_time = time
	warning_triggered = false
	blink_animation_triggered = false
	warning_sound_playing = false
	
	# Reproducir sonido de inicio
	_play_start_sound()
	
	# inicializar audio tick timer
	_play_audio_tick()

func restart() -> void:
	if max_time >= 0:
		start(max_time)

func stop() -> void:
	is_running = false
	if timer_title:
		timer_title_back.remove_meta("original_color")
		timer_title.remove_meta("original_color")
		timer_label_back.remove_meta("original_color")
		timer_label.remove_meta("original_color")
	_stop_warning_effects()
	_stop_tick_effects()
	current_time = 0
	if not Engine.is_editor_hint():
		queue_free()
	else:
		_update_timer_display()

func pause() -> void:
	set_process(false)
	is_paused = true
	if tick_timer:
		tick_timer.set_paused(true)
	_stop_warning_effects()

func resume() -> void:
	if is_paused:
		set_process(true)
		is_paused = false
		
		if tick_timer:
			tick_timer.set_paused(false)
		
		# Reactivar efectos si es necesario
		if warning_triggered and current_time <= warning_start_time:
			_play_warning_feedback()
		if blink_animation_triggered and enable_blink_animation and current_time <= blink_animation_start_time:
			_start_blink_animation()

func add_time(value: float) -> void:
	current_time += value
	_check_timer_state_after_time_change()

func subtract_time(value: float) -> void:
	current_time -= value
	_check_timer_state_after_time_change()
#endregion
