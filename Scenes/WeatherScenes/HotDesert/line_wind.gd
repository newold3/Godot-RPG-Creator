extends Line2D

@export var direction: Vector2 = Vector2.RIGHT # Exported initial direction
@export var wind_color: Color = Color.WHEAT
@export var min_speed: float = 100.0
@export var max_speed: float = 300.0
@export var wave_amplitude: float = 20.0 # Wave amplitude
@export var wave_frequency: float = 5.0 # Wave frequency
@export var wave_phase_shift: float = 0.5 # Phase shift between points
@export var lifetime: float = 3.0

var speed: float
var actual_direction: Vector2
var original_points: PackedVector2Array
var time_elapsed: float = 0.0
var actual_wave_amplitude: float = 0.0
var spread = 0

func _ready():
	# Use exported direction or generate random if Vector2.ZERO
	actual_direction = direction if direction != Vector2.ZERO else Vector2.RIGHT.rotated(randf_range(0, 2 * PI))
	
	# Random values for speed
	speed = randf_range(min_speed, max_speed)
	
	# Generate random points
	clear_points()
	
	spread = randi_range(10, 20)
	
	actual_wave_amplitude = wave_amplitude + randf_range(-2.0, actual_wave_amplitude)
	
	var point_count = spread
	for i in range(point_count):
		var point = Vector2(
			i * spread,
			randi_range(-1, 1)
		)
		add_point(point)
	
	# Save original points for reference
	original_points = points
	
	modulate = wind_color
	
	# Opacity transition
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", wind_color.a, 1.5)

func _process(delta):
	time_elapsed += delta
	
	# Move line in main direction
	position += actual_direction * speed * delta
	
	# Create snake-like undulating movement
	var perpendicular_direction = actual_direction.rotated(PI / 2)
	
	for i in range(points.size()):
		var original_point = original_points[i]
		
		# Create wave with phase shift for each point
		var wave_offset = sin(time_elapsed * wave_frequency + i * wave_phase_shift) * wave_amplitude
		
		# Apply offset in direction perpendicular to movement
		points[i] = original_point + perpendicular_direction * wave_offset
	
	# Disappear when lifetime is reached
	if time_elapsed >= lifetime:
		var fade_tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, 2.5)
		fade_tween.tween_callback(queue_free)
