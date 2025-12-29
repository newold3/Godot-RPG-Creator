class_name SpriteFramesAnimatedTexture
extends RefCounted

func get_class() -> String:
	return "SpriteFramesAnimatedTexture"


signal updated()

var sprite_frames: SpriteFrames
var current_animation: String = ""
var current_frame: int = 0
var frame_timer: float = 0.0
var is_playing: bool = true
var animation_speed: float = 1.0


# Load directly from an AnimatedSprite2D node
func load_from_node(node: AnimatedSprite2D, free_node: bool = false) -> bool:
	if not node:
		push_error("Node is null")
		return false
	
	if not node is AnimatedSprite2D:
		push_error("Node is not an AnimatedSprite2D")
		return false
	
	sprite_frames = node.sprite_frames
	
	if not sprite_frames:
		push_error("AnimatedSprite2D has no SpriteFrames assigned")
		return false
	
	_setup_first_animation()
	
	# Free the node if requested
	if free_node:
		node.queue_free()
	
	return true

# Load from a path (can be .tres SpriteFrames or .tscn with AnimatedSprite2D)
func load_from_path(path: String) -> bool:
	var resource = load(path)
	
	if not resource:
		push_error("Could not load resource: " + path)
		return false
	
	# If it's a SpriteFrames directly
	if resource is SpriteFrames:
		sprite_frames = resource
		_setup_first_animation()
		return true
	
	# If it's a scene, search for AnimatedSprite2D
	if resource is PackedScene:
		var instance = resource.instantiate()
		var found = false
		
		if instance is AnimatedSprite2D:
			sprite_frames = instance.sprite_frames
			found = true
		else:
			# Search in children
			for child in instance.get_children():
				if child is AnimatedSprite2D:
					sprite_frames = child.sprite_frames
					found = true
					break
		
		instance.free()
		
		if found:
			_setup_first_animation()
			return true
		else:
			push_error("AnimatedSprite2D not found in scene: " + path)
			return false
	
	push_error("Resource is neither SpriteFrames nor PackedScene: " + path)
	return false

# Set up the first available animation
func _setup_first_animation():
	if not sprite_frames:
		return
	
	var animations = sprite_frames.get_animation_names()
	if animations.size() > 0:
		current_animation = animations[0]
		current_frame = 0
		frame_timer = 0.0

# Set specific animation (with fallback to first if it doesn't exist)
func set_animation(anim_name: String) -> bool:
	if not sprite_frames:
		push_error("No SpriteFrames loaded")
		return false
	
	var animations = sprite_frames.get_animation_names()
	
	if animations.has(anim_name):
		current_animation = anim_name
		current_frame = 0
		frame_timer = 0.0
		return true
	else:
		push_warning("Animation '" + anim_name + "' not found. Using first available.")
		_setup_first_animation()
		return false

# Manual update (must be called from _process)
func update(delta: float):
	if not is_playing or not sprite_frames:
		return
	
	var fps = sprite_frames.get_animation_speed(current_animation) * animation_speed
	if fps <= 0:
		return
	
	var frame_duration = 1.0 / fps
	frame_timer += delta
	
	var frame_changed = false
	
	while frame_timer >= frame_duration:
		frame_timer -= frame_duration
		current_frame += 1
		frame_changed = true
		
		var frame_count = sprite_frames.get_frame_count(current_animation)
		
		if current_frame >= frame_count:
			if sprite_frames.get_animation_loop(current_animation):
				current_frame = 0
			else:
				current_frame = frame_count - 1
				is_playing = false
				break
	
	# Emit signal when frame changes
	if frame_changed:
		updated.emit()

# Get the current texture
func get_current_texture() -> Texture2D:
	if sprite_frames and current_animation != "":
		return sprite_frames.get_frame_texture(current_animation, current_frame)
	return null

# Playback control
func play():
	is_playing = true

func stop():
	is_playing = false
	current_frame = 0
	frame_timer = 0.0

func pause():
	is_playing = false

func resume():
	is_playing = true

# Configuration
func set_speed_scale(speed: float):
	animation_speed = speed

func get_animation_names() -> PackedStringArray:
	if sprite_frames:
		return sprite_frames.get_animation_names()
	return PackedStringArray()

func get_current_animation() -> String:
	return current_animation

func is_animation_playing() -> bool:
	return is_playing
