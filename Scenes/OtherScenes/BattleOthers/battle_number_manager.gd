@tool
extends Node2D
class_name BattleNumberManager

signal screen_shake_requested(intensity: float)

enum AnimIn {
	## Appears gradually by transitioning opacity from 0 to 1
	FADE,
	## Scales up rapidly from zero with a bouncy elastic effect
	POP_UP,
	## Falls from above and bounces off the baseline
	BOUNCE_DOWN,
	## Moves in from the left side with a cubic ease
	SLIDE_LEFT,
	## Moves in from the right side with a cubic ease
	SLIDE_RIGHT,
	## Flips horizontally from a 0 width to full width
	FLIP_H,
	## Flips vertically from a 0 height to full height
	FLIP_V,
	## Rotates wildly while scaling up
	SPIN_IN,
	## Stretches heavily on the Y axis before squashing to normal
	STRETCH_Y,
	## Starts massive and scales down to normal size quickly
	ZOOM_IN,
	## Extremely bouncy scale up simulating elastic material
	ELASTIC_POP,
	## Drops down instantly with an exponential curve
	DROP_IN,
	## Rolls in from the side as if bound to a wheel
	ROLL_IN,
	## Spins multiple times quickly while scaling up
	SWIRL_IN,
	## Erratically jumps in scale and position before settling
	GLITCH,
	## Instantly appears without interpolation
	TYPEWRITER,
	## Splits digits to the sides and slams them together
	MAGNETIZE,
	## Digits circle their target position before landing
	ORBIT_IN,
	## Rapidly changes the displayed numbers before locking in
	DIGITAL_DECODE,
	## Bounces between extremely wide and extremely tall scales
	RUBBER_BAND,
	## Pulses in scale mimicking a heartbeat
	HEARTBEAT,
	## Drops and bounces multiple times with realistic gravity
	GRAVITY_BOUNCE,
	## Enters at an angle and snaps into place like a whip
	WHIP,
	## Instant flash of white color with a high-tension shake
	LIGHTNING_STRIKE,
	## Slams downwards forcefully triggering a screen shake
	STAMP,
	## Each digit triggers sequentially with a slight delay
	CHAIN_REACTION,
	## Picks a random animation from the available in animations
	RANDOM
}

enum AnimOut {
	## Fades away by transitioning opacity to 0
	FADE,
	## Shrinks down to zero scale with a back ease
	SHRINK,
	## Floats upwards while fading out smoothly
	FLOAT_UP,
	## Drops downwards quickly
	FALL_DOWN,
	## Slides away to the left
	SLIDE_LEFT,
	## Slides away to the right
	SLIDE_RIGHT,
	## Spins around while scaling down
	SPIN_OUT,
	## Randomly scatters the digits in all directions
	EXPLODE,
	## Scales up massively while fading out
	ZOOM_OUT,
	## Flattens out horizontally before disappearing
	SQUASH_OUT,
	## Shoots upwards extremely fast
	FLY_AWAY,
	## Breaks apart with erratic rotation and translation
	SHATTER,
	## Spins violently upwards while scaling down
	TORNADO_OUT,
	## Bounces and rolls away to the side
	ROLL_AWAY,
	## Rises slowly and expands while fading like smoke
	SMOKE_DISSOLVE,
	## Instantly snaps scale and opacity in a pixelated manner
	PIXEL_BREAK,
	## Folds in half horizontally like a playing card
	CARD_FLIP,
	## Shoots right then sharply comes back left before fading
	BOOMERANG,
	## Rotates and moves outward in a circular spiral
	SPIRAL_OUT,
	## Gets sucked rapidly towards the central target point
	VACUUM,
	## Stretches down and flattens out as if melting
	MELT,
	## Picks a random animation from the available out animations
	RANDOM
}

enum AnimIdle {
	## No idle animation applied
	NONE,
	## Digits move up and down in a continuous sine wave
	WAVE,
	## Rapid, chaotic small movements every frame
	JITTER,
	## Slowly expands and contracts
	BREATHE,
	## Opacity continuously cycles up and down
	PULSE,
	## Cycles through the HSV color spectrum
	HUE_SHIFT,
	## Slowly drifts horizontally in a smooth curve
	SINE_FLOAT
}

enum Effect {
	## No secondary visual effects
	NONE,
	## Leaves a trail of fading ghost images spaced by time
	AFTERIMAGE,
	## Draws a flashing outline around the digits
	OUTLINE_FLASH,
	## Leaves a dense trail of ghost images every frame
	MOTION_BLUR,
	## Projects a dark shadow below and behind the digits
	DROP_SHADOW,
	## Renders a soft, enlarged, tinted background glow
	GLOW_BEHIND,
	## Splits red and blue color channels horizontally
	CHROMATIC_ABERRATION
}

class Digit extends RefCounted:
	var character: String = ""
	var size: Vector2 = Vector2.ZERO
	var pos: Vector2 = Vector2.ZERO
	var offset: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE
	var scale: Vector2 = Vector2.ONE
	var rotation: float = 0.0
	var decode_time: float = 0.0
	var history_timer: float = 0.0
	var history_pos: Array[Vector2] = []
	var history_scale: Array[Vector2] = []
	var history_rot: Array[float] = []

class NumberGroup extends RefCounted:
	var digits: Array[Digit] = []
	var anim_idle: AnimIdle = AnimIdle.NONE
	var effect: Effect = Effect.NONE
	var stack_offset: Vector2 = Vector2.ZERO

class TargetTracker extends RefCounted:
	var target: Node2D = null
	var fixed_pos: Vector2 = Vector2.ZERO
	var groups: Array[NumberGroup] = []

## The font used to draw the numbers
@export var font: Font = null

## The base font size for the numbers
@export var font_size: int = 32

## The gap between digits in pixels
@export var digit_spacing: float = 2.0

## The global scale multiplier applied to all numbers
@export var numbers_scale: float = 1.0

@export_group("Debug Testing")

## The animation used for the number entrance
@export var test_anim_in: AnimIn = AnimIn.POP_UP

## The animation used for the number exit
@export var test_anim_out: AnimOut = AnimOut.FADE

## The continuous idle animation for the number
@export var test_anim_idle: AnimIdle = AnimIdle.NONE

## The special visual effect applied to the number
@export var test_effect: Effect = Effect.NONE

## The color of the debug test number
@export var test_color: Color = Color.WHITE

## The total duration of the debug test animation
@export var test_duration: float = 1.1

## Click to spawn a debug number in the editor viewport
@export var play_test_animation: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_trigger_editor_test()
		play_test_animation = false

var active_trackers: Array[TargetTracker] = []
var debug_enabled: bool = true


## Initializes the random number generator
func _ready() -> void:
	randomize()


## Triggers a test number directly in the editor viewport
func _trigger_editor_test() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
		
	var test_val: int = randi_range(100, 9999)
	show_number(test_val, null, test_color, 1.0, test_anim_in, test_anim_out, test_anim_idle, test_effect, test_duration)


## Generates a random number with random parameters for runtime debugging
func _generate_debug_number() -> void:
	var rand_val: int = randi_range(1, 99999)
	var rand_color: Color = Color(randf_range(0.4, 1.0), randf_range(0.4, 1.0), randf_range(0.4, 1.0), 1.0)
	var rand_scale: float = randf_range(0.7, 1.4)
	var rand_duration: float = randf_range(0.8, 1.8)
	var rand_idle: AnimIdle = randi() % AnimIdle.size() as AnimIdle
	var rand_effect: Effect = randi() % Effect.size() as Effect
	
	show_number(rand_val, null, rand_color, rand_scale, AnimIn.RANDOM, AnimOut.RANDOM, rand_idle, rand_effect, rand_duration)


## Triggers a standard attack number animation picking from suitable clean animations
func normal_hit(value: int, target: Node2D = null, color: Color = Color.WHITE, scale_val: float = 1.0, duration: float = 0.8) -> void:
	var in_anims: Array[AnimIn] = [AnimIn.POP_UP, AnimIn.BOUNCE_DOWN, AnimIn.SLIDE_LEFT, AnimIn.SLIDE_RIGHT]
	var out_anims: Array[AnimOut] = [AnimOut.FLOAT_UP, AnimOut.FADE, AnimOut.SHRINK, AnimOut.FLY_AWAY]
	var rand_in: AnimIn = in_anims.pick_random()
	var rand_out: AnimOut = out_anims.pick_random()
	
	show_number(value, target, color, scale_val, rand_in, rand_out, AnimIdle.NONE, Effect.NONE, duration)


## Triggers a critical attack number animation picking from suitable high impact animations
func critical_hit(value: int, target: Node2D = null, color: Color = Color(1.0, 0.85, 0.2, 1.0), scale_val: float = 1.5, duration: float = 0.75) -> void:
	var in_anims: Array[AnimIn] = [AnimIn.ZOOM_IN, AnimIn.ELASTIC_POP, AnimIn.DROP_IN, AnimIn.STAMP, AnimIn.LIGHTNING_STRIKE, AnimIn.GLITCH]
	var out_anims: Array[AnimOut] = [AnimOut.SHATTER, AnimOut.EXPLODE, AnimOut.SQUASH_OUT, AnimOut.SMOKE_DISSOLVE, AnimOut.PIXEL_BREAK]
	var rand_in: AnimIn = in_anims.pick_random()
	var rand_out: AnimOut = out_anims.pick_random()
	
	show_number(value, target, color, scale_val, rand_in, rand_out, AnimIdle.SINE_FLOAT, Effect.NONE, duration)


## Handles runtime debug input
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not debug_enabled: 
		return
	
	if event.is_action_pressed("ui_accept"):
		_generate_debug_number()
	elif event.is_action_pressed("ui_up"):
		var rand_val: int = randi_range(10, 999)
		normal_hit(rand_val)
	elif event.is_action_pressed("ui_down"):
		var rand_val: int = randi_range(1000, 9999)
		critical_hit(rand_val)


## Processes active tweens, history logic and tracking updates
func _process(delta: float) -> void:
	if active_trackers.size() > 0:
		for tracker in active_trackers:
			var base_pos: Vector2 = tracker.fixed_pos
			
			if is_instance_valid(tracker.target):
				base_pos = tracker.target.global_position
				tracker.fixed_pos = base_pos
				
			for group in tracker.groups:
				if group.effect == Effect.AFTERIMAGE:
					for digit in group.digits:
						digit.history_timer += delta
						
						if digit.history_timer >= 0.04:
							digit.history_timer = 0.0
							var final_pos: Vector2 = base_pos + group.stack_offset + digit.pos + digit.offset
							digit.history_pos.append(final_pos)
							digit.history_scale.append(digit.scale)
							digit.history_rot.append(digit.rotation)
							
							if digit.history_pos.size() > 5:
								digit.history_pos.pop_front()
								digit.history_scale.pop_front()
								digit.history_rot.pop_front()
								
				elif group.effect == Effect.MOTION_BLUR:
					for digit in group.digits:
						var final_pos: Vector2 = base_pos + group.stack_offset + digit.pos + digit.offset
						digit.history_pos.append(final_pos)
						digit.history_scale.append(digit.scale)
						digit.history_rot.append(digit.rotation)
						
						if digit.history_pos.size() > 8:
							digit.history_pos.pop_front()
							digit.history_scale.pop_front()
							digit.history_rot.pop_front()
							
		queue_redraw()


## Draws all active number digits and tracking their nodes securely
func _draw() -> void:
	var f: Font = font if font else ThemeDB.fallback_font
	var time: float = Time.get_ticks_msec() / 1000.0
		
	for tracker in active_trackers:
		var base_pos: Vector2 = tracker.fixed_pos
		
		if is_instance_valid(tracker.target):
			base_pos = tracker.target.global_position
			tracker.fixed_pos = base_pos
			
		for group in tracker.groups:
			for i in range(group.digits.size()):
				var digit: Digit = group.digits[i]
				var draw_pos: Vector2 = base_pos + group.stack_offset + digit.pos
				var draw_scale: Vector2 = digit.scale
				var draw_color: Color = digit.color
				var draw_char: String = digit.character
				var history_size: int = digit.history_pos.size()
				
				if digit.decode_time > 0.0:
					draw_char = str(randi() % 10)
				
				match group.anim_idle:
					AnimIdle.WAVE:
						draw_pos.y += sin(time * 8.0 + (i * 0.5)) * 8.0
					AnimIdle.JITTER:
						draw_pos.x += randf_range(-2.0, 2.0)
						draw_pos.y += randf_range(-2.0, 2.0)
					AnimIdle.BREATHE:
						var b_scale: float = 1.0 + (sin(time * 5.0) * 0.15)
						draw_scale *= Vector2(b_scale, b_scale)
					AnimIdle.PULSE:
						var a_mod: float = 0.6 + (sin(time * 10.0) * 0.4)
						draw_color = Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * a_mod)
					AnimIdle.HUE_SHIFT:
						draw_color = Color.from_hsv(fmod(time * 0.5, 1.0), draw_color.s, draw_color.v, draw_color.a)
					AnimIdle.SINE_FLOAT:
						draw_pos.x += sin(time * 4.0 + i) * 6.0
				
				var center_offset: Vector2 = Vector2(-digit.size.x / 2.0, -digit.size.y / 2.0 + f.get_ascent(font_size))
				var actual_pos: Vector2 = draw_pos + digit.offset
				
				match group.effect:
					Effect.DROP_SHADOW:
						draw_set_transform(actual_pos + Vector2(4.0, 4.0), digit.rotation, draw_scale)
						f.draw_string(get_canvas_item(), center_offset, draw_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, draw_color.a * 0.7))
					
					Effect.GLOW_BEHIND:
						var glow_color: Color = draw_color
						glow_color.a *= 0.3
						draw_set_transform(actual_pos, digit.rotation, draw_scale)
						f.draw_string_outline(get_canvas_item(), center_offset, draw_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(1, int(4.0 * draw_scale.x)), glow_color)
						
					Effect.CHROMATIC_ABERRATION:
						var red_color: Color = Color(1.0, 0.0, 0.0, draw_color.a * 0.6)
						var blue_color: Color = Color(0.0, 0.5, 1.0, draw_color.a * 0.6)
						var shift_vec: Vector2 = Vector2(3.0 * draw_scale.x, 0.0)
						draw_set_transform(actual_pos + shift_vec, digit.rotation, draw_scale)
						f.draw_string(get_canvas_item(), center_offset, draw_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, red_color)
						draw_set_transform(actual_pos - shift_vec, digit.rotation, draw_scale)
						f.draw_string(get_canvas_item(), center_offset, draw_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, blue_color)
						
					Effect.OUTLINE_FLASH:
						var outline_color: Color = Color.WHITE
						var alpha_mod: float = 0.5 + (sin(time * 12.0) * 0.5)
						outline_color.a = draw_color.a * alpha_mod
						draw_set_transform(actual_pos, digit.rotation, draw_scale)
						f.draw_string_outline(get_canvas_item(), center_offset, draw_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, outline_color)
					
					Effect.AFTERIMAGE, Effect.MOTION_BLUR:
						for t in range(history_size):
							var t_scale: Vector2 = digit.history_scale[t]
							var t_alpha: float = (float(t + 1) / float(history_size)) * 0.4 * draw_color.a
							var t_color: Color = Color(draw_color.r, draw_color.g, draw_color.b, t_alpha)
							draw_set_transform(digit.history_pos[t], digit.history_rot[t], t_scale)
							f.draw_string(get_canvas_item(), center_offset, draw_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, t_color)
				
				draw_set_transform(actual_pos, digit.rotation, draw_scale)
				f.draw_string(get_canvas_item(), center_offset, draw_char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, draw_color)
				
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Spawns a new floating number tracking a target, handling grouping and layout logic
func show_number(value: int, target: Node2D = null, color: Color = Color.WHITE, scale_val: float = 1.0, anim_in: AnimIn = AnimIn.POP_UP, anim_out: AnimOut = AnimOut.FADE, anim_idle: AnimIdle = AnimIdle.NONE, effect: Effect = Effect.NONE, duration: float = 1.1) -> void:
	var actual_anim_in: AnimIn = anim_in
	var actual_anim_out: AnimOut = anim_out
	var value_str: String = str(value)
	var char_count: int = value_str.length()
	var total_w: float = 0.0
	var group: NumberGroup = NumberGroup.new()
	var tracker: TargetTracker = null
	var final_scale: float = scale_val * numbers_scale
	var f: Font = font if font else ThemeDB.fallback_font

	if actual_anim_in == AnimIn.RANDOM:
		actual_anim_in = (randi() % (AnimIn.size() - 1)) as AnimIn

	if actual_anim_out == AnimOut.RANDOM:
		actual_anim_out = (randi() % (AnimOut.size() - 1)) as AnimOut

	group.anim_idle = anim_idle
	group.effect = effect

	for i in range(char_count):
		var char_size: Vector2 = f.get_string_size(value_str[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		total_w += char_size.x * final_scale

	total_w += (char_count - 1) * digit_spacing

	var start_x: float = -(total_w / 2.0)

	for i in range(char_count):
		var char_str: String = value_str[i]
		var char_size: Vector2 = f.get_string_size(char_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var digit: Digit = Digit.new()
		var y_disp: float = 0.0

		if randf() > 0.6:
			y_disp = randf_range(-6.0, 6.0)

		digit.character = char_str
		digit.size = char_size
		digit.pos = Vector2(start_x + (char_size.x * final_scale / 2.0), y_disp)
		digit.color = color
		digit.scale = Vector2(final_scale, final_scale)
		digit.rotation = deg_to_rad(randf_range(-3.0, 3.0))

		group.digits.append(digit)
		start_x += (char_size.x * final_scale) + digit_spacing

	if is_instance_valid(target):
		for t in active_trackers:
			if t.target == target:
				tracker = t
				break

	if tracker == null:
		tracker = TargetTracker.new()
		tracker.target = target

		if target == null:
			if Engine.is_editor_hint():
				tracker.fixed_pos = get_viewport_rect().size / 2.0
			elif debug_enabled:
				tracker.fixed_pos = Vector2(randf_range(150, 650), randf_range(150, 450))
			else:
				tracker.fixed_pos = get_viewport_rect().size / 2.0

		active_trackers.append(tracker)

	tracker.groups.append(group)

	if tracker.groups.size() > 1:
		var push_amount: float = 40.0 * final_scale
		var stack_tween: Tween = create_tween().set_parallel(true)

		for i in range(tracker.groups.size() - 1):
			var older_group: NumberGroup = tracker.groups[i]
			stack_tween.tween_property(older_group, "stack_offset:y", older_group.stack_offset.y - push_amount, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var tween: Tween = create_tween().set_parallel(true)
	var delay_step: float = 0.0
	var safe_duration: float = maxf(duration, 0.2)
	var in_time: float = safe_duration * 0.25
	var hold_time: float = safe_duration * 0.50
	var out_time: float = safe_duration * 0.25

	if group.digits.size() > 1:
		var total_delay: float = safe_duration * 0.2
		var remaining_time: float = safe_duration - total_delay

		delay_step = total_delay / (group.digits.size() - 1)
		in_time = remaining_time * 0.25
		hold_time = remaining_time * 0.50
		out_time = remaining_time * 0.25

	for i in range(group.digits.size()):
		var d: Digit = group.digits[i]
		var base_delay: float = i * delay_step
		var out_delay: float = in_time + hold_time + base_delay
		var target_rot: float = d.rotation
		var start_rot_spin: float = target_rot - PI
		var start_rot_roll: float = target_rot - (PI * 2.0)
		var start_rot_swirl: float = target_rot - (PI * 4.0)

		match actual_anim_in:
			AnimIn.FADE:
				d.color.a = 0.0
				tween.tween_property(d, "color:a", color.a, in_time).set_delay(base_delay)
			AnimIn.POP_UP:
				d.scale = Vector2.ZERO
				d.color.a = color.a
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(base_delay)
			AnimIn.BOUNCE_DOWN:
				d.offset.y = -50.0
				d.color.a = 0.0
				tween.tween_property(d, "offset:y", 0.0, in_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.4).set_delay(base_delay)
			AnimIn.SLIDE_LEFT:
				d.offset.x = 60.0
				d.color.a = 0.0
				tween.tween_property(d, "offset:x", 0.0, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time).set_delay(base_delay)
			AnimIn.SLIDE_RIGHT:
				d.offset.x = -60.0
				d.color.a = 0.0
				tween.tween_property(d, "offset:x", 0.0, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time).set_delay(base_delay)
			AnimIn.FLIP_H:
				d.scale = Vector2(0.0, final_scale)
				d.color.a = color.a
				tween.tween_property(d, "scale:x", final_scale, in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(base_delay)
			AnimIn.FLIP_V:
				d.scale = Vector2(final_scale, 0.0)
				d.color.a = color.a
				tween.tween_property(d, "scale:y", final_scale, in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(base_delay)
			AnimIn.SPIN_IN:
				d.rotation = start_rot_spin
				d.scale = Vector2.ZERO
				d.color.a = color.a
				tween.tween_property(d, "rotation", target_rot, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_delay(base_delay)
			AnimIn.STRETCH_Y:
				d.scale = Vector2(final_scale * 0.2, final_scale * 3.0)
				d.color.a = color.a
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
			AnimIn.ZOOM_IN:
				d.scale = Vector2(final_scale * 3.0, final_scale * 3.0)
				d.color.a = 0.0
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.5).set_delay(base_delay)
			AnimIn.ELASTIC_POP:
				d.scale = Vector2.ZERO
				d.color.a = color.a
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
			AnimIn.DROP_IN:
				d.offset.y = -100.0
				d.color.a = 0.0
				tween.tween_property(d, "offset:y", 0.0, in_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.5).set_delay(base_delay)
			AnimIn.ROLL_IN:
				d.offset.x = -80.0
				d.rotation = start_rot_roll
				d.color.a = 0.0
				tween.tween_property(d, "offset:x", 0.0, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "rotation", target_rot, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.5).set_delay(base_delay)
			AnimIn.SWIRL_IN:
				d.scale = Vector2.ZERO
				d.rotation = start_rot_swirl
				d.color.a = 0.0
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "rotation", target_rot, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.5).set_delay(base_delay)
			AnimIn.GLITCH:
				d.scale = Vector2(final_scale * 2.0, final_scale * 0.1)
				d.offset = Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0))
				d.color.a = 0.0
				tween.tween_property(d, "color:a", color.a, 0.01).set_delay(base_delay)
				tween.tween_property(d, "offset", Vector2(randf_range(-20.0, 20.0), randf_range(-30.0, 30.0)), in_time * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale * 0.2, final_scale * 2.5), in_time * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "offset", Vector2(randf_range(-30.0, 30.0), randf_range(-10.0, 10.0)), in_time * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(base_delay + in_time * 0.2)
				tween.tween_property(d, "scale", Vector2(final_scale * 1.8, final_scale * 0.4), in_time * 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(base_delay + in_time * 0.2)
				tween.tween_property(d, "offset", Vector2.ZERO, in_time * 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(base_delay + in_time * 0.4)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time * 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(base_delay + in_time * 0.4)
			AnimIn.TYPEWRITER:
				d.color.a = 0.0
				tween.tween_property(d, "color:a", color.a, 0.01).set_delay(base_delay)
			AnimIn.MAGNETIZE:
				var dir_x: float = -150.0 if i < (char_count / 2.0) else 150.0
				d.offset.x = dir_x
				d.color.a = 0.0
				tween.tween_property(d, "offset:x", 0.0, in_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.5).set_delay(base_delay)
			AnimIn.ORBIT_IN:
				d.scale = Vector2.ZERO
				d.offset = Vector2(cos(i) * 80.0, sin(i) * 80.0)
				d.color.a = color.a
				tween.tween_property(d, "offset", Vector2.ZERO, in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_delay(base_delay)
			AnimIn.DIGITAL_DECODE:
				d.decode_time = 1.0
				d.color.a = 0.0
				tween.tween_property(d, "decode_time", 0.0, in_time).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, 0.01).set_delay(base_delay)
			AnimIn.RUBBER_BAND:
				d.scale = Vector2.ZERO
				d.color.a = color.a
				tween.tween_property(d, "scale", Vector2(final_scale * 1.5, final_scale * 0.5), in_time * 0.33).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale * 0.5, final_scale * 1.5), in_time * 0.33).set_delay(base_delay + in_time * 0.33)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time * 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(base_delay + in_time * 0.66)
			AnimIn.HEARTBEAT:
				d.scale = Vector2.ZERO
				d.color.a = color.a
				tween.tween_property(d, "scale", Vector2(final_scale * 1.4, final_scale * 1.4), in_time * 0.25).set_trans(Tween.TRANS_SINE).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time * 0.25).set_trans(Tween.TRANS_SINE).set_delay(base_delay + in_time * 0.25)
				tween.tween_property(d, "scale", Vector2(final_scale * 1.3, final_scale * 1.3), in_time * 0.25).set_trans(Tween.TRANS_SINE).set_delay(base_delay + in_time * 0.5)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time * 0.25).set_trans(Tween.TRANS_SINE).set_delay(base_delay + in_time * 0.75)
			AnimIn.GRAVITY_BOUNCE:
				d.offset.y = -120.0
				d.color.a = 0.0
				tween.tween_property(d, "offset:y", 0.0, in_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.2).set_delay(base_delay)
			AnimIn.WHIP:
				d.offset.x = -60.0
				d.rotation = target_rot - (PI / 2.0)
				d.scale = Vector2(final_scale * 2.0, final_scale * 0.4)
				d.color.a = 0.0
				tween.tween_property(d, "offset:x", 0.0, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "rotation", target_rot, in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.5).set_delay(base_delay)
			AnimIn.LIGHTNING_STRIKE:
				d.color = Color.WHITE
				d.scale = Vector2(final_scale * 1.3, final_scale * 1.3)
				d.offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
				tween.tween_property(d, "color", color, in_time * 0.5).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_delay(base_delay)
				tween.tween_property(d, "offset", Vector2.ZERO, in_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(base_delay)
			AnimIn.STAMP:
				d.offset.y = -200.0
				d.scale = Vector2(final_scale * 3.0, final_scale * 3.0)
				d.color.a = 0.0
				tween.tween_property(d, "offset:y", 0.0, in_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(base_delay)
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(base_delay)
				tween.tween_property(d, "color:a", color.a, in_time * 0.2).set_delay(base_delay)
				if i == 0:
					tween.tween_callback(func(): screen_shake_requested.emit(0.4)).set_delay(base_delay + in_time * 0.5)
			AnimIn.CHAIN_REACTION:
				d.scale = Vector2.ZERO
				d.color.a = color.a
				tween.tween_property(d, "scale", Vector2(final_scale, final_scale), in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(base_delay * 1.5)

		tween.tween_property(d, "color:a", color.a, 0.01).set_delay(out_delay - 0.01)

		match actual_anim_out:
			AnimOut.FADE:
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.SHRINK:
				tween.tween_property(d, "scale", Vector2.ZERO, out_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(out_delay)
			AnimOut.FLOAT_UP:
				tween.tween_property(d, "offset:y", -50.0, out_time).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.FALL_DOWN:
				tween.tween_property(d, "offset:y", 50.0, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.SLIDE_LEFT:
				tween.tween_property(d, "offset:x", -60.0, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.SLIDE_RIGHT:
				tween.tween_property(d, "offset:x", 60.0, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.SPIN_OUT:
				tween.tween_property(d, "rotation", target_rot + PI, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "scale", Vector2.ZERO, out_time).set_delay(out_delay)
			AnimOut.EXPLODE:
				var explode_x: float = randf_range(-40.0, 40.0)
				var explode_y: float = randf_range(-40.0, 40.0)
				tween.tween_property(d, "offset:x", explode_x, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(out_delay)
				tween.tween_property(d, "offset:y", explode_y, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.ZOOM_OUT:
				tween.tween_property(d, "scale", Vector2(final_scale * 3.0, final_scale * 3.0), out_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.SQUASH_OUT:
				tween.tween_property(d, "scale", Vector2(final_scale * 1.5, 0.0), out_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.FLY_AWAY:
				tween.tween_property(d, "offset:y", -150.0, out_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "scale", Vector2(final_scale * 0.5, final_scale * 0.5), out_time).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.SHATTER:
				var shatter_x: float = randf_range(-40.0, 40.0)
				var shatter_y: float = randf_range(20.0, 80.0)
				var shatter_rot: float = target_rot + randf_range(-PI, PI)
				tween.tween_property(d, "offset:x", shatter_x, out_time).set_trans(Tween.TRANS_LINEAR).set_delay(out_delay)
				tween.tween_property(d, "offset:y", shatter_y, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "rotation", shatter_rot, out_time).set_trans(Tween.TRANS_LINEAR).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.TORNADO_OUT:
				tween.tween_property(d, "rotation", target_rot + (PI * 4.0), out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "scale", Vector2.ZERO, out_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "offset:y", -80.0, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.ROLL_AWAY:
				tween.tween_property(d, "offset:x", 80.0, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "offset:y", 30.0, out_time).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(out_delay)
				tween.tween_property(d, "rotation", target_rot + (PI * 2.0), out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.SMOKE_DISSOLVE:
				tween.tween_property(d, "offset:y", -80.0, out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(out_delay)
				tween.tween_property(d, "offset:x", randf_range(-40.0, 40.0), out_time).set_delay(out_delay)
				tween.tween_property(d, "scale", Vector2(final_scale * 2.0, final_scale * 2.0), out_time).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)
			AnimOut.PIXEL_BREAK:
				tween.tween_property(d, "scale", Vector2.ZERO, out_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(out_delay)
			AnimOut.CARD_FLIP:
				tween.tween_property(d, "scale:y", 0.0, out_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "scale:x", final_scale * 1.5, out_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time * 0.5).set_delay(out_delay)
			AnimOut.BOOMERANG:
				tween.tween_property(d, "offset:x", 80.0, out_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(out_delay)
				tween.tween_property(d, "offset:x", -200.0, out_time * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay + out_time * 0.5)
				tween.tween_property(d, "color:a", 0.0, out_time * 0.5).set_delay(out_delay + out_time * 0.5)
			AnimOut.SPIRAL_OUT:
				tween.tween_property(d, "rotation", target_rot + (PI * 4.0), out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "offset", Vector2(cos(i) * 150.0, sin(i) * 150.0), out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "scale", Vector2.ZERO, out_time).set_delay(out_delay)
			AnimOut.VACUUM:
				tween.tween_property(d, "offset", Vector2(tracker.fixed_pos.x - d.pos.x, 0.0), out_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "scale", Vector2.ZERO, out_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(out_delay)
			AnimOut.MELT:
				tween.tween_property(d, "scale:y", final_scale * 3.0, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "scale:x", final_scale * 0.2, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "offset:y", 100.0, out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(out_delay)
				tween.tween_property(d, "color:a", 0.0, out_time).set_delay(out_delay)

	tween.chain().tween_callback(self._remove_group.bind(tracker, group))


## Unlinks a group from its parent tracker gracefully upon tween completion
func _remove_group(tracker: TargetTracker, group: NumberGroup) -> void:
	tracker.groups.erase(group)
	
	if tracker.groups.is_empty():
		active_trackers.erase(tracker)
