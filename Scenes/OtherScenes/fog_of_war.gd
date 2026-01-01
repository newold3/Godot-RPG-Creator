extends CanvasLayer

# Sprite containing the fog texture
@onready var fog_sprite: Sprite2D = %MainSprite

# Array of fog points (time, direction, x, y)
var fog_points: Array[Vector4] = []

# Nodes that generate "holes" in the fog
var targets: Array = []

func _ready():
	create_fog_of_war_texture()
	add_player()


# Create fog texture
func create_fog_of_war_texture() -> void:
	var map: RPGMap = get_tree().get_first_node_in_group("rpgmap")
	
	if map:
		var viewport_size: Vector2 = get_viewport().size
		var used_rect: Rect2 = map.get_used_rect(false)

		# Create fog texture of map size
		var fog_texture = Image.create(
			viewport_size.x,
			viewport_size.y,
			false,
			Image.FORMAT_RGBA8
		)
		
		# Fill with black
		fog_texture.fill(Color(0, 0, 0, 1))

		var image_texture = ImageTexture.create_from_image(fog_texture)

		# Configure fog sprite
		fog_sprite.texture = image_texture
		fog_sprite.position = used_rect.position
		var gs = Vector2(used_rect.size) / image_texture.get_size()
		fog_sprite.global_scale = gs
		
		$CanvasLayer/ColorRect/TextureRect.texture = image_texture

		var mat: ShaderMaterial = fog_sprite.get_material()
		if mat:
			mat.set_shader_parameter("scale", Vector2(1.0 / gs.x, 1.0 / gs.y))


# Add players to the hole system
func add_player() -> void:
	var nodes = get_tree().get_nodes_in_group("player")
	for node in nodes:
		add_target(node)


func _process(delta):
	if !targets:
		add_player()
		return

	# Update times in fog_points
	for i in range(fog_points.size() - 1, -1, -1):
		var point = fog_points[i]
		point.x += delta

		# Remove points that finished their animation
		if point.x > 1.0 and point.y == 0.0:
			fog_points.remove_at(i)
		else:
			fog_points[i] = point

	# Calculate current target positions
	var fog_sprite_size = fog_sprite.texture.get_size()
	var current_target_positions = targets.map(
		func(t):
			# Calculate exact global position
			var global_pos = Vector2i(t.global_position - fog_sprite.global_position)
			return global_pos
	)
	
	# Add new points
	for pos in current_target_positions:
		var found = false
		for point in fog_points:
			if abs(point.z - pos.x) < 1.0 and abs(point.w - pos.y) < 1.0:
				found = true
				break
		if not found:
			fog_points.insert(0, Vector4(0, 1.0, pos.x, pos.y))
	
	# Mark points that no longer have targets (similar to your existing code)
	for i in range(fog_points.size() - 1, -1, -1):
		var point = fog_points[i]
		var pos_exists = false
		for target_pos in current_target_positions:
			if point.z == target_pos.x and point.w == target_pos.y:
				pos_exists = true
				break
		if not pos_exists and point.y == 1.0:
			fog_points[i].y = 0.0 # Start fading
			fog_points[i].x = 0.0 # Reset time
	
	# Pass parameters to shader

	var mat: ShaderMaterial = fog_sprite.get_material()
	if mat:
		mat.set_shader_parameter("fog_points", fog_points)
		mat.set_shader_parameter("active_fog_points", fog_points.size())
		mat.set_shader_parameter("scale", Vector2(
			1.0 / fog_sprite.global_scale.x,
			1.0 / fog_sprite.global_scale.y
			)
		)

# Add a target manually
func add_target(target: Node2D):
	if not target in targets:
		targets.append(target)

# Remove a target manually
func remove_target(target: Node2D):
	targets.erase(target)
