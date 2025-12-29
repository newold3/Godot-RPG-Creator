extends SubViewportContainer

@export var rotation_speed = 0 
@export var depth = Vector2.ZERO
@export_node_path("Camera2D") var camera_path

var shader = null
var virtual_transform = Transform2D.IDENTITY 
var camera = null
var perspective_matrix = Basis.IDENTITY

func _ready():
	shader = material as ShaderMaterial
	virtual_transform = Transform2D.IDENTITY
	#virtual_transform.scale = Vector2.ONE
	
	camera = get_node_or_null(camera_path) as Camera2D
	
	shader.set_shader_parameter("depth", depth)
	perspective_matrix = create_2d_perspective_matrix()
	
func _process(delta):
	global_position = camera.global_position - size / 2
	
	movement(delta)
	
	update_shader_params()
	
func create_2d_perspective_matrix():
	var matrix = Basis.IDENTITY
	
	matrix.x = Vector3(1, 0, depth.x)
	matrix.y = Vector3(0, 1, depth.y)
	matrix.z = Vector3(0, 0, 1)
	
	return matrix

func transform_position(position):
	var sprite_transform = Transform2D.IDENTITY
	
	# position is based on the camera positions, work in progress will use the virtual transform for now
	# scale is based on the mode 7 backgrounds virtual transform
	# rotation is based on the mode 7 backgrounds virtual transform
	#working_transform.origin = camera.global_position
	
	# transform position from world space to -1 to 1
	var world_pos = (position / (get_viewport_rect().size / 2)) - Vector2.ONE
	
	# combined perspective and view transforms
	var view_basis = Basis.IDENTITY
	
	view_basis.set_column(0, Vector3(virtual_transform.x.x, virtual_transform.x.y, 0))
	view_basis.set_column(1, Vector3(virtual_transform.y.x, virtual_transform.y.y, 0))
	view_basis.set_column(2, Vector3(virtual_transform.origin.x, virtual_transform.origin.y, 1))
	
	#var pv = perspective_matrix * view_basis
	var pv = view_basis * perspective_matrix
	
	var pos = Vector3(world_pos.x, world_pos.y, 1)
	pos = pv.xform(pos)
	pos.x /= pos.z
	pos.y /= pos.z
	
	world_pos.x = pos.x
	world_pos.y = pos.y
	
	# transform back to world_pos
	world_pos = (world_pos + Vector2.ONE) * (get_viewport_rect().size / 2)
	pos.x = world_pos.x
	pos.y = world_pos.y
	
	return pos
	
func movement(delta):
	var motion = Vector2.ZERO
	
	var scroll_speed = Vector2.ONE 
	
	# Movement is handled in the Player object
	# Uncomment this if you just want to test everything going on with the virtual transform
	#
	if Input.is_action_pressed("ui_up"):
		motion.y -= scroll_speed.y
	if Input.is_action_pressed("ui_down"): 
		motion.y += scroll_speed.y
	virtual_transform.origin += (motion * delta)
	
	# Scaling here if wanted in the future
	
	#var zoom = Vector2.ZERO
	#if Input.is_action_pressed("jump"):
		#zoom.y += scale_speed.y
		#zoom.x += scale_speed.x
	#if Input.is_action_pressed("slide_dive"):
		#zoom.y -= scale_speed.y
		#zoom.x -= scale_speed.x 
	#virtual_transform.scale += (zoom * delta)
	
	# Rotations are handled here so the background lines up with the direction of player movement
	var rotate = 0
	if Input.is_action_pressed("ui_left"):
		rotate += rotation_speed
	if Input.is_action_pressed("ui_right"):
		rotate -= rotation_speed
	virtual_transform.rotated(rotate * delta)
	
func update_shader_params():
	if shader != null:
		shader.set_shader_parameter("transform", virtual_transform)
