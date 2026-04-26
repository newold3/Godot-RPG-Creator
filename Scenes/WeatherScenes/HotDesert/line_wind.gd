extends Line2D

## Base movement direction.
@export var direction: Vector2 = Vector2.RIGHT
## Color of the wind trail.
@export var wind_color: Color = Color.WHEAT
## Minimum forward speed.
@export var min_speed: float = 300.0
## Maximum forward speed.
@export var max_speed: float = 500.0
## Radians of wobble for the snake movement.
@export var wave_amplitude: float = 15.0
## Speed of the wobble oscillation.
@export var wave_frequency: float = 4.0
## Total active lifetime of the line in seconds.
@export var lifetime: float = 4.0
## Distance between captured points for the trail.
@export var trail_spacing: float = 8.0

@export_group("Trail Length")
## Minimum number of points in the tail.
@export var min_trail_length: int = 40
## Maximum number of points in the tail.
@export var max_trail_length: int = 80

@export_group("Loop Logic")
## Minimum radius for the loop effect.
@export var min_loop_radius: float = 30.0
## Maximum radius for the loop effect.
@export var max_loop_radius: float = 70.0
## Probability (0.0 to 1.0) of a loop occurring.
@export var loop_chance: float = 0.75
## Minimum time in seconds for the 360-degree rotation.
@export var min_loop_duration: float = 1.0
## Maximum time in seconds for the 360-degree rotation.
@export var max_loop_duration: float = 1.6

var speed: float
var base_dir: Vector2

var forward_speed_factor: float = 1.0
var wobble_factor: float = 1.0
var loop_alpha: float = 0.0
var loop_sign: float = 1.0
var current_loop_radius: float = 0.0
var current_max_points: int = 80

var will_loop: bool = false
var has_looped: bool = false
var loop_trigger_time: float = 0.0
var active_lifetime: float = 0.0
var wobble_time: float = 0.0

var head_base_pos: Vector2 = Vector2.ZERO
var path_points: Array[Vector2] = []
var is_dying: bool = false


func _ready() -> void:
	base_dir = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT.rotated(randf_range(0, TAU))
	speed = randf_range(min_speed, max_speed)
	
	# Determine random tail length for this specific wind line
	current_max_points = randi_range(min_trail_length, max_trail_length)
	
	will_loop = randf() < loop_chance
	if will_loop:
		loop_trigger_time = randf_range(0.8, lifetime - 1.0)
		current_loop_radius = randf_range(min_loop_radius, max_loop_radius)
		
	loop_sign = 1.0 if randf() > 0.5 else -1.0
	
	clear_points()
	head_base_pos = Vector2.ZERO
	path_points.append(head_base_pos)
	modulate = wind_color
	modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", wind_color.a, 1.0)


func _physics_process(delta: float) -> void:
	active_lifetime += delta
	wobble_time += delta * forward_speed_factor
	
	if not is_dying and active_lifetime >= lifetime:
		is_dying = true
		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 1.5)
		fade_tween.tween_callback(queue_free)
		
	if will_loop and not has_looped and active_lifetime >= loop_trigger_time:
		start_mathematical_loop()
		
	head_base_pos += base_dir * speed * forward_speed_factor * delta
	
	var wobble_offset_mag = sin(wobble_time * wave_frequency) * wave_amplitude * wobble_factor
	var wobble_vector = base_dir.rotated(PI/2) * wobble_offset_mag
	
	var loop_vector = Vector2.ZERO
	if loop_alpha > 0.0 and loop_alpha < TAU:
		var local_cx = sin(loop_alpha) * current_loop_radius
		var local_cy = loop_sign * (1.0 - cos(loop_alpha)) * current_loop_radius
		var local_loop_offset = Vector2(local_cx, local_cy)
		loop_vector = local_loop_offset.rotated(base_dir.angle())
	
	var head_pos = head_base_pos + wobble_vector + loop_vector
	
	if head_pos.distance_to(path_points[0]) >= trail_spacing:
		path_points.insert(0, head_pos)
		# Use the randomized max points here
		if path_points.size() > current_max_points:
			path_points.pop_back()
			
	var render_points = PackedVector2Array()
	render_points.append(head_pos)
	for pt in path_points:
		render_points.append(pt)
		
	points = render_points


func start_mathematical_loop() -> void:
	has_looped = true
	
	var current_loop_duration = randf_range(min_loop_duration, max_loop_duration)
	
	var extra_offset = randf_range(1.0, 2.5)
	lifetime += current_loop_duration + extra_offset
	
	var t = create_tween()
	t.set_parallel(true)
	
	t.tween_property(self, "loop_alpha", TAU, current_loop_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	t.tween_property(self, "forward_speed_factor", 0.1, current_loop_duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "wobble_factor", 0.0, current_loop_duration * 0.3)
	
	t.tween_property(self, "forward_speed_factor", 1.0, current_loop_duration * 0.3).set_delay(current_loop_duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "wobble_factor", 1.0, current_loop_duration * 0.3).set_delay(current_loop_duration * 0.7)
	
	t.chain().tween_callback(func(): loop_alpha = 0.0)
