@tool
class_name DialogBase
extends PanelContainer


class SpecialEffectCommand:
	var name: String = ""
	var parameters: Dictionary = {}
	var start: int = 0
	var completed: bool = false
	
	@warning_ignore("shadowed_variable")
	func _init(name: String = "", parameters: Dictionary = {}, start: int = 0) -> void:
		self.name = name
		self.parameters = parameters
		self.start = start
	
	func _to_string() -> String:
		return "<name: %s, parameters: %s, start: %s, completed: %s>" % [name, parameters, start, completed]


class BackgroundImage:
	var id: int = 0
	var image: TextureRect
	var start_position: int
	var idle_animation: int
	var end_animation: int
	var end_animation_time: float
	var current_offset: Vector2
	var character_linked_to: int = 0
	
	var end_animation_displacement_horizontal: float = 256
	
	var idle_animation_tween: Tween
	
	signal deleted()
	
	@warning_ignore("shadowed_variable")
	func _init(id: int = 0, image: TextureRect = null, start_position: int = 0, idle_animation: int = 0, end_animation: int = 0, end_animation_time: float = 0.0, current_offset: Vector2 = Vector2.ZERO, character_linked_to: int = 0) -> void:
		self.id = id
		self.image = image
		self.start_position = start_position
		self.idle_animation = idle_animation
		self.end_animation = end_animation
		self.end_animation_time = end_animation_time
		self.current_offset = current_offset
		self.character_linked_to = character_linked_to
	

	func start_idle_animation() -> void:
		if not is_instance_valid(self) or is_queued_for_deletion() or not image: return
		
		if idle_animation_tween:
			idle_animation_tween.kill()
		
		if idle_animation == 1: # Breathing
			image.pivot_offset = Vector2(image.custom_minimum_size.x * 0.5, image.custom_minimum_size.y)
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_loops()
			idle_animation_tween.set_ease(Tween.EASE_OUT)
			idle_animation_tween.set_trans(Tween.TRANS_CIRC)
			idle_animation_tween.tween_property(image, "scale:y", 0.994, 0.5)
			idle_animation_tween.tween_property(image, "scale:y", 1.0, 0.5)
			idle_animation_tween.tween_interval(0.25)
		elif idle_animation == 2: # Scared
			image.pivot_offset = Vector2(image.custom_minimum_size.x * 0.5, image.custom_minimum_size.y)
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_ease(Tween.EASE_OUT)
			idle_animation_tween.set_trans(Tween.TRANS_CIRC)
			idle_animation_tween.set_speed_scale(2.5)
			idle_animation_tween.set_loops()
			idle_animation_tween.tween_property(image, "position:x", image.position.x - 3, 0.05)
			idle_animation_tween.tween_property(image, "position:x", image.position.x, 0.05)
			idle_animation_tween.tween_property(image, "scale:y", 0.998, 0.05)
			idle_animation_tween.tween_property(image, "position:x", image.position.x + 3, 0.05)
			idle_animation_tween.tween_property(image, "position:x", image.position.x, 0.05)
			idle_animation_tween.tween_property(image, "scale:y", 1.0, 0.05)
		elif idle_animation == 3: # Floating / Levitate
			# Ideally, pivot should be center for purely visual float, but bottom works if we only tween position
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_loops()
			idle_animation_tween.set_trans(Tween.TRANS_SINE)
			idle_animation_tween.set_ease(Tween.EASE_IN_OUT)
			# Moves up slightly then returns down
			var float_offset: float = 8.0
			idle_animation_tween.tween_property(image, "position:y", image.position.y - float_offset, 1.0)
			idle_animation_tween.tween_property(image, "position:y", image.position.y, 1.0)
		elif idle_animation == 4: # Pulsing / Heartbeat
			image.pivot_offset = Vector2(image.custom_minimum_size.x * 0.5, image.custom_minimum_size.y * 0.5) # Center pivot for even scaling
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_loops()
			idle_animation_tween.set_trans(Tween.TRANS_SINE)
			idle_animation_tween.set_ease(Tween.EASE_IN_OUT)
			idle_animation_tween.tween_property(image, "scale", Vector2(1.05, 1.05), 0.6)
			idle_animation_tween.tween_property(image, "scale", Vector2.ONE, 0.6)
		elif idle_animation == 5: # Wobble / Sway
			image.pivot_offset = Vector2(image.custom_minimum_size.x * 0.5, image.custom_minimum_size.y) # Pivot at bottom
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_loops()
			idle_animation_tween.set_trans(Tween.TRANS_SINE)
			idle_animation_tween.set_ease(Tween.EASE_IN_OUT)
			idle_animation_tween.tween_property(image, "rotation_degrees", 4.0, 1.0)
			idle_animation_tween.tween_property(image, "rotation_degrees", -4.0, 1.0)
		elif idle_animation == 6: # Ghost / Transparency
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_loops()
			idle_animation_tween.set_trans(Tween.TRANS_SINE)
			idle_animation_tween.set_ease(Tween.EASE_IN_OUT)
			idle_animation_tween.tween_property(image, "modulate:a", 0.4, 1.5)
			idle_animation_tween.tween_property(image, "modulate:a", 1.0, 1.5)
		elif idle_animation == 7: # Rage / Vibration
			image.pivot_offset = Vector2(image.custom_minimum_size.x * 0.5, image.custom_minimum_size.y * 0.5)
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_loops()
			idle_animation_tween.set_trans(Tween.TRANS_LINEAR)
			var base_pos: Vector2 = image.position
			var shake: float = 2.0
			idle_animation_tween.tween_property(image, "position", base_pos + Vector2(shake, -shake), 0.05)
			idle_animation_tween.tween_property(image, "position", base_pos + Vector2(-shake, shake), 0.05)
			idle_animation_tween.tween_property(image, "position", base_pos + Vector2(-shake, -shake), 0.05)
			idle_animation_tween.tween_property(image, "position", base_pos + Vector2(shake, shake), 0.05)
			idle_animation_tween.tween_property(image, "position", base_pos, 0.05)
		elif idle_animation == 8: # Squash & Stretch (Bouncy)
			image.pivot_offset = Vector2(image.custom_minimum_size.x * 0.5, image.custom_minimum_size.y)
			idle_animation_tween = image.create_tween()
			idle_animation_tween.set_loops()
			idle_animation_tween.set_trans(Tween.TRANS_SINE)
			idle_animation_tween.set_ease(Tween.EASE_IN_OUT)
			# Flatten down and get wider
			idle_animation_tween.tween_property(image, "scale", Vector2(1.1, 0.9), 0.4)
			# Stretch up and get thinner
			idle_animation_tween.tween_property(image, "scale", Vector2(0.9, 1.1), 0.4)
	
	func end_idle_animation() -> void:
		if idle_animation_tween:
			idle_animation_tween.kill()
		
		image.scale = Vector2.ONE
	
	func kill() -> void:
		if idle_animation_tween:
			idle_animation_tween.kill()
		if image:
			if end_animation == 0 or end_animation_time <= 0.0:
				image.get_parent().remove_child(image)
				image.queue_free()
				image = null
			else:
				var t = image.get_parent().create_tween()
				t.set_parallel(true)
				match end_animation:
					2: # move to left
						t.tween_property(image, "position:x", image.position.x - end_animation_displacement_horizontal, end_animation_time)
					3: # move to right
						t.tween_property(image, "position:x", image.position.x + end_animation_displacement_horizontal, end_animation_time)

				t.tween_property(image, "modulate:a", 0.0, end_animation_time)
				t.tween_interval(0.01)
				t.set_parallel(false)
				t.tween_callback(
					func():
						image.get_parent().remove_child(image)
						image.queue_free()
						image = null
				)
		deleted.emit()
	
	func _to_string() -> String:
		return "<image %s start_position=%s idle_animation=%s character_linked_to=%s>" % [id, start_position, idle_animation, character_linked_to]


class TagInfo:
	var type: String # Tag type without /
	var start: int # Start position
	var length: int # Total tag length
	var is_closing: bool # If closing tag
	var full_tag: String # Full tag
	
	func _init(t: String, s: int, l: int, c: bool, f: String):
		type = t
		start = s
		length = l
		is_closing = c
		full_tag = f
	
	func _to_string() -> String:
		return "type: %s, start: %s, length: %s, is_closing: %s, full_tag: %s" % [
			type, start, length, is_closing, full_tag
		]

# The message will be tested with the text of the variable “test_dialog_box” after 0.5 seconds...
@export_multiline var test_dialog_box: String = "":
	set(value):
		test_dialog_box = value
		if Engine.is_editor_hint() and is_node_ready():
			if not editor_setup_initialized:
				setup()
			if not test_dialog_box.is_empty():
				editor_refresh_timer = 0.5
				print("The message will be tested with the text of the variable “test_dialog_box” after 0.5 seconds...")
			else:
				reset()
				editor_refresh_timer = 0.0

@export var minimun_dialog_width: int = 180
@export var minimun_dialog_height: int = 60

@export var message_max_width = 800
@export_range(1, 16) var message_max_lines: int = 4
@export var comma_pause_delay: float = 0.15
@export var dot_pause_delay: float = 0.35
@export var character_container: Control

const BACKGROUND_IMAGE = preload("res://Scenes/DialogTemplates/background_image.tscn")
const AUTO_AUDIO_PLAYER = preload("res://Scenes/DialogTemplates/auto_audio_player.tscn")

enum SkipMode {NONE, SHOW_ALL_IGNORE_COMMANDS, SHOW_ALL, FAST_MESSAGE}

var paragraph_delay: float = 1.5

var busy: bool = false
var busy_when_preview: bool = false
var busy_until_resume: bool = false
var busy_process: bool = false
# Lists
var special_commands: Array[SpecialEffectCommand] = []
var images: Array[BackgroundImage] = []
var sounds: Array[AudioStreamPlayer] = []
var speakers: Dictionary = {}
var paragraphs: Array[String]
# Flow text
var current_character: int = 0
var max_characters: int = 0
var skip_type: SkipMode = SkipMode.FAST_MESSAGE
var skip_speed = 0.01
var max_character_delay: float = 0.03
var current_delay: float = 0.0
var delay_for_input: float = 0.0
var wait_for_input_enabled: bool = true
var force_no_wait_for_input: bool = false
var wait_for_input_time = 1.0
var waiting_for_input: bool = false
var resume_dialog: bool = false
var dialog_is_started: bool = false
var dialog_is_paused: bool = false
# Dialog Animation
var start_animation_id: int = 0
var start_animation_duration: float = 0.45
var start_animation_trans_type: int = 10
var start_animation_ease_type: int = 1
var end_animation_id: int = 0
var end_animation_duration: float = 0.45
var end_animation_trans_type: int = 10
var end_animation_ease_type: int = 0
# Dialog writing sound
var text_fx: AudioStream = preload("res://Assets/Sounds/typewrite2.ogg")
var text_fx_volume: float = 0.0
var text_fx_min_pitch: float = 0.7
var text_fx_max_pitch: float = 1.1
var current_text_fx: AudioStream = text_fx
var current_text_fx_volume: float = text_fx_volume
var current_text_fx_min_pitch: float = text_fx_min_pitch
var current_text_fx_max_pitch: float = text_fx_max_pitch
var can_play_sound: bool = true
# Dialog config
var initial_config: Dictionary = {}
var DEFAULTFONT = "res://addons/CustomControls/Resources/Fontsunifont-13.0.01.ttf"
var default_font: String = DEFAULTFONT
var default_text_size: int = 22
var default_text_align: int = 0
var default_text_color: Color = Color.WHITE
var text_box_margin_left: int
var text_box_margin_right: int
var text_box_margin_top: int
var text_box_margin_bottom: int
var text_box_position: int
var caching_speaker: bool = false
# Others
var tweens: Dictionary = {
	"left_box": null,
	"left_face": null,
	"right_box": null,
	"right_face": null,
	"message": null,
	"others": []
}
var wait_for_user_option_selected_enabled: bool = false

var is_new_dialog: bool = true
var is_multi_dialog: bool = false
var is_editor_prevew: bool = false

var speaker_text_color: Color = Color.TRANSPARENT
var backup_blip = {
	"current_text_fx": null,
	"current_text_fx_min_pitch": 1.0,
	"current_text_fx_max_pitch": 1.0,
	"current_text_fx_volume": 0.0
}

# Flag to indicate that the dialog is floating and the node to which it is attached to reposition itself correctly.
var is_floating: bool = false
var anchor_node: Node
var floating_initialize: bool = false

var instant_text_enabled: bool = false

# Start Transition Variables
@export var reverse: bool = false
@export var all_at_once: bool = false

var start_transition_id: int = 0
var start_transition_parameters: Dictionary = {}

var editor_setup_initialized: bool = false
var editor_refresh_timer: float = 0.0
var command_waiting_enabled: bool = false

var highlight_character_tween: Tween

var time: float:
	get():
		if !is_inside_tree():
			return 0
		else:
			if max_characters > 0:
				return (float(current_character) / float(max_characters))
			else:
				return (0)
		

# Reference self for use in transition effects.
static var instance


@onready var message = %Message


signal message_started()
signal message_finished()
signal message_childs_changed()
signal perform_resume_dialog()
signal all_messages_finished()
signal closing()


func _ready() -> void:
	propagate_call("set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	mouse_filter = Control.MOUSE_FILTER_STOP
	instance = self
	perform_resume_dialog.connect(_on_resume_dialog)
	reset()


func resume() -> void:
	dialog_is_paused = false
	busy_until_resume = false


func _on_resume_dialog() -> void:
	resume_dialog = false
	if paragraphs.size() > 0:
		var bak = wait_for_user_option_selected_enabled
		await setup_text("next paragraph", true, true)
		wait_for_user_option_selected_enabled = bak
	else:
		# No more paragraphs
		show_close_animation()
		
	delay_for_input = 0.1


func get_real_size() -> Vector2:
	var w = size.x
	var h = size.y
	if character_container:
		var minx = INF
		var maxx = - INF
		var miny = INF
		var maxy = - INF
		for img in character_container.get_children():
			minx = min(img.position.x, minx)
			maxx = max(img.position.x + img.size.x, maxx)
			miny = min(img.position.y, miny)
			maxy = max(img.position.y + img.size.y, maxy)
		w = max(w, maxx - minx)
		h = max(h, maxy - miny)
	
	return Vector2(w, h)


func _process(delta: float) -> void:
	if editor_refresh_timer > 0.0 and Engine.is_editor_hint():
		editor_refresh_timer -= delta
		if editor_refresh_timer <= 0.0:
			instance = self
			await setup_text(test_dialog_box)
			var screen_size = Vector2(
				ProjectSettings["display/window/size/viewport_width"],
				ProjectSettings["display/window/size/viewport_height"] - 38
			)
			position = Vector2(
				screen_size.x * 0.5 - size.x * 0.5,
				screen_size.y - size.y
			)
			pivot_offset = size * 0.5
		return
		
	if !dialog_is_started or dialog_is_paused:
		return
	
	if is_floating:
		set_position_over_node()
		if busy and instant_text_enabled: return
	else:
		if instant_text_enabled and busy_until_resume and not busy:
			busy = true

	if delay_for_input > 0:
		delay_for_input -= delta
		
	if (busy or waiting_for_input) and not get_viewport().is_input_handled():
		if waiting_for_input and (Input.is_action_just_pressed("ui_select") or Input.is_action_just_pressed("Mouse Left")):
			if busy_when_preview:
				return
			get_viewport().set_input_as_handled()
			waiting_for_input = false
			%AdvanceCursorContainer.visible = false
			busy = false
			if resume_dialog:
				perform_resume_dialog.emit()
		return
	
	if busy_until_resume:
		return
	
	if dialog_is_started and current_delay <= 0:
		dialog_is_paused = false
		busy_until_resume = true
		if !wait_for_user_option_selected_enabled or is_new_dialog or paragraphs.size() > 0:
			if paragraphs.size() == 0 and wait_for_user_option_selected_enabled:
				all_messages_finished.emit()
			else:
				message_finished.emit()
				if max_characters <= 1:
					%Message.visible_characters = 2
		else:
			all_messages_finished.emit()
	
	if waiting_for_input and busy_when_preview:
		return
	

	if current_delay > 0.0:
		current_delay -= delta
		if current_delay <= 0:
			current_delay = 0
			busy_process = true
			await show_next_character()
			busy_process = false
	
	if current_delay <= 0.0 and current_character < max_characters:
		current_delay = max_character_delay


func _show_wait_form_input_cursor() -> void:
	if is_floating:
		if not is_inside_tree(): return
		await get_tree().create_timer(paragraph_delay).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		if floating_initialize:
			resume()
			_on_resume_dialog()
		else:
			perform_resume_dialog.emit()
	else:
		if force_no_wait_for_input:
			if not is_inside_tree(): return
			
			var wait_time = wait_for_input_time if wait_for_input_time > 0 else 1.0
			
			busy = true
			await get_tree().create_timer(wait_time).timeout
			if not is_instance_valid(self) or not is_inside_tree(): return
			
			if is_inside_tree():
				perform_resume_dialog.emit()
		
		elif wait_for_input_enabled:
			busy = true
			waiting_for_input = true
			resume_dialog = true
			%AdvanceCursorContainer.show()
		else:
			if not is_inside_tree(): return
			await get_tree().create_timer(wait_for_input_time).timeout
			if not is_instance_valid(self) or not is_inside_tree(): return
			perform_resume_dialog.emit()


func get_message_box() -> RichTextLabel:
	return %Message


func setup() -> void:
	setup_effects()
	setup_transitions()
	if Engine.is_editor_hint():
		editor_setup_initialized = true
	if not message_finished.is_connected(_show_wait_form_input_cursor):
		message_finished.connect(_show_wait_form_input_cursor)


func setup_effects():
	var paths = [
		"res://addons/CustomControls/Resources/RichTextEffects/ColorMod.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Cuss.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/ghost.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Heart.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Jump.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/L33T.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Nervous.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Number.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Rain.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Sparkle.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/UwU.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Woo.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/lenguage_learning.gd"
	]
	
	for path in paths:
		var effect = load(path).new()
		if !message: return
		message.install_effect(effect)


func setup_transitions():
	var paths = [
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Bounce.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Console.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Embers.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Prickle.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Redacted.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/WFC.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Word.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Glitch.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Energize.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Transitions/Fade.gd"
	]
	
	for path in paths:
		var effect = load(path).new()
		if !message: return
		message.install_effect(effect)
	
	for effect in message.custom_effects:
		effect.set_meta("dialog", self)


func parse_text(text: String) -> String:
	var t = text
	t = t.strip_edges()
	
	var regex = RegEx.new()
	
	# clean \n after special command
	var special_tags = "character|face|imgfx|img_remove|showbox|hidebox|sound|wait|no_wait_input|dialog_shake|blip|highlight_character|speaker_entry|speaker_entry_end|speaker_exit|freeze"
	regex.compile("(\\[(?:" + special_tags + ")[^\\]]*\\])\\n")
	t = regex.sub(t, "$1", true)
	
	# Clean \n before special command
	regex.compile("\\n(\\[(?:" + special_tags + ")[^\\]]*\\])")
	t = regex.sub(t, "$1", true)
	
	t = t.strip_edges()
	
	# Consolidate consecutive newlines (if more than 1, leave 1)
	regex.compile("\\n{2,}")
	t = regex.sub(t, "\n", true)
	
	# Remove newlines immediately following any command closing bracket
	regex.compile("(\\])\\n")
	t = regex.sub(t, "$1", true)
	
	# Transform [newline] tag into actual line break
	t = t.replace("[newline]", "\n")
	
	## Insert a space after a period or comma if one was not already present.
	## It now only adds a space if the following character is NOT a lowercase letter or digit.
	#regex.compile("(?![^\\[\\]]*\\])([,.])([^a-z0-9\\s])")
	#t = regex.sub(t, "$1 $2", true)
	
	# Replace the . with wait commands with a dot_pause_delay duration.
	# FIX: Added (?![a-z0-9]) lookahead to avoid adding pauses inside file paths or numbers.
	regex.compile("(?![^\\[\\]]*\\])(\\.)(?![a-z0-9])")
	t = regex.sub(t, ".[wait type=0 seconds=%s _is_script_command=true]" % dot_pause_delay, true)
	
	# Replace the , with wait commands with a comma_pause_delay duration.
	# FIX: Added (?![a-z0-9]) lookahead here as well for consistency.
	regex.compile("(?![^\\[\\]]*\\])(,)(?![a-z0-9])")
	t = regex.sub(t, ",[wait type=0 seconds=%s _is_script_command=true]" % comma_pause_delay, true)
	
	# Replaces the speaker command with several commands
	regex.compile("\\[speaker index=(\\d+)\\]")
	
	var matches = regex.search_all(t)
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var index: int = int(m.get_string(1))
		var replace_text = get_speaker_commands(index)
		var start_pos = m.get_start()
		var end_pos = m.get_end()
		t = regex.sub(t, replace_text, false, start_pos, end_pos)

	# Replaces the hide_speaker command with several commands
	regex.compile("\\[hide_speaker index=(\\d+)\\]")
	matches = regex.search_all(t)
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var index: int = int(m.get_string(1))
		var replace_text = get_hide_speaker_commands(index)
		var start_pos = m.get_start()
		var end_pos = m.get_end()
		t = regex.sub(t, replace_text, false, start_pos, end_pos)
	# Replaces the reset command with several commands
	t = t.replace("[r]", get_reset_commands())
	
	regex.compile("(\\[(\\w+)\\s*[^]]*\\])|(\\[/\\w+\\])")
	
	var command_list = []
	var special_command_list = [
		"character", "face", "imgfx", "img_remove", "showbox", "hidebox", "sound", "wait",
		"no_wait_input", "variable", "actor", "party", "gold", "class", "item", "weapon",
		"profession_name", "profession_level",
		"armor", "enemy", "state", "show_whole_line", "dialog_shake", "blip", "highlight_character",
		"speaker", "speaker_end", "speaker_entry", "speaker_entry_end", "speaker_exit", "freeze"
	]
	var offset = 0
	var image_found = 0
	
	matches = regex.search_all(t)
	for m in matches:
		var command_name = m.get_string(2).to_lower()
		var command_start = m.get_start() - offset - 1
		if "_is_script_command" in m.get_string(0):
			command_start += 1
		#var command_end = m.get_end() - offset
		if command_name in special_command_list:
			if command_name in ["variable", "actor", "party", "gold", "class", "item", "weapon",
		"profession_name", "profession_level", "armor", "enemy", "state"]:
				var obj_value: String = ""
				var args: Dictionary = parse_args(m.get_string(1))
				match command_name:
					"variable":
						if args.has("id"):
							var id = int(args.id)
							var data = RPGSYSTEM.system.variables
							obj_value = str(GameManager.get_variable(id))
							if args.has("extra") and args.extra:
								obj_value = data.get_item_name(id) + ": " + obj_value
					"actor", "class", "item", "weapon", "armor", "enemy", "state", "profession_name":
						var index = ["actor", "class", "item", "weapon", "armor", "enemy", "state", "profession_name"].find(command_name)
						var data_id = ["actors", "classes", "items", "weapons", "armors", "enemies", "states", "professions"][index]
						var data = RPGSYSTEM.database[data_id]
						if args.has("id"):
							var id = int(args.id)
							if data.size() > id:
								obj_value = data[id].name
								if args.has("extra") and args.extra:
									var icon = _get_icon(data[id].icon, args.get("size", ""))
									if not icon.is_empty():
										obj_value = icon + obj_value
										offset += icon.length()
					"profession_level":
						if args.has("id"):
							var id = int(args.id)
							if id > 0 and RPGSYSTEM.database.professions.size() > id:
								var profession = RPGSYSTEM.database.professions[id]
								var level = GameManager.get_profession_level(profession) - 1
								if level >= 0 and profession.levels.size() > level:
									var profession_name = profession.levels[level].name
									obj_value = profession_name
									offset += obj_value.length()
					"gold":
						var extra1 = args.get("extra", 0)
						var extra2 = args.get("extra2", 0)
						var currency_info = {} if extra1 == 0 else RPGSYSTEM.database.system.currency_info
						var gold_name = "" if !currency_info else currency_info.get("name", "")
						var gold_value = 0 if Engine.is_editor_hint() else GameManager.game_state.current_gold
						obj_value = "%s%s" % [gold_value, gold_name]
						offset += gold_name.length()
						
						if extra2 == 1:
							currency_info = RPGSYSTEM.database.system.currency_info
							var icon_path = currency_info.get("icon", "")
							var icon = _get_icon(icon_path, args.get("size", ""))
							if not icon.is_empty():
								obj_value = icon + " " + obj_value
								offset += icon.length()
					"party":
						if GameManager.game_state:
							if args.has("id"):
								var id = int(args.id)
								var actor_id = -1 if id < 0 or GameManager.game_state.current_party.size() <= id else GameManager.game_state.current_party[id]
								var actor_name = "" if actor_id < 1 or RPGSYSTEM.database.actors.size() <= actor_id else RPGSYSTEM.database.actors[actor_id].name
								if not actor_name.is_empty():
									obj_value = actor_name
									offset += obj_value.length()
							
				offset += m.get_string(0).length() - obj_value.length()
				var c = {
					"start": m.get_start(),
					"end": m.get_end(),
					"text": obj_value
				}
				command_list.append(c)
				continue
			else:
				var c = {
					"start": m.get_start(),
					"end": m.get_end(),
					"text": ""
				}
				command_list.append(c)
				special_commands.append(
					SpecialEffectCommand.new(command_name, parse_args(m.get_string(0)), command_start
				))

		if m.get_string(3).to_lower() == "[/img]" and image_found:
			offset += m.get_start() - image_found
			image_found = 0
		else:
			if command_name == "img":
				image_found = m.get_start()
			offset += m.get_string(0).length()
		
	for i in range(command_list.size() - 1, -1, -1):
		var c = command_list[i]
		t = t.substr(0, c["start"]) + c.text + t.substr(c["end"], t.length())
	

	t = get_final_text(t)
	t = fix_tags(t)
	
	#regex.compile("\\.(\\s+)\\.")
	#var match_point = regex.search(t)
	#while match_point:
		#var i = match_point.get_start()
		#var e = match_point.get_end()
		#t = t.substr(0, i + 1) + t.substr(e - 1)
		#match_point = regex.search(t)
	return t.strip_edges()


func _get_icon(icon: Variant, encoded_format: String) -> String:
	var icon_command = ""
	var w = int(str(encoded_format).get_slice("x", 0))
	var h = int(str(encoded_format).get_slice("x", 1))
	if icon is String:
		if encoded_format.is_empty():
			icon_command = "[img]%s[/img]" % icon
		else:
			icon_command = "[img=%sx%s]%s[/img]" % [w, h, icon]
	elif icon is RPGIcon:
		var icon_path = icon.path
		var icon_region = "region=\"%s,%s,%s,%s\"" % [
			icon.region.position.x,
			icon.region.position.y,
			icon.region.size.x,
			icon.region.size.y
		]
		if not encoded_format.is_empty():
			if icon.region.has_area():
				icon_command = "[img=%sx%s %s]%s[/img]" % [w, h, icon_region, icon_path]
			else:
				icon_command = "[img=%sx%s]%s[/img]" % [w, h, icon_path]
		elif icon.region.has_area():
			icon_command = "[img %s]%s[/img]" % [icon_region, icon_path]
		else:
			icon_command = "[img]%s[/img]" % icon_path

	return icon_command


func parse_args(command: String) -> Dictionary:
	var args = {}
	var regex = RegEx.new()
	regex.compile("\\[(\\w+)\\s*=\\s*([^\\]]+)|(\\w+)\\s*=\\s*\"([^\"]+)\"|([^\\s]+)\\s*=\\s*([^\\s\\]]+)")
	var matches = regex.search_all(command)
	for m in matches:
		var command_name: String = ""
		var command_arg: String = ""
		var value
		if m.get_string(1):
			command_name = "value"
			command_arg = m.get_string(2)
		elif m.get_string(3):
			command_name = m.get_string(3)
			command_arg = m.get_string(4)
		elif m.get_string(5):
			command_name = m.get_string(5)
			command_arg = m.get_string(6)
		
		if command_arg.is_valid_int(): value = int(command_arg)
		elif command_arg.is_valid_float(): value = float(command_arg)
		elif command_arg.is_valid_html_color(): value = Color.from_string(command_arg, Color.BLACK)
		else:
			command_arg = command_arg.strip_edges()
			if command_arg.to_lower() == "true":
				value = true
			elif command_arg.to_lower() == "false":
				value = false
			else:
				value = command_arg
		
		args[command_name] = value
	return args


func reset() -> void:
	if not message: return
	message.text = ""
	if (is_new_dialog and not is_multi_dialog) or is_editor_prevew:
		modulate.a = 0.0
		for key in tweens:
			if key == "others":
				for t: Tween in tweens.others:
					if t and t.is_valid() and t.is_running():
						t.kill()
				tweens.others = []
			else:
				if tweens[key] is Tween and tweens[key].is_valid() and tweens[key].is_running():
					tweens[key].kill()
				tweens[key] = null
		set("custom_minimum_size", Vector2.ZERO)
		message.set("custom_minimum_size", Vector2.ZERO)
		message.size = Vector2.ZERO
		propagate_call("set_size", [Vector2.ZERO])
		message.pivot_offset = Vector2.ZERO
		message.visible_characters = 0

	busy = false
	waiting_for_input = false
	current_character = 0
	max_characters = 0
	dialog_is_started = false
	dialog_is_paused = false
	resume_dialog = false
	speaker_text_color = Color.TRANSPARENT
	busy_when_preview = false
	busy_until_resume = false
	is_new_dialog = true
	is_multi_dialog = false
	is_editor_prevew = false
	current_delay = 0.0
	delay_for_input = 0.0
	wait_for_user_option_selected_enabled = false
	wait_for_input_enabled = true
	wait_for_input_time = 0.0

	for obj in images.duplicate():
		obj.kill()

	special_commands.clear()
	for obj in sounds: obj.queue_free()
	sounds.clear()
	paragraphs.clear()
	%TypeWritePlayer.stop()
	%NameLeftContainer.visible = false
	%NameLeft.text = ""
	%NameRightContainer.visible = false
	%NameRight.text = ""
	%LeftIconFace.texture = null
	%LeftIconFace.get_parent().get_parent().visible = false
	%RightIconFace.texture = null
	%RightIconFace.get_parent().get_parent().visible = false
	%AdvanceCursorContainer.visible = false
	
	if Engine.is_editor_hint():
		var screen_size = Vector2(
			ProjectSettings["display/window/size/viewport_width"],
			ProjectSettings["display/window/size/viewport_height"] - 38
		)
		position = Vector2(
			screen_size.x * 0.5 - size.x * 0.5,
			screen_size.y - size.y
		)
		pivot_offset = size * 0.5
	
	if highlight_character_tween:
		highlight_character_tween.kill()
	
	%NameLeft.self_modulate.a = 1.0
	%NameLeftBackground.self_modulate.a = 1.0
	%LeftIconFace.self_modulate.a = 1.0
	%NameRight.self_modulate.a = 1.0
	%NameRightBackground.self_modulate.a = 1.0
	%RightIconFace.self_modulate.a = 1.0


func soft_reset() -> void:
	wait_for_input_enabled = true
	wait_for_input_time = 0.0
	message.modulate.a = 1.0
	%AdvanceCursorContainer.visible = false
	current_character = 0
	max_characters = 0
	special_commands.clear()


func get_command_selected(selection: String) -> Dictionary:
	var result: Dictionary = {}
	
	var regex = RegEx.new()
	regex.compile("^\\[(\\w+)([^\\]]*)\\]|\\[\\W*\\/(\\w+)\\]$")
	var matches: Array[RegExMatch] = regex.search_all(selection)
	if matches.size() == 2:
		if matches[0].get_string(1) == matches[1].get_string(3):
			var xi = matches[0].get_string(0).length()
			var xf = selection.length() - matches[1].get_string(0).length() - xi
			result = {
				"command_name": matches[0].get_string(1),
				"args": matches[0].get_string(2),
				"text": selection.substr(xi, xf),
				"command_start": matches[0].get_string(0),
				"command_end": matches[1].get_string(0)
			}
	elif matches.size() == 1:
		var xi = matches[0].get_string(0).length()
		var xf = selection.length() - xi
		result = {
			"command_name": matches[0].get_string(1),
			"args": matches[0].get_string(2),
			"text": selection.substr(xi, xf),
			"command_start": matches[0].get_string(0),
			"command_end": ""
		}
		
	return result


func try_select_bbcode(text: String, cursor_pos: int) -> String:
	var start_idx1 = text.rfind("[", cursor_pos)
	var start_idx2 = text.rfind("]", cursor_pos - 1)
	var end_idx1 = text.find("]", cursor_pos)
	var end_idx2 = text.find("[", cursor_pos)
	if (
		(start_idx2 != -1 and start_idx1 != -1 and start_idx2 > start_idx1) or
		(end_idx2 != -1 and end_idx1 != -1 and end_idx2 < end_idx1)
	):
		return ""

	if start_idx1 != -1 and end_idx1 != -1:
		var command = text.substr(start_idx1, end_idx1 - start_idx1 + 1)
		var command_data = get_command_selected(command)
		return command_data.command_start
	
	return ""


func set_message_config(config: Dictionary) -> void:
	if not message: return

	config.get("scene_path", null)
	message_max_lines = config.get("max_lines", 4)
	message_max_width = config.get("max_width", 800)
	max_character_delay = config.get("character_delay", 0.03)
	dot_pause_delay = config.get("dot_delay", 0.35)
	comma_pause_delay = config.get("comma_delay", 0.15)
	paragraph_delay = config.get("paragraph_delay", 1.5)
	skip_type = config.get("skip_mode", SkipMode.FAST_MESSAGE)
	skip_speed = config.get("skip_speed", 0.01)
	start_animation_id = config.get("start_animation", 0)
	start_animation_duration = config.get("start_animation_duration", 0.45)
	start_animation_trans_type = config.get("start_animation_trans_type", 10)
	start_animation_ease_type = config.get("start_animation_ease_type", 1)
	end_animation_id = config.get("end_animation", 0)
	end_animation_duration = config.get("end_animation_duration", 0.45)
	end_animation_trans_type = config.get("end_animation_trans_type", 10)
	end_animation_ease_type = config.get("end_animation_ease_type", 0)
	start_transition_id = config.get("text_transition", 0)
	start_transition_parameters = get_parameters(start_transition_id, config.get("text_transition_parameters", {}))
	var fx = config.get("fx_path", "res://Assets/Sounds/typewrite2.ogg")
	if ResourceLoader.exists(fx):
		text_fx = load(fx)
	else:
		text_fx = null
		
	text_fx_volume = config.get("fx_volume", 0.0)
	text_fx_min_pitch = config.get("fx_pitch_min", 0.7)
	text_fx_max_pitch = config.get("fx_pitch_max", 1.1)
	
	current_text_fx = text_fx
	current_text_fx_volume = text_fx_volume
	current_text_fx_min_pitch = text_fx_min_pitch
	current_text_fx_max_pitch = text_fx_max_pitch
	backup_blip.current_text_fx = current_text_fx
	backup_blip.current_text_fx_min_pitch = current_text_fx_min_pitch
	backup_blip.current_text_fx_max_pitch = current_text_fx_max_pitch
	backup_blip.current_text_fx_volume = current_text_fx_volume
	
	default_font = config.get("font", DEFAULTFONT)
	default_text_color = config.get("text_color", Color.WHITE)
	default_text_size = config.get("text_size", 22)
	default_text_align = config.get("text_align", 0)
	
	text_box_margin_left = config.get("text_box_margin_left", 16)
	text_box_margin_right = config.get("text_box_margin_right", 16)
	text_box_margin_top = config.get("text_box_margin_top", 16)
	text_box_margin_bottom = config.get("text_box_margin_bottom", 16)
	text_box_position = config.get("text_box_position", 7)
	
	message.set("theme_override_constants/outline_size", config.get("outline_size", 2))
	var shadow_offset = config.get("shadow_offset", Vector2(2, 2))
	message.set("theme_override_constants/shadow_offset_x", shadow_offset.x)
	message.set("theme_override_constants/shadow_offset_y", shadow_offset.y)
	message.set("theme_override_colors/font_outline_color", config.get("outline_color", Color.BLACK))
	message.set("theme_override_colors/font_shadow_color", config.get("outline_color", Color("#00000093")))
	
	if not is_floating:
		set_position_preset()
	else:
		set_position_over_node()


func set_position_preset() -> void:
	set_main_margin(text_box_margin_left, text_box_margin_right, text_box_margin_top, text_box_margin_bottom)
	
	var presets = [
		Control.PRESET_TOP_LEFT, Control.PRESET_CENTER_TOP, Control.PRESET_TOP_RIGHT,
		Control.PRESET_CENTER_LEFT, Control.PRESET_CENTER, Control.PRESET_CENTER_RIGHT,
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_RIGHT,
		"RANDOM"
	]
	var text_box_pos = max(0, min(text_box_position, presets.size() - 1))
	if text_box_pos == presets.size() - 1:
		text_box_pos = presets[randi_range(0, presets.size() - 2)]
	
	# Set size flags based on exact preset
	match presets[text_box_pos]:
		Control.PRESET_TOP_LEFT:
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		Control.PRESET_CENTER_TOP:
			size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
			size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		Control.PRESET_TOP_RIGHT:
			size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
			size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		Control.PRESET_CENTER_LEFT:
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
		Control.PRESET_CENTER:
			size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
			size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
		Control.PRESET_CENTER_RIGHT:
			size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
			size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
		Control.PRESET_BOTTOM_LEFT:
			size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
		Control.PRESET_CENTER_BOTTOM:
			size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
			size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
		Control.PRESET_BOTTOM_RIGHT:
			size_flags_horizontal = Control.SIZE_SHRINK_END
			size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND


func set_position_over_node() -> void:
	if anchor_node:
		var up_node = anchor_node.get_node_or_null("%Up")
		var p: Vector2
		if up_node:
			p = up_node.get_global_transform_with_canvas().origin
		else:
			p = anchor_node.get_global_transform_with_canvas().origin
		position = p - Vector2(size.x * 0.5, size.y) * scale


func get_parameters(index: int, _parameters: Dictionary) -> Dictionary:
	var parameters = {}
	parameters.length = _parameters.get("length", 8.0)
	match index:
		0:
			parameters.fade_time = _parameters.get("fade_time", 0.3)
		1:
			parameters.intensity = _parameters.get("intensity", 8.0)
		2:
			parameters.cursor = _parameters.get("cursor", "┃")
			parameters.use_text_color = _parameters.get("use_text_color", false)
			parameters.color = _parameters.get("color", Color.GREEN_YELLOW)
		3:
			parameters.ember = _parameters.get("ember", ".")
			parameters.color = _parameters.get("color", Color.RED)
			parameters.scale = _parameters.get("scale", 16.0)
		4:
			parameters.pow = _parameters.get("pow", 2.0)
		5:
			parameters.freq = _parameters.get("freq", 1.0)
			parameters.scale = _parameters.get("scale", 1.0)
	
	return parameters


func set_initial_config(config: Dictionary) -> void:
	initial_config = config
	is_floating = initial_config.get("is_floating_dialog", false)
	instant_text_enabled = initial_config.get("ignore_letter_by_letter", false)
	force_no_wait_for_input = initial_config.get("no_wait_for_input", false)
	#if is_floating:
		#instant_text_enabled = true
	anchor_node = initial_config.get("anchor_node", null)
	if is_floating:
		%BackgroundContainer.set("theme_override_constants/margin_left", 0)
		%BackgroundContainer.set("theme_override_constants/margin_top", 0)
		%BackgroundContainer.set("theme_override_constants/margin_right", 0)
		%BackgroundContainer.set("theme_override_constants/margin_bottom", 0)
		%DialogMainContainer.set("theme_override_constants/margin_left", 20)
		%DialogMainContainer.set("theme_override_constants/margin_top", 16)
		%DialogMainContainer.set("theme_override_constants/margin_right", 20)
		%DialogMainContainer.set("theme_override_constants/margin_bottom", 26)
		%NameContainer.visible = false
		z_index = 1000


func clear_text() -> void:
	message.text = ""


func _get_initial_config_commands() -> String:
	var commands = ""
	var pos_val = initial_config.get("position", 0)
	
	var face_data = initial_config.get("face")
	if face_data:
		var path = ""
		var region = ""
		
		if face_data is RPGIcon:
			path = face_data.path
			if face_data.region.has_area():
				region = " region=\"%d,%d,%d,%d\"" % [
					face_data.region.position.x, face_data.region.position.y,
					face_data.region.size.x, face_data.region.size.y
				]
		elif face_data is String and not face_data.is_empty():
			path = face_data
		
		if not path.is_empty():
			commands += "[face path=\"%s\"%s position=%d]" % [path, region, pos_val]

	var name_data = initial_config.get("character_name")
	if name_data and name_data is Dictionary:
		var type = name_data.get("type", 0)
		var val = name_data.get("value", "")
		
		if str(val) != "" and str(val) != "0":
			commands += "[showbox type=%s val=\"%s\" pos=%d]" % [type, val, pos_val]

	return commands


func setup_text(text: String, use_soft_reset: bool = false, is_additional_text: bool = false) -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if not instant_text_enabled: busy_until_resume = true
	
	if !use_soft_reset:
		reset()
		if not text.is_empty():
			var init_cmds = _get_initial_config_commands()
			if not init_cmds.is_empty():
				text = init_cmds + text
	else:
		soft_reset()
	
	await get_tree().process_frame
	
	if !use_soft_reset:
		setup_paragraphs(text)

	if paragraphs.is_empty(): return
	
	text = paragraphs.pop_front()
	text = text.strip_edges()

	if speaker_text_color != Color.TRANSPARENT:
		text = "[color=#%s]" % speaker_text_color.to_html() + text + "[/color]"
	text = parse_text(text)
	
	modulate.a = 0.0
	message.text = text
	
	if message.get_parsed_text().strip_edges().is_empty():
		for command in special_commands:
			if not command.completed:
				await start_special_command(command)
		if paragraphs.size() > 0:
			setup_text.call_deferred("", true, true)
		else:
			all_messages_finished.emit()
		return
	
	await precalculate_dialog_size(use_soft_reset)
	
	#if (!is_additional_text and is_new_dialog) or is_editor_prevew or Engine.is_editor_hint():
		#await precalculate_dialog_size(use_soft_reset)
	#if (!is_additional_text and is_new_dialog) or (Engine.is_editor_hint() and not use_soft_reset):
		#await precalculate_dialog_size()

	var current_lines = message.get_line_count()
	if current_lines > 1:
		# Ensure that words that do not fit on the same line have a line break added at the beginning.
		var indexes = []
		var current_line = 0
		var text_parsed = message.get_parsed_text()
		for i in range(1, text.length(), 1):
			var letter_line = message.get_character_line(i)
			if letter_line != current_line and letter_line != -1:
				current_line = letter_line
				if text_parsed[i - 1] != "\n":
					indexes.append(i)
		for i in range(indexes.size() - 1, -1, -1):
			# Search the original text for the correct position, adding an offset
			# that increments as bbcodes are encountered.
			#var bbcode_found = 0
			var count = 0
			var offset = 0
			for j in range(0, text.length(), 1):
				if text[j] == "[":
					var current_bbcode = try_select_bbcode(text, j + 1)
					if current_bbcode.length() > 0:
						offset += current_bbcode.length()
					else:
						offset += text[j].length()
				else:
					if count == indexes[i] + offset:
						var character = "\n"
						text = text.insert(indexes[i] + offset, character)
						var insertion_visual_point = indexes[i]
						for command in special_commands:
							if command.start >= insertion_visual_point:
								command.start += 1
						offset += character.length()
						break
					else:
						count += 1

	text = text.replace("  ", " ")
	message.text = text

	message.visible_characters = 0
	if use_soft_reset:
		modulate.a = 1.0

	max_characters = message.get_parsed_text().length()
	var player = %TypeWritePlayer
	player.stream = current_text_fx
	player.volume_db = current_text_fx_volume
	
	if is_floating:
		player.stop()
	
	if force_no_wait_for_input:
		wait_for_input_enabled = false
	if !use_soft_reset:
		show_open_animation()
	else:
		busy = false
		await show_next_character()
		if instant_text_enabled:
			message.set_deferred("visible_characters", -1)
		
	busy_until_resume = false
	
	message_started.emit()


## Splits the text into paragraphs based on the [p] tag and message_max_lines.
func setup_paragraphs(text: String) -> void:
	paragraphs.clear()
	
	# Split by [p] first to respect explicit page breaks (hard split).
	var raw_sections = text.split("[p]")
	
	for section in raw_sections:
		var clean_section = section.strip_edges()
		
		if clean_section.is_empty():
			continue
		
		# If there is no line limit, simply add the section.
		if message_max_lines <= 0:
			paragraphs.append(clean_section)
			continue
		
		# Process automatic breaks based on max lines (soft split).
		var lines = clean_section.split("\n")
		var current_block = ""
		var line_count = 0
		
		for i in lines.size():
			var line = lines[i]
			
			current_block += line + "\n"
			line_count += 1
			
			# If we reached the limit and it is not the last line, cut here.
			if line_count >= message_max_lines and i < lines.size() - 1:
				paragraphs.append(current_block.strip_edges())
				current_block = ""
				line_count = 0
		
		# Add any remaining text from the block.
		if not current_block.strip_edges().is_empty():
			paragraphs.append(current_block.strip_edges())
	
	balance_bbcode_paragraphs()


func get_speaker_commands(speaker_id: int) -> String:
	var new_text = "\n"
	if RPGSYSTEM.database.speakers.size() > speaker_id:
		var speaker: RPGSpeaker
		var node = Engine.get_main_loop().root.get_node_or_null("main_database")
		if node:
			speaker = node.data
		else:
			speaker = RPGSYSTEM.database.speakers[speaker_id]
		if speaker:
			# start speaker command
			# this command is called to cache the current text color for use
			# in another paragraph if the character continues to speak and has not been deleted.
			var color = speaker.text_color.to_html()
			
			var spekaer_position = speaker.character_position
			
			new_text += "[speaker_entry color=\"#%s\" speaker_id=%s _is_script_command=true]" % [color, speaker_id]
			
			if not speaker.font_name.is_empty(): new_text += "[font=\"%s\"]" % speaker.font_name
			
			new_text += "[font_size=%s]" % speaker.font_size
			
			if speaker.text_bold: new_text += "[b]"
			
			if speaker.text_italic: new_text += "[i]"
			
			# Command Name
			var name_data = speaker.name
			var type = name_data.get("type", 0)
			var val = name_data.get("val", 0)
			new_text += "[showbox type=%s val=\"%s\" pos=%s _is_script_command=true]" % [type, val, spekaer_position]
			
			# Command Face
			speaker.face.position = spekaer_position
			new_text += get_image_or_face_command(speaker.face)
			
			# Command Character
			speaker.character.character_linked_to = val + 1
			new_text += get_image_or_face_command(speaker.character)
			
			# Letter-By-Letter Sound
			if ResourceLoader.exists(speaker.text_fx.filename):
				var arg1 = "path=\"%s\"" % speaker.text_fx.filename
				var arg2 = "" if speaker.text_fx.volume_db == 0.0 else " volume=%s" % speaker.text_fx.volume_db
				var arg3 = "" if speaker.text_fx.pitch_scale == 1.0 else " pitch=%s" % speaker.text_fx.pitch_scale
				var arg4 = "" if speaker.text_fx.random_pitch_scale == 1.0 else " pitch2=%s" % speaker.text_fx.random_pitch_scale
				var bbcode = "[blip %s%s%s%s _is_script_command=true]" % [arg1, arg2, arg3, arg4]
				new_text += bbcode
			
			# Text Color
			new_text += "[color=\"#%s\"]" % speaker.text_color.to_html()
			
			# End block for this speaker, name and images wiil be cached beetween tags speaker_entry and speaker_entry_end
			new_text += "[speaker_entry_end speaker_id=%s _is_script_command=true]" % speaker_id

	return new_text


func get_hide_speaker_commands(speaker_id: int) -> String:
	var new_text = ""
	if RPGSYSTEM.database.speakers.size() > speaker_id:
		var speaker: RPGSpeaker = RPGSYSTEM.database.speakers[speaker_id]
		if speaker:
			# end speaker command
			# this command is called to delete the color that has been
			# saved in the cache variable when entering the character
			new_text = "[speaker_exit _is_script_command=true]"
			
			# add close command in reverse order
			
			new_text += "[/color]"
				
			if speaker.character.get("path", ""):
				new_text += "[img_remove type=1 id=%s _is_script_command=true]" % speaker.character.image_id
				
			if speaker.face.get("path", ""):
				new_text += "[img_remove type=0 id=%s _is_script_command=true]" % speaker.face.position
				
			new_text += "[hidebox=%s _is_script_command=true]" % speaker.name.pos
			
			if ResourceLoader.exists(speaker.text_fx.filename):
				var arg1 = "" if !text_fx else "path=\"%s\"" % text_fx.resource_path
				var arg2 = " volume=%s" % text_fx_volume
				var arg3 = " pitch=%s" % text_fx_min_pitch
				var arg4 = " pitch2=%s" % text_fx_max_pitch
				new_text += "[blip %s%s%s%s _is_script_command=true]" % [arg1, arg2, arg3, arg4]
			
			if speaker.text_bold: new_text += "[/b]"
			
			if speaker.text_italic: new_text += "[/i]"
			
			new_text += "[/font_size]"
			
			new_text += "[/font]"

	return new_text


func get_image_or_face_command(img: Dictionary) -> String:
	var bbcode: String = ""
	var d0 = img.get("path", RPGIcon)
	var d1 = img.get("trans_type", 0)
	var d2 = img.get("trans_time", 0)
	var d3 = img.get("trans_wait", 0)
	var d4 = img.get("width", 0)
	var d5 = img.get("height", 0)
	var d6 = img.get("position", 0)
	var d7 = img.get("image_type", 0)
	var d8 = img.get("image_id", 0)
	var d9 = img.get("start_position", 0)
	var d10 = img.get("idle_animation", 0)
	var d11 = img.get("is_speaker", false)
	var d12 = img.get("image_offset", Vector2i.ZERO)
	var d13 = ""
	# 0 = no link, 1 = link to character left, 2 = link to character right
	var d14 = img.get("character_linked_to", 0)
	if d0 is RPGIcon:
		if d0.region:
			d13 = " region=\"%s,%s,%s,%s\"" % [
				int(d0.region.position.x),
				int(d0.region.position.y),
				int(d0.region.size.x),
				int(d0.region.size.y)
			]
		d0 = d0.path
	if d0:
		if d7 == 0: # face
			var arg1 = "" if d1 == 0 else " trans_type=%s" % d1
			var arg2 = "" if !arg1 else " trans_time=%s" % d2
			var arg3 = "" if !arg1 else " trans_wait=%s" % d3
			var arg4 = "" if d4 == 0 and d5 == 0 else " size=%s" % d4
			var arg5 = "" if d5 == 0 else "x%s" % d5
			var arg6 = "" if d11 == false else " is_character=%s" % d11
			if d6 == 0:
				bbcode = "[face path=\"%s\"%s" % [d0, d13]
			else:
				bbcode = "[face path=\"%s\"%s position=1" % [d0, d13]
			bbcode += arg1 + arg2 + arg3 + arg4 + arg5 + arg6 + "]"
		elif d7 == 1: # Background Character
			var arg1 = "path=\"%s\"" % d0
			var arg2 = "" if d8 == 0 else " id=%s" % d8
			var dir = [
				"left", "center", "right",
				"bottom_left_screen", "bottom_center_screen", "bottom_right_screen",
				"top_left_screen", "top_center_screen", "top_right_screen",
				"left_screen", "right_screen", "custom"
				][d9]
			var arg3 = "" if d9 == 0 else " position=\"%s\"" % dir
			var arg4 = "" if d1 == 0 else " trans_type=%s" % d1
			var arg5 = "" if !arg4 else " trans_time=%s" % d2
			var arg6 = "" if !arg4 else " trans_wait=%s" % d3
			var arg7 = "" if d4 == 0 and d5 == 0 else " size=%s" % d4
			var arg8 = "" if d5 == 0 else "x%s" % d5
			var arg9 = "" if d10 == 0 else " idle_animation=%s" % d10
			var arg10 = "" if d11 == false else " is_character=%s" % d11
			var arg11 = "" if d12 == Vector2i.ZERO else " image_offset=%s" % "%sx%s" % [d12.x, d12.y]
			var arg12 = " character_linked_to=%s" % d14 if d14 != 0 else ""
			bbcode = "[character %s%s%s%s%s%s%s%s%s%s%s%s]" % [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12]
	
	return bbcode


func get_reset_commands() -> String:
	var new_text = ""
	
	return new_text


func balance_bbcode_paragraphs():
	var valid_codes = [
		"b", "i", "u", "s", "code", "char", "p", "center", "left", "right",
		"fill", "indent", "url", "hint", "font", "font_size", "color",
		"bg_color", "fgcolor", "outline_size", "outline_color",
		"pulse", "wave", "tornado", "shake", "fade", "woo",
		"uwu", "sparkle", "rain", "number", "nervous", "l33t", "jump",
		"heart", "cuss", "colormod", "ghost", "rainbow",
		"transition_fade", "bounce", "console", "embers", "energize",
		"glitch", "prickle", "redacted", "wfc", "word"
	]

	var i = 0
	var regex_open = RegEx.new()
	var regex_close = RegEx.new()
	regex_open.compile(r"\[(\w+)(=*[^\]]+)?\]") # Capturar etiquetas abiertas
	regex_close.compile(r"\[\/(\w+)\]") # Capturar etiquetas cerradas
	while i < paragraphs.size():
		var paragraph = paragraphs[i]

		var open_stack = [] # Etiquetas abiertas sin cerrar

		# Detectar etiquetas abiertas
		for match in regex_open.search_all(paragraph):
			var tag_name = match.get_string(1)
			var tag_param = match.get_string(2)
			if tag_name in valid_codes:
				open_stack.append({"tag_name": tag_name, "tag_param": tag_param})

		# Detectar etiquetas cerradas
		for match in regex_close.search_all(paragraph):
			var tag_name = match.get_string(1)
			if tag_name in valid_codes:
				# Si esta etiqueta ya está abierta, elimínala de la pila
				for j in range(open_stack.size() - 1, -1, -1):
					if open_stack[j]["tag_name"] == tag_name:
						open_stack.remove_at(j)
						break

		# Cerrar etiquetas abiertas restantes al final del párrafo
		for j in range(open_stack.size() - 1, -1, -1):
			var tag = open_stack[j]
			paragraph += "[/" + tag["tag_name"] + "]"

		# Propagar etiquetas abiertas al siguiente párrafo
		if i < paragraphs.size() - 1 and open_stack.size() > 0:
			var next_paragraph = paragraphs[i + 1]
			for j in range(open_stack.size() - 1, -1, -1):
				var tag = open_stack[j]
				var tag_name = tag["tag_name"]
				var tag_param = tag["tag_param"]
				next_paragraph = "[" + tag_name + tag_param + "]" + next_paragraph
			paragraphs[i + 1] = next_paragraph

		# Actualizar el párrafo actual
		paragraphs[i] = paragraph
		i += 1


func fix_tags(text: String) -> String:
	#print("Dirty text: ", text)
	# Lista de etiquetas válidas
	var valid_tags = ["font", "font_size", "s", "u", "i", "b", "color", "bgcolor", "pulse",
					 "woo", "uwu", "sparkle", "rain", "number", "nervous", "l33t", "jump",
					 "heart", "cuss", "colormod", "ghost", "rainbow", "fade", "shake",
					 "tornado", "wave", "transition_fade", "fill", "right", "center", "left"]
	
	var stack = [] # Pila para etiquetas abiertas
	var result = text # Texto resultante
	var offset = 0 # Offset para ajustar posiciones después de modificaciones
	
	# Regex para capturar etiquetas
	var regex = RegEx.new()
	regex.compile("\\[(\\/?)(\\w+)([^\\]]*)?\\]")
	
	# Procesar todas las etiquetas
	var matches = regex.search_all(text)
	for m in matches:
		var full_tag = m.get_string()
		var is_closing = m.get_string(1) == "/"
		var tag_type = m.get_string(2)
		var tag_start = m.get_start()
		
		if tag_type in valid_tags:
			if is_closing:
				# Si es una etiqueta de cierre
				if stack.size() > 0:
					var last_tag = stack.back()
					if last_tag.type != tag_type:
						# Si la etiqueta de cierre no corresponde con la última abierta,
						# la eliminamos y añadiremos la correcta más tarde
						var pos = tag_start + offset
						result = result.substr(0, pos) + result.substr(pos + full_tag.length())
						offset -= full_tag.length()
					else:
						# Si corresponde, la mantenemos y quitamos la última del stack
						stack.pop_back()
				else:
					# Si no hay etiquetas abiertas, eliminar la etiqueta de cierre
					var pos = tag_start + offset
					result = result.substr(0, pos) + result.substr(pos + full_tag.length())
					offset -= full_tag.length()
			else:
				# Si es una etiqueta de apertura, la añadimos al stack
				stack.append({
					"type": tag_type,
					"full_tag": full_tag,
					"start": tag_start
				})
	
	# Añadir las etiquetas de cierre faltantes en orden inverso
	for i in range(stack.size() - 1, -1, -1):
		result += "[/" + stack[i].type + "]"
	
	#print("Clean text: ", result)
	return result


func precalculate_dialog_size(is_soft_reset: bool = false) -> void:
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	message.visible_characters = -1

	message.custom_minimum_size = Vector2(message_max_width, 0)
	message.size = Vector2(message_max_width, 0)

	custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO

	if not is_floating:
		for command in special_commands:
			if command.name == "showbox":
				start_command_showbox(command, true)
			elif command.name == "face":
				start_command_face(command, true)

	await get_tree().process_frame
	var content_width = message.get_content_width()
	var content_height = message.get_content_height()

	var final_width = max(minimun_dialog_width, min(content_width, message_max_width))
	var final_height = max(minimun_dialog_height, content_height)

	var real_size = Vector2(final_width, final_height) + Vector2(4, 8)

	message.custom_minimum_size = real_size
	message.size = real_size

	if not is_soft_reset:
		%NameLeftContainer.modulate.a = 0.0
		%NameRightContainer.modulate.a = 0.0
		%LeftIconFace.modulate.a = 0.0
		%RightIconFace.modulate.a = 0.0

	custom_minimum_size = real_size
	size = real_size

	message.pivot_offset = message.size * 0.5
	pivot_offset = size * 0.5

	message.visible_characters = 0


func get_final_text(text: String) -> String:
	var final_text: String = ""
	var length = start_transition_parameters.get("length", 8.0)
	
	# Text color
	final_text = "[color=\"#%s\"]%s[/color]" % [default_text_color.to_html(), text]
	
	# Align
	var align = "" if default_text_align == 0 else "center" if default_text_align == 1 else "right"
	if align:
		final_text = "[%s]%s[/%s]" % [align, final_text, align]
	
	# Text size
	final_text = "[font_size=%s]%s[/font_size]" % [default_text_size, final_text]
	
	# Font
	if default_font:
		final_text = "[font=\"%s\"]%s[/font]" % [default_font, final_text]
	else:
		final_text = "[font=\"%s\"]%s[/font]" % [DEFAULTFONT, final_text]
	
	# Start Animation Text
	match start_transition_id:
		1:
			var a = start_transition_parameters.get("intensity", 8.0)
			final_text = "[bounce id=bounce length=%s intensity=%s]%s[/bounce]" % [length, a, final_text]
		2:
			var a = start_transition_parameters.get("cursor", "┃")
			var b = start_transition_parameters.get("use_text_color", false)
			var c = (start_transition_parameters.get("color", Color.GREEN_YELLOW)).to_html()
			if b:
				final_text = "[console id=console length=%s cursor=%s]%s  [/console]" % [length, a, final_text]
			else:
				final_text = "[console id=console length=%s cursor=%s color=%s]%s  [/console]" % [length, a, c, final_text]
		3:
			var a = start_transition_parameters.get("ember", ".")
			var b = (start_transition_parameters.get("color", Color.RED)).to_html()
			var c = start_transition_parameters.get("scale", 16.0)
			final_text = "[embers id=embers length=%s ember=%s color=%s scale=%s]%s[/embers]" % [length, a, b, c, final_text]
		4:
			var a = start_transition_parameters.get("pow", 2.0)
			final_text = "[prickle id=prickle length=%s pow=%s]%s[/prickle]" % [length, a, final_text]
		5:
			var a = start_transition_parameters.get("freq", 1.0)
			var b = start_transition_parameters.get("scale", 1.0)
			final_text = "[redacted id=redacted length=%s freq=%s scale=%s]%s[/redacted]" % [length, a, b, final_text]
		6:
			final_text = "[wfc id=wfc]%s[/wfc]" % final_text
		7:
			final_text = "[word id=word]%s[/word]" % final_text
		_:
			if max_character_delay != 0:
				var a = start_transition_parameters.get("fade_time", 0.3)
				final_text = "[transition_fade duration=%s]%s[/transition_fade]" % [a, final_text]
		
	return final_text


func show_open_animation() -> void:
	if !is_new_dialog:
		await show_next_character()
		dialog_is_started = true
		return
	
	if tweens.message:
		tweens.message.kill()
	
	var animations = [
		"none", "Fade-In", "Fade-In + Horizontal Grow", "Fade-In + Vertical Grow",
		"Fade-In + Grow", "Horizontal Grow", "Vertical Grow", "Grow",
		"Move Left To Right", "Move Left To Right + Fade-In",
		"Move Right To Left", "Move Right To Left + Fade-In"
	]
	
	var current_animation = animations[clamp(start_animation_id, 0, animations.size() - 1)]
	
	var node = self
	node.modulate.a = 1.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE
	
	await get_tree().process_frame
	
	if current_animation != "none":
		var t = start_animation_duration
		tweens.message = create_tween()
		var trans_type = [
			Tween.TRANS_LINEAR, Tween.TRANS_SINE, Tween.TRANS_QUINT, Tween.TRANS_QUART,
			Tween.TRANS_QUAD, Tween.TRANS_EXPO, Tween.TRANS_ELASTIC, Tween.TRANS_CUBIC,
			Tween.TRANS_CIRC, Tween.TRANS_BOUNCE, Tween.TRANS_BACK, Tween.TRANS_SPRING
		][start_animation_trans_type]
		var trans_ease = [
			Tween.EASE_IN, Tween.EASE_OUT, Tween.EASE_IN_OUT, Tween.EASE_OUT_IN
		][start_animation_ease_type]
		tweens.message.set_trans(trans_type)
		tweens.message.set_ease(trans_ease)
		tweens.message.set_parallel(true)
		
		if current_animation.find("Fade-In") != -1:
			node.modulate.a = 0.0
			tweens.message.tween_property(node, "modulate:a", 1.0, t).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
			
		if ["Fade-In + Horizontal Grow", "Fade-In + Grow", "Horizontal Grow", "Grow"].has(current_animation):
			node.scale.x = 0.25
			tweens.message.tween_property(node, "scale:x", 1.0, t)
			
		if ["Fade-In + Vertical Grow", "Fade-In + Grow", "Vertical Grow", "Grow"].has(current_animation):
			node.scale.y = 0.25
			tweens.message.tween_property(node, "scale:y", 1.0, t)
			
		if ["Move Left To Right", "Move Left To Right + Fade-In"].has(current_animation):
			var current_position_x = node.position.x
			node.position.x = - node.size.x
			tweens.message.tween_property(node, "position:x", current_position_x, t)
			
		if ["Move Right To Left", "Move Right To Left + Fade-In"].has(current_animation):
			var current_position_x = node.position.x
			node.position.x = get_viewport().size.x
			tweens.message.tween_property(node, "position:x", current_position_x, t)
			
		tweens.message.set_parallel(false)
		tweens.message.tween_callback(
			func():
				await show_next_character()
				set("dialog_is_started", true)
				if instant_text_enabled:
					message.set_deferred("visible_characters", -1)
		)
	else:
		await show_next_character()
		dialog_is_started = true


func show_close_animation() -> void:
	if waiting_for_input:
		return
		
	if is_new_dialog or is_multi_dialog:
		await get_tree().process_frame
		all_messages_finished.emit()
		return
	
	if tweens.message:
		tweens.message.kill()
	
	var animations = [
		"none", "Fade-Out", "Fade-Out + Sink",
		"Move To Left", "Move To Left + Fade-Out",
		"Move To Right", "Move To Right + Fade-Out",
	]
	
	var current_animation = animations[clamp(end_animation_id, 0, animations.size() - 1)]
	
	if current_animation != "none":
		closing.emit()
		
		var node = self
		
		var t = max(get_process_delta_time(), end_animation_duration)
		tweens.message = create_tween()
		var trans_type = [
			Tween.TRANS_LINEAR, Tween.TRANS_SINE, Tween.TRANS_QUINT, Tween.TRANS_QUART,
			Tween.TRANS_QUAD, Tween.TRANS_EXPO, Tween.TRANS_ELASTIC, Tween.TRANS_CUBIC,
			Tween.TRANS_CIRC, Tween.TRANS_BOUNCE, Tween.TRANS_BACK, Tween.TRANS_SPRING
		][end_animation_trans_type]
		var trans_ease = [
			Tween.EASE_IN, Tween.EASE_OUT, Tween.EASE_IN_OUT, Tween.EASE_OUT_IN
		][end_animation_ease_type]
		tweens.message.set_trans(trans_type)
		tweens.message.set_ease(trans_ease)
		tweens.message.set_parallel(true)
		
		if current_animation.find("Fade-Out") != -1:
			tweens.message.tween_property(node, "modulate:a", 0.0, t).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
			
		if current_animation.find("Sink") != -1:
			node.pivot_offset = node.size * 0.5
			tweens.message.tween_property(node, "scale", Vector2(0.15, 0.15), t)
		
		if current_animation.find("Left") != -1:
			tweens.message.tween_property(node, "position:x", -node.size.x, t)
		
		if current_animation.find("Right") != -1:
			tweens.message.tween_property(node, "position:x", get_viewport().size.x, t)
		
		tweens.message.tween_callback(
			func():
				all_messages_finished.emit()
				if not is_multi_dialog:
					reset()
		).set_delay(t)
	else:
		await get_tree().process_frame
		all_messages_finished.emit()
	
	wait_for_user_option_selected_enabled = false
	dialog_is_paused = false


func start_command_character(command: SpecialEffectCommand) -> void:
	if is_floating: return
	if "path" in command.parameters and ResourceLoader.exists(command.parameters.path):
		var is_speaker: bool = command.parameters.get("is_character", false)
		var id = int(command.parameters.get("id", 0))
		var image_position = command.parameters.get("position", "left")
		var start_position = [
			"left", "center", "right",
			"bottom_left_screen", "bottom_center_screen", "bottom_right_screen",
			"top_left_screen", "top_center_screen", "top_right_screen",
			"left_screen", "right_screen",
		].find(image_position.to_lower())
		var idle_animation = int(command.parameters.get("idle_animation", 0))
		
		for bg in images:
			if bg.id == id:
				bg.kill()
				images.erase(bg)
				break
				
		var img = load(command.parameters.path)
		var t: TextureRect
		var current_bg: BackgroundImage
				
		if img is PackedScene:
			t = img.instantiate()
			if !t is TextureRect:
				return
			img = t.texture
		elif img is Texture:
			t = BACKGROUND_IMAGE.instantiate()
		else:
			return
			
		t.item_rect_changed.connect(func(): message_childs_changed.emit())
		t.texture = img
			
		var s = str(command.parameters.size) if "size" in command.parameters else ""
		var w = int(s.get_slice("x", 0)) if s else img.get_width()
		var h = int(s.get_slice("x", 1)) if s else img.get_height()
		if w == 0: w = img.get_width()
		if h == 0: h = img.get_height()
		var image_size = Vector2(w, h)
		
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size = Vector2.ZERO
		t.custom_minimum_size = image_size
		t.flip_h = command.parameters.get("flip_h", 0) == 1
		t.flip_v = command.parameters.get("flip_v", 0) == 1

		#if image_position == "center":
			#t.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		#elif image_position == "right":
			#t.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		#elif image_position == "left":
			#t.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		#else:
			#t.set_anchors_preset(Control.PRESET_TOP_LEFT)
			
		t.pivot_offset = image_size * 0.5
		
		if character_container:
			character_container.add_child(t)
		
		var image_offset = command.parameters.get("image_offset", "0x0").split("x")
		var current_offset: Vector2 = Vector2.ZERO
		if image_offset.size() == 2:
			current_offset = Vector2(int(image_offset[0]), (int(image_offset[1])))
			t.global_position += current_offset

		var trans_end = command.parameters.get("trans_type_end", 0)
		var trans_end_time = command.parameters.get("trans_end_time", 0)
		var character_linked_to = command.parameters.get("character_linked_to", 0)
		current_bg = BackgroundImage.new(id, t, start_position, idle_animation, trans_end, trans_end_time, current_offset, character_linked_to)
		current_bg.deleted.connect(
			func():
				images.erase(current_bg)
		)
		images.append(current_bg)
		
		reposition_texture(current_bg)
		
		var target_pos_x = t.position.x
		
		var trans = command.parameters.trans_type if "trans_type" in command.parameters else 0
		var animation_time = command.parameters.trans_time if "trans_time" in command.parameters else 0
		var wait = command.parameters.trans_wait if "trans_wait" in command.parameters else 0
		if is_speaker:
			animation_time = 0.0

		if trans and animation_time:
			var tween = create_tween()
			match trans:
				2: # Move Left To Right (Entrada desde la izquierda - fuera de pantalla)
					t.position.x = -t.custom_minimum_size.x # Forzamos inicio fuera a la izquierda
					tween.tween_property(t, "position:x", target_pos_x, animation_time)
					
				3: # Move Right To Left (Entrada desde la derecha - fuera de pantalla)
					# Usamos el ancho del viewport para asegurar que sale de pantalla
					t.position.x = get_viewport_rect().size.x
					tween.tween_property(t, "position:x", target_pos_x, animation_time).from(get_viewport_rect().size.x)
					
				4: # Move To Left Position (Animación interna)
					var p = -t.custom_minimum_size.x * 0.5
					tween.tween_property(t, "position:x", p, animation_time)
					tween.tween_callback(t.set_anchors_preset.bind(Control.PRESET_BOTTOM_LEFT))
				5: # Move To Center Position (Animación interna)
					var p = %Message.size.x * 0.5 - t.custom_minimum_size.x * 0.5
					tween.tween_property(t, "position:x", p, animation_time)
					tween.tween_callback(t.set_anchors_preset.bind(Control.PRESET_CENTER_BOTTOM))
				6: # Move To Right Position (Animación interna)
					var p = %Message.size.x - t.custom_minimum_size.x * 0.5
					tween.tween_property(t, "position:x", p, animation_time)
					tween.tween_callback(t.set_anchors_preset.bind(Control.PRESET_BOTTOM_RIGHT))
				_: # Fade In por defecto
					if trans != 0:
						t.modulate.a = 0.0
						tween.tween_property(t, "modulate:a", 1.0, animation_time)
			
			tween.tween_callback(current_bg.start_idle_animation)
			
			# Asegurar posición Y correcta si se guardó meta (importante para floats)
			if t.has_meta("start_position"):
				t.position.y = t.get_meta("start_position").y
				
			if wait:
				message_childs_changed.emit()
				busy = true
				await tween.finished
				busy = false
		else:
			current_bg.start_idle_animation()
			await get_tree().process_frame
			message_childs_changed.emit()


func reposition_texture(image: BackgroundImage) -> void:
	var t = image.image
	var image_position = [
			"left", "center", "right",
			"bottom_left_screen", "bottom_center_screen", "bottom_right_screen",
			"top_left_screen", "top_center_screen", "top_right_screen",
			"left_screen", "right_screen", "custom"
		][image.start_position]
	var obj = character_container
	if not obj:
		obj = self
	var m = %Message
	if t.texture:
		var screen_size = obj.size
		var image_size = t.size
		if image_position == "left":
			t.global_position = Vector2(
				m.global_position.x,
				m.global_position.y + m.size.y - image_size.y
			)
		elif image_position == "center":
			t.global_position = Vector2(
				m.global_position.x + m.size.x * 0.5 - image_size.x * 0.5,
				m.global_position.y + m.size.y - image_size.y
			)
		if image_position == "right":
			t.global_position = Vector2(
				m.global_position.x + m.size.x - image_size.x,
				m.global_position.y + m.size.y - image_size.y
			)
		elif image_position == "bottom_left_screen":
			t.global_position = Vector2(
				0,
				screen_size.y - image_size.y
			)
		elif image_position == "bottom_center_screen":
			t.global_position = Vector2(
				screen_size.x * 0.5 - image_size.x * 0.5,
				screen_size.y - image_size.y
			)
		elif image_position == "bottom_right_screen":
			t.global_position = Vector2(
				screen_size.x - image_size.x,
				screen_size.y - image_size.y
			)
		elif image_position == "top_left_screen":
			t.global_position = Vector2(
				0,
				0
			)
		elif image_position == "top_center_screen":
			t.global_position = Vector2(
				screen_size.x * 0.5 - image_size.x * 0.5,
				0
			)
		elif image_position == "top_right_screen":
			t.global_position = Vector2(
				screen_size.x - image_size.x,
				0
			)
		elif image_position == "left_screen":
			t.global_position = Vector2(
				0,
				screen_size.y * 0.5 - image_size.y * 0.5
			)
		elif image_position == "right_screen":
			t.global_position = Vector2(
				screen_size.x - image_size.x,
				screen_size.y * 0.5 - image_size.y * 0.5
			)

	if image_position != "custom":
		t.global_position += image.current_offset
	else:
		t.global_position = image.current_offset


func start_command_face(command: SpecialEffectCommand, force_run: bool = false) -> void:
	if is_floating and not force_run: return
	
	if "path" in command.parameters:
		if ResourceLoader.exists(command.parameters.path):
			var region_data = command.parameters.get("region", "0,0,0,0").split(",")
			var region = Rect2(int(region_data[0]), int(region_data[1]), int(region_data[2]), int(region_data[3]))
			var is_speaker = command.parameters.get("is_character", false)
			var img
			
			## FIX: "if region:" is always true for Rect2. We must check if it has dimensions.
			if region.has_area():
				img = AtlasTexture.new()
				img.atlas = load(command.parameters.path)
				img.region = region
			else:
				img = load(command.parameters.path)
				
			var obj = %LeftIconFace
			if "position" in command.parameters and command.parameters.position == 1:
				obj = %RightIconFace
			
			## Check if it is the same texture to avoid reloading/animating
			if (is_speaker and
				obj.get_texture() and
				((img is AtlasTexture and obj.get_texture() is AtlasTexture and obj.get_texture().atlas.resource_path == command.parameters.path and obj.get_texture().region == region) or
				(img is Texture2D and obj.get_texture().resource_path == command.parameters.path)) and
				obj.get_parent().get_parent().visible == true
			):
				var key = "left_face" if obj == %LeftIconFace else "right_face"
				var t: Tween = tweens.get(key)
				if (not t or (t and not t.is_valid())) and (obj.modulate.a != 1.0 or obj.scale != Vector2.ONE):
					pass
				else:
					return
				
			obj.get_parent().get_parent().visible = true
			
			if img is PackedScene:
				var img2 = img.instantiate()
				if !img2 is TextureRect:
					return
				img = img2.texture
				img2.queue_free()
			
			obj.texture = img
			
			if not force_run:
				obj.pivot_offset = obj.size / 2
				
				var trans = command.parameters.trans_type if "trans_type" in command.parameters else 0
				@warning_ignore("shadowed_variable")
				var time = command.parameters.trans_time if "trans_time" in command.parameters else 0
				var wait = command.parameters.trans_wait if "trans_wait" in command.parameters else 0
				if trans and time:
					var key = "left_face" if obj == %LeftIconFace else "right_face"
					if tweens[key]:
						tweens[key].kill()
					tweens[key] = create_tween()
					match trans:
						2: # Zoom In
							obj.modulate.a = 1.0
							obj.scale = Vector2(0.6, 0.6)
							tweens[key].tween_property(obj, "scale", Vector2.ONE, time)
						3: # Zoom Out
							obj.modulate.a = 1.0
							obj.scale = Vector2(1.4, 1.4)
							tweens[key].tween_property(obj, "scale", Vector2.ONE, time)
						_: # Fade In
							if trans != 0:
								obj.modulate.a = 0.0
								tweens[key].tween_property(obj, "modulate:a", 1.0, time)

					if wait:
						message_childs_changed.emit()
						busy = true
						await tweens[key].finished
						busy = false
				else:
					obj.scale = Vector2.ONE
					obj.modulate = Color.WHITE
			else:
				obj.modulate = Color.WHITE
					
			message_childs_changed.emit()


func start_command_highlight_character(command: SpecialEffectCommand) -> void:
	var p_mode = command.parameters.get("mode", 0)
	var p_pos = command.parameters.get("pos", 0)
	
	if highlight_character_tween:
		highlight_character_tween.kill()
	
	var name_left = %NameLeft
	var name_left_background = %NameLeftBackground
	var face_left = %LeftIconFace
	var name_right = %NameRight
	var name_right_background = %NameRightBackground
	var face_right = %RightIconFace
	
	highlight_character_tween = create_tween()
	highlight_character_tween.set_parallel(true)
	
	var modulation_left = Color.WHITE
	var modulation_right = Color.WHITE
	var attenuation_color = Color(0.565, 0.565, 0.565, 0.396)
	
	if p_mode == 0: # Enable highlight
		if p_pos == 0: # Highlight Left, Right attenuation
			modulation_right = attenuation_color
		else: # Highlight Right, Left attenuation
			modulation_left = attenuation_color
	
	highlight_character_tween.tween_property(name_left, "self_modulate", modulation_left, 0.35)
	highlight_character_tween.tween_property(name_left_background, "self_modulate", modulation_left, 0.35)
	highlight_character_tween.tween_property(face_left, "self_modulate", modulation_left, 0.35)
	highlight_character_tween.tween_property(name_right, "self_modulate", modulation_right, 0.35)
	highlight_character_tween.tween_property(name_right_background, "self_modulate", modulation_right, 0.35)
	highlight_character_tween.tween_property(face_right, "self_modulate", modulation_right, 0.35)
	
	for image in images:
		if image.character_linked_to == 0:
			continue

		var target_color = Color.WHITE

		if image.character_linked_to == 1:
			target_color = modulation_left
		elif image.character_linked_to == 2:
			target_color = modulation_right
			
		highlight_character_tween.tween_property(image.image, "self_modulate", target_color, 0.35)


func start_command_image_remove(command: SpecialEffectCommand) -> void:
	if is_floating: return
	if "type" in command.parameters:
		var id = int(command.parameters.type)
		if id == 0:
			var target_id = int(command.parameters.id) if "id" in command.parameters else 0
			if target_id == 0:
				%LeftIconFace.get_parent().get_parent().visible = false
			else:
				%RightIconFace.get_parent().get_parent().visible = false
		elif id == 1:
			var target_id = int(command.parameters.id) if "id" in command.parameters else 0
			var to_delete: Array = []
			for obj in images:
				if obj.id == target_id:
					obj.kill()
					to_delete.append(obj)
			for obj in to_delete:
				images.erase(obj)
		
		message_childs_changed.emit()


func start_command_imgfx(command: SpecialEffectCommand) -> void:
	if is_floating: return
	if "type" in command.parameters:
		var obj
		var obj_parent
		if command.parameters.type == 1:
			var id = 0 if !"id" in command.parameters else command.parameters.id
			for img in images:
				if img.id == id:
					obj = img.image
					obj_parent = img
					break
		else:
			obj = %LeftIconFace
			if "position" in command.parameters and command.parameters.position == 1:
				obj = %RightIconFace
		
		if obj:
			var use_tween = false
			if (
				"move" in command.parameters or "rotate" in command.parameters or
				"zoom" in command.parameters or "color" in command.parameters or
				"shake" in command.parameters
			):
				use_tween = true
				
			var duration = 0.25 if !"duration" in command.parameters else command.parameters.duration

			if use_tween:
				var eases = [Tween.EASE_IN, Tween.EASE_OUT, Tween.EASE_IN_OUT, Tween.EASE_OUT_IN]
				var types = [
					Tween.TRANS_LINEAR, Tween.TRANS_SINE, Tween.TRANS_QUINT, Tween.TRANS_QUART,
					Tween.TRANS_QUAD, Tween.TRANS_EXPO, Tween.TRANS_ELASTIC, Tween.TRANS_CUBIC,
					Tween.TRANS_CIRC, Tween.TRANS_BOUNCE, Tween.TRANS_BACK, Tween.TRANS_SPRING
				]
				var ease_type = eases[clamp(command.parameters.get("ease_type", 0), 0, eases.size() - 1)]
				var ease_transition = types[clamp(command.parameters.get("ease_transition", 0), 0, types.size() - 1)]
				
				var t = create_tween().bind_node(self).set_ease(ease_type).set_trans(ease_transition).set_parallel(true)
				
				if "move" in command.parameters:
					var x = int(command.parameters.move.get_slice(",", 0))
					var y = int(command.parameters.move.get_slice(",", 1))
					t.tween_property(obj, "position", obj.position + Vector2(x, y), duration)
					
				if "rotate" in command.parameters:
					var r = deg_to_rad(float(command.parameters.rotate))
					t.tween_property(obj, "rotation", obj.rotation + r, duration)
					
				if "zoom" in command.parameters:
					var zoom = float(command.parameters.zoom)
					t.tween_property(obj, "scale", obj.scale + Vector2(zoom, zoom), duration)
					
				if "color" in command.parameters:
					var color = command.parameters.color
					t.tween_property(obj, "modulate", color, duration)
					
				if "shake" in command.parameters:
					var magnitude = float(command.parameters.shake.get_slice(",", 0))
					var frequency = float(command.parameters.shake.get_slice(",", 1))
					var callable = _animate_shake_dialog.bind(obj, magnitude, frequency, obj.position)
					
					t.tween_method(callable, 0.0, 1.0, duration)
				
			if "transition_type" in command.parameters and command.parameters.type == 1 and command.parameters.transition_type > 0:
				var t = create_tween()
				match command.parameters.transition_type:
					1: # Fade Out
						t.tween_property(obj, "modulate:a", 0.0, duration)
					2: # Move To Left Position
						var p = - obj.custom_minimum_size.x * 0.5
						t.tween_property(obj, "position:x", p, duration)
						t.tween_callback(obj.set_anchors_preset.bind(Control.PRESET_BOTTOM_LEFT))
					3: # Move To Center Position
						var p = %Message.size.x * 0.5 - obj.custom_minimum_size.x * 0.5
						t.tween_property(obj, "position:x", p, duration)
						t.tween_callback(obj.set_anchors_preset.bind(Control.PRESET_CENTER_BOTTOM))
					4: # Move To Right Position
						var p = %Message.size.x - obj.custom_minimum_size.x * 0.5
						t.tween_property(obj, "position:x", p, duration)
						t.tween_callback(obj.set_anchors_preset.bind(Control.PRESET_BOTTOM_RIGHT))
					5: # Horizontal Flip
						obj.flip_h = !obj.flip_h
					6: # Jump
						var d1 = duration * 0.2
						var d2 = duration * 0.4
						var p1 = obj.position.y - 100
						obj.pivot_offset = Vector2(obj.size.x / 0.5, obj.size.y)
						t.tween_property(obj, "scale:y", 0.91, d1)
						t.tween_property(obj, "position:y", p1, d2)
						t.tween_property(obj, "position:y", obj.position.y, d1)
						t.tween_property(obj, "scale:y", 1.0, d1)
					7: # Zoom In - Out
						var d = duration / 2
						t.tween_property(obj, "scale:y", 1.2, d)
						t.tween_property(obj, "scale:y", 1.0, d)
					8: # Zoom Out - In
						var d = duration / 2
						t.tween_property(obj, "scale:y", 0.8, d)
						t.tween_property(obj, "scale:y", 1.0, d)
					_: # Fade In
						t.tween_property(obj, "modulate:a", 1.0, duration)
							
				
			if "wait" in command.parameters and command.parameters.wait:
				busy = true
				if not is_inside_tree(): return
				await get_tree().create_timer(duration).timeout
				if not is_instance_valid(self) or not is_inside_tree(): return
				busy = false
			
			if command.parameters.type == 1 and "idle_animation" in command.parameters:
				if command.parameters.idle_animation != 0:
					var id = clamp(command.parameters.idle_animation - 1, 0, 2)
					obj_parent.idle_animation = id
					obj_parent.start_idle_animation()


func start_command_showbox(command: SpecialEffectCommand, force_run: bool = false) -> void:
	if is_floating and not force_run: return
	if "type" in command.parameters and "val" in command.parameters and command.parameters.val:
		var pos = 0
		if "pos" in command.parameters:
			pos = int(command.parameters.pos)
		var obj = %NameLeftContainer if pos == 0 else %NameRightContainer

		var id = int(command.parameters.type)
		var character_name: String = ""
		if id == 0:
			character_name = str(command.parameters.val)
		elif id == 1:
			var actor_id = int(command.parameters.val)
			if RPGSYSTEM.database.actors.size() > actor_id:
				character_name = RPGSYSTEM.database.actors[actor_id].name
		elif id == 2:
			var enemy_id = int(command.parameters.val)
			if RPGSYSTEM.database.enemies.size() > enemy_id:
				character_name = RPGSYSTEM.database.enemies[enemy_id].name
		
		if character_name:
			var key: String
			if pos == 0:
				%NameLeft.text = str(character_name)
				key = "left_box"
			else:
				%NameRight.text = str(character_name)
				key = "right_box"
			obj.visible = true
			if not force_run:
				if tweens[key]:
					tweens[key].kill()
				obj.modulate.a = 0.0
				tweens[key] = create_tween()
				tweens[key].tween_property(obj, "modulate:a", 1.0, 0.15)
				message_childs_changed.emit()


func start_command_hidebox(command: SpecialEffectCommand) -> void:
	if is_floating: return
	if "value" in command.parameters:
		var v = int(command.parameters.value)
		if v == 0:
			%NameLeftContainer.visible = false
		elif v == 1:
			%NameRightContainer.visible = false
		
		message_childs_changed.emit()


func start_command_sound(command: SpecialEffectCommand) -> void:
	if "path" in command.parameters and ResourceLoader.exists(command.parameters.path):
		var stream: AudioStream = load(command.parameters.path)
		var volume_db: float = 0.0
		var pitch: float = 1.0
		if "volume" in command.parameters:
			volume_db = float(command.parameters.volume)
		if "pitch" in command.parameters:
			pitch = max(0.01, float(command.parameters.pitch))
		var player = AUTO_AUDIO_PLAYER.instantiate()
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = pitch
		add_child(player)
		player.play()
		sounds.append(player)
		player.tree_exiting.connect(func(): sounds.erase(player))


func start_command_wait(command: SpecialEffectCommand) -> void:
	busy = true
	var type: int = 0
	var seconds: float = 0.1
	if "type" in command.parameters:
		type = int(command.parameters.type)
	if "seconds" in command.parameters:
		seconds = float(command.parameters.seconds)
	if type == 0:
		if not is_inside_tree(): return
		command_waiting_enabled = true
		await get_tree().create_timer(seconds).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		busy = false
		command_waiting_enabled = false
	else:
		%AdvanceCursorContainer.show()
		waiting_for_input = true


func start_command_no_wait_input(command: SpecialEffectCommand) -> void:
	if is_floating: return
	var enabled = bool(int(command.parameters.enabled)) if "enabled" in command.parameters else false
	var _time = float(command.parameters.time) if "time" in command.parameters else 0.0
	force_no_wait_for_input = enabled
	wait_for_input_enabled = !enabled
	wait_for_input_time = _time
	command.completed = true


func start_command_show_whole_line(command: SpecialEffectCommand) -> void:
	var value = false
	if "value" in command.parameters:
		value = command.parameters.value == 1
		
	if !value: return
		
	while current_character < max_characters and %Message.get_parsed_text()[current_character] != "\n":
		current_character += 1
		var breakit = false
		for c in special_commands:
			if c.completed: continue
			if current_character > c.start:
				if c.name == "wait":
					command.completed = false
					breakit = true
					break
				elif c.name == "show_whole_line" and c.parameters.value == 0:
					breakit = true
					break
		if breakit:
			break


func start_command_dialog_shake(command: SpecialEffectCommand) -> void:
	var magnitude = 1.1
	var frequency = 120
	var duration = 0.25
	var wait = false
	if "magnitude" in command.parameters:
		magnitude = float(command.parameters.magnitude)
	if "frequency" in command.parameters:
		frequency = float(command.parameters.frequency)
	if "duration" in command.parameters:
		duration = float(command.parameters.duration)
	if "wait" in command.parameters:
		wait = int(command.parameters.wait) == 1
	var original_position: Vector2
	if has_meta("original_position"):
		original_position = get_meta("original_position")
	else:
		original_position = position
		set_meta("original_position", original_position)
	var callable = _animate_shake_dialog.bind(self, magnitude, frequency, original_position)
	var t = create_tween()
	t.tween_method(callable, 0.0, 1.0, duration)
	t.tween_property(self, "position", original_position, 0.0)
	t.tween_property(self, "position", original_position, 0.0)
	
	if wait:
		busy = true
		if not is_inside_tree(): return
		await get_tree().create_timer(duration).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		busy = false


func start_command_change_blip(command: SpecialEffectCommand) -> void:
	if is_floating: return
	
	var path = command.parameters.get("path", "")

	if ResourceLoader.exists(path):
		current_text_fx = load(path)
		current_text_fx_min_pitch = command.parameters.get("pitch", 1.0)
		current_text_fx_max_pitch = command.parameters.get("pitch2", 1.0)
		current_text_fx_volume = command.parameters.get("volume", 0.0)
		%TypeWritePlayer.stream = current_text_fx
		
	pass


func start_command_add_speaker(command: SpecialEffectCommand) -> void:
	if is_floating: return
	var speaker_id = command.parameters.get("speaker_id", 0)
	if speaker_id in speakers:
		for img in speakers[speaker_id].images:
			img.queue_free()
	speakers[speaker_id] = {
		"name": {"text": "", "pos": 0},
		"images": []
	}
	caching_speaker = true
	speaker_text_color = Color(command.parameters.get("color", "white"))


func start_command_add_speaker_end(command: SpecialEffectCommand) -> void:
	if is_floating: return
	caching_speaker = false
	
	var speaker_id = command.parameters.speaker_id
	
	if RPGSYSTEM.database.speakers.size() > speaker_id:
		var speaker: RPGSpeaker = RPGSYSTEM.database.speakers[speaker_id]
		if speaker and speaker.wait_on_finish > 0:
			busy = true
			if not is_inside_tree(): return
			await get_tree().create_timer(speaker.wait_on_finish).timeout
			if not is_instance_valid(self) or not is_inside_tree(): return
			busy = false


func start_command_remove_speaker(_command: SpecialEffectCommand) -> void:
	if is_floating: return
	speaker_text_color = Color.TRANSPARENT


func start_command_freeze() -> void:
	if is_floating: return
	current_character -= 1
	dialog_is_paused = true
	all_messages_finished.emit()


func start_special_command(command: SpecialEffectCommand) -> void:
	command.completed = true
	# Valid commands:
	#[
		#"character", "face", "imgfx", "img_remove", "showbox", "hidebox", "sound", "wait",
		#"no_wait_input", "show_whole_line", "dialog_shake"
	#]
	
	@warning_ignore_start("redundant_await")
	match command.name:
		"character": await start_command_character(command)
		"face": await start_command_face(command)
		"highlight_character": await start_command_highlight_character(command)
		"imgfx": await start_command_imgfx(command)
		"img_remove": await start_command_image_remove(command)
		"showbox": await start_command_showbox(command)
		"hidebox": await start_command_hidebox(command)
		"sound": await start_command_sound(command)
		"wait": await start_command_wait(command)
		"no_wait_input": await start_command_no_wait_input(command)
		"show_whole_line": await start_command_show_whole_line(command)
		"dialog_shake": await start_command_dialog_shake(command)
		"blip": await start_command_change_blip(command)
		"speaker_entry": await start_command_add_speaker(command)
		"speaker_entry_end": await start_command_add_speaker_end(command)
		"speaker_exit": await start_command_remove_speaker(command)
		"freeze": await start_command_freeze()


@warning_ignore("shadowed_variable", "unused_parameter")
func _animate_shake_dialog(time: float, node: Node, magnitude: float, frequency: float, original_position: Vector2) -> void:
	var x_offset = magnitude * sin(time * 2 * PI * frequency)
	var y_offset = magnitude * cos(time * 2 * PI * frequency)
	node.position += Vector2(x_offset, y_offset)


func show_next_character() -> void:
	var ignore_commands: bool = false
	if !busy_when_preview and delay_for_input <= 0 and skip_type != SkipMode.FAST_MESSAGE and Input.is_action_pressed("ui_select") and not is_floating:
		if !waiting_for_input and !busy:
			if skip_type == SkipMode.SHOW_ALL_IGNORE_COMMANDS:
				current_character = max_characters
				ignore_commands = true
				get_viewport().set_input_as_handled()
			elif skip_type == SkipMode.SHOW_ALL:
				current_character = max_characters
				get_viewport().set_input_as_handled()
		else:
			current_character += 1
	else:
		current_character += 1


	# Ensure view all characters if no delay beetween letters or instant_text_enabled is true
	if max_character_delay == 0 or instant_text_enabled:
		current_character = max_characters
	
	if !ignore_commands:
		# Use a loop to ensure that if a command pauses execution (wait), 
		# we re-check for remaining commands at this position immediately after the pause.
		while true:
			var command_executed_and_paused: bool = false
			for command in special_commands:
				if command.completed: continue
				
				if current_character > command.start:
					await start_special_command(command)
					
					if busy:
						command_executed_and_paused = true
						break
			
			while busy:
				await get_tree().process_frame
			
			if not command_executed_and_paused:
				break


	if paragraphs.is_empty() and instant_text_enabled and not is_floating:
		pass

	if message.visible_characters != current_character:
		message.visible_characters = current_character
		if can_play_sound and not is_floating:
			var player = %TypeWritePlayer
			player.stop()
			player.stream = current_text_fx
			player.pitch_scale = randf_range(current_text_fx_min_pitch, current_text_fx_max_pitch)
			player.volume_db = current_text_fx_volume
			player.play()
	
	if current_character < max_characters:
		var delay = max_character_delay
		if !busy_when_preview and skip_type == SkipMode.FAST_MESSAGE and Input.is_action_pressed("ui_select") and not is_floating:
			delay = skip_speed

		current_delay = delay
	else:
		# Start any remaining commands at the end of the text
		if !ignore_commands:
			while true:
				var paused: bool = false
				for command in special_commands:
					if !command.completed:
						await start_special_command(command)
						if busy:
							paused = true
							break
				
				while busy:
					await get_tree().process_frame
				
				if not paused:
					break


func _on_message_item_rect_changed() -> void:
	for image in images:
		reposition_texture(image)
		image.start_idle_animation()


func set_main_margin(left_value: int, right_value: int, top_value: int, bottom_value: int) -> void:
	%MainMargin.set("theme_override_constants/margin_left", left_value)
	%MainMargin.set("theme_override_constants/margin_top", top_value)
	%MainMargin.set("theme_override_constants/margin_right", right_value)
	%MainMargin.set("theme_override_constants/margin_bottom", bottom_value)


# char_index: Character position requesting a time value.
# allow_all_together: used internally by some transitions.
func get_t(char_index: int, allow_all_together: bool = true, length: float = 16.0) -> float:
	@warning_ignore("shadowed_variable")
	var time: float = 0
	var max_time: float = 0
	var text = %Message.get_parsed_text()
	for i in range(0, max_characters, 1):
		max_time += (dot_pause_delay if text[i] == "." else
			comma_pause_delay if text[i] == "," else current_delay)
		if i >= current_character:
			time += (dot_pause_delay if text[i] == "." else
				comma_pause_delay if text[i] == "," else current_delay)
	
	if max_time > 0:
		time = 1.0 - time / max_time
	else:
		return 0
		
	if all_at_once and allow_all_together:
		return 1.0 - time
	else:
		var characters = current_character + length
		if reverse:
			var t = (1.0 - time) * characters
			return 1.0 - clamp((char_index + length - t), 0.0, length) / length
		else:
			var t = time * characters
			return clamp((char_index + length - t), 0.0, length) / length


func get_visible_characters() -> int:
	return message.visible_characters


func get_characters_delay() -> float:
	return max_character_delay
