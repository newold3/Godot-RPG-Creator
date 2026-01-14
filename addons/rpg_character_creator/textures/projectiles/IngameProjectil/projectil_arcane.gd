extends ProjectileBase

@export var frequency: float = 12.0
@export var amplitude: float = 4.0

var _time_accum: float = 0.0

func _ready() -> void:
	super()
	speed = 400.0 

func _process(delta: float) -> void:
	super._process(delta)
	
	_time_accum += delta
	
	var wave_velocity = cos(_time_accum * frequency) * amplitude * 60.0 * delta
	
	var perp_vector = Vector2(-direction_vector.y, direction_vector.x)
	
	position += perp_vector * wave_velocity
	
	if direction_string == "left" or direction_string == "right":
		position.y += 25.0 * delta
