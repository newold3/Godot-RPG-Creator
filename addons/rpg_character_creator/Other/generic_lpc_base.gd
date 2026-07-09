@tool
class_name GenericLPCEvent
extends CharacterBase


## Defines how the event is visually represented.
enum DisplayMode {
	EDITOR_LPC, ## Standard mode using the character editor data.
	CUSTOM_IMAGE, ## Uses a single static texture.
	CUSTOM_SCENE ## Instantiates a custom .tscn file.
}

## Determines the visual logic for this event.
## Defaults to EDITOR_LPC (0) for backward compatibility.
@export var display_mode: DisplayMode = DisplayMode.EDITOR_LPC

## The texture to use if display_mode is CUSTOM_IMAGE.
@export var custom_texture: Texture2D

## The scene to instantiate if display_mode is CUSTOM_SCENE.
## To receive movement and direction updates, the root script of the scene must have the function:
## func process_event_state(state: Dictionary) -> void
## The 'state' dictionary contains: { "is_moving": bool, "direction": int (Enum), "delta": float }
@export var custom_scene: PackedScene

var force_disable_breathing: bool
var instanced_scene: Node = null


#region variables
@export var event_data: RPGLPCCharacter
@export var current_event: RPGEvent
@export var current_event_page: RPGEventPage :
	set(value):
		current_event_page = value
		if value:
			if is_node_ready():
				force_disable_breathing = !character_options.idle_animation
				if has_node("%MainTexture"):
					%MainTexture.modulate = current_event_page.modulate

var current_data: Variant = null

var animation_data = {
	"idle_left": [Vector2(0, 0)],
	"idle_down": [Vector2(0, 192)],
	"idle_right": [Vector2(0, 384)],
	"idle_up": [Vector2(0, 576)],
	"walk_left": [Vector2(192, 0), Vector2(384, 0), Vector2(576, 0), Vector2(768, 0), Vector2(960, 0), Vector2(1152, 0), Vector2(1344, 0), Vector2(1536, 0)],
	"walk_down": [Vector2(192, 192), Vector2(384, 192), Vector2(576, 192), Vector2(768, 192), Vector2(960, 192), Vector2(1152, 192), Vector2(1344, 192), Vector2(1536, 192)],
	"walk_right": [Vector2(192, 384), Vector2(384, 384), Vector2(576, 384), Vector2(768, 384), Vector2(960, 384), Vector2(1152, 384), Vector2(1344, 384), Vector2(1536, 384)],
	"walk_up": [Vector2(192, 576), Vector2(384, 576), Vector2(576, 576), Vector2(768, 576), Vector2(960, 576), Vector2(1152, 576), Vector2(1344, 576), Vector2(1536, 576)]
}

#endregion


func get_class() -> String: return "GenericLPCEvent"


func get_custom_class() -> String: return "GenericLPCEvent"


func _build() -> void:
	match display_mode:
		DisplayMode.CUSTOM_IMAGE:
			_build_custom_image()
		DisplayMode.CUSTOM_SCENE:
			_build_custom_scene()
		_: # Default behavior (Legacy/LPC)
			_build_editor_lpc()
			
	if not is_in_group("event"):
		add_to_group("event")


func _build_editor_lpc() -> void:
	# Hide instanced scene if it exists from a previous mode switch
	if instanced_scene:
		instanced_scene.visible = false
		
	if has_node("%MainTexture"):
		%MainTexture.visible = true
		
	if not %MainTexture.texture and event_data:
		var scene_path: String = event_data.scene_path
		
		var regex = RegEx.new()
		regex.compile("_event\\.tscn$")
		var base_name = regex.sub(scene_path.get_file(), "", true)
		
		var texture_path = scene_path.get_base_dir() + "/" + base_name + "_character_minimalist.png"
		
		if ResourceLoader.exists(texture_path):
			var tex = load(texture_path)
			%MainTexture.region_enabled = true
			%MainTexture.region_rect = Rect2(0, 192, 192, 192)
			%MainTexture.texture = tex


func _build_custom_image() -> void:
	if instanced_scene:
		instanced_scene.visible = false
		
	var texture_node: Sprite2D
	
	if has_node("%MainTexture"):
		texture_node = %MainTexture
		texture_node.visible = true
	else:
		texture_node = Sprite2D.new()
		texture_node.name = "MainTexture"
		if has_node("%FullBody"):
			%FullBody.add_child(texture_node)
			texture_node.owner = self
		else:
			add_child(texture_node)
			
	if custom_texture:
		texture_node.texture = custom_texture
		texture_node.region_enabled = false
		texture_node.hframes = 1
		texture_node.vframes = 1
		texture_node.region_rect = Rect2(Vector2.ZERO, custom_texture.get_size())
		
		texture_node.centered = true
		
		texture_node.offset.y = -custom_texture.get_height() / 2.0
		if GameManager.current_map:
			var tile_size: Vector2i = GameManager.get_map_tile_size()
			texture_node.offset.y += tile_size.y - 4


func _build_custom_scene() -> void:
	if has_node("%MainTexture"):
		%MainTexture.visible = false
		
	if custom_scene:
		if not instanced_scene or instanced_scene.scene_file_path != custom_scene.resource_path:
			if instanced_scene:
				instanced_scene.queue_free()
			
			instanced_scene = custom_scene.instantiate()
			
			if has_node("%FullBody"):
				%FullBody.add_child(instanced_scene)
			else:
				add_child(instanced_scene)
		
		instanced_scene.visible = true
		
		instanced_scene.position = Vector2.ZERO


func update_character_rect(region: Rect2) -> void:
	var node = get_node_or_null("%MainTexture")
	if region.has_area():
		node.region_enabled = true
		node.region_rect = region
	else:
		node.region_enabled = false
	
	node.offset.y = -region.size.y / 2.0
	if GameManager.current_map:
		var tile_size: Vector2i = GameManager.get_map_tile_size()
		node.offset.y += tile_size.y + 4


func _ready() -> void:
	super()
	_build()
	
	current_data = event_data
	
	adjust_bounds()
	if Engine.is_editor_hint():
		set_process(false)
		set_process_input(false)
	else:
		if movement_current_mode == MOVEMENTMODE.GRID:
			var current_maps = get_tree().get_nodes_in_group("rpgmap")
			if current_maps:
				var map: RPGMap = GameManager.current_map
				current_map_tile_size = map.tile_size
		calculate_grid_move_duration()
		set_process(true)
		set_process_input(true)


func _manage_animator() -> void:
	if display_mode == DisplayMode.CUSTOM_IMAGE or display_mode == DisplayMode.CUSTOM_SCENE:
		return

	var node = get_node_or_null("%MainAnimator")
	if node and node is AnimationPlayer and node.has_animation("Breathing"):
		if node.is_playing():
			node.stop()
		var restart_time: float = randf_range(1, 4)
		var t = create_tween()
		t.tween_interval(restart_time)
		t.tween_callback(
			func():
				node.speed_scale = randf_range(0.6, 0.8)
				node.play("Breathing")
		)


func _process(delta: float) -> void:
	if GameManager.loading_game or is_invalid_event:
		return
		
	if frame_delay <= frame_delay_max:
		frame_delay += delta
		if frame_delay >= frame_delay_max:
			frame_delay = 0
			_update_frame(delta)


func run_animation() -> void:
	_update_frame(0.0)


func _update_frame(delta: float = 0.0):
	if not is_moving and current_animation != "idle":
		await get_tree().process_frame
		_animation_to_idle.call_deferred()
	elif is_moving:
		current_animation = "walk"
	
	match display_mode:
		DisplayMode.CUSTOM_SCENE:
			_sync_custom_scene_state(delta)
		DisplayMode.CUSTOM_IMAGE:
			pass
		_: # Default behavior (Legacy/LPC)
			_update_frame_lpc()


func _update_frame_lpc() -> void:
	if self.current_animation == "idle" and %MainAnimator.get_current_animation() != "Breathing" and not force_disable_breathing:
		%MainAnimator.play("Breathing")
	elif self.current_animation != "idle":
		%MainAnimator.play("RESET")
		
	var animation_id = current_animation.to_lower() + "_" + str(DIRECTIONS.find_key(current_direction)).to_lower()
	
	if not animation_data.has(animation_id):
		return
		
	var current_anim_array = animation_data[animation_id]
	current_frame += 1
	
	if current_frame >= current_anim_array.size():
		current_frame = 0
	
	if has_node("%MainTexture") and %MainTexture.texture:
		%MainTexture.region_rect.position = current_anim_array[current_frame]


## Looks for 'process_event_state' in the custom scene and passes data to it.
func _sync_custom_scene_state(delta: float) -> void:
	if not instanced_scene: return
	
	if instanced_scene.has_method("process_event_state"):
		var state = {
			"is_moving": is_moving,
			"direction": current_direction,
			"delta": delta
		}
		instanced_scene.call("process_event_state", state)


func get_icon() -> Texture2D:
	var tex: Texture2D
	
	if current_event_page:
		# lpc character, image
		if current_event_page.character_type in [0, 1]:
			tex = %MainTexture.texture
		if not tex: tex = GameManager.get_empty_texture()
	
	return tex


## Formats and returns the shadow data array based on the current event display mode
func get_shadow_data() -> Dictionary:
	if is_on_vehicle or is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
		
	var parent_body = get_node_or_null("%FullBody")
	if not parent_body:
		parent_body = self
		
	var global_pos = parent_body.global_position
	
	var shadow_dict = {
		"position": global_pos,
		"textures": [],
		"positions": [],
		"regions": [],
		"feet_offsets": [],
		"mask_offsets": [],
		"alpha": parent_body.modulate.a,
		"scale": parent_body.scale,
		"rotation": parent_body.rotation,
		"flip_h": false
	}
	
	var sprites_to_process = []
	var is_custom_image = (display_mode == DisplayMode.CUSTOM_IMAGE)
	var custom_global_pos = global_pos
	
	match display_mode:
		DisplayMode.CUSTOM_IMAGE:
			var main_tex: Sprite2D = get_node_or_null("%MainTexture")
			if main_tex and main_tex.texture:
				sprites_to_process.append(main_tex)
				var tile_size = GameManager.get_map_tile_size()
				custom_global_pos.y -= tile_size.y - 2
				shadow_dict.position = custom_global_pos
				
		DisplayMode.CUSTOM_SCENE:
			if instanced_scene:
				if instanced_scene.has_method("get_shadow_data"):
					return instanced_scene.get_shadow_data()
				elif instanced_scene.has_method("get_shadow_sprites"):
					var scene_sprites = instanced_scene.call("get_shadow_sprites")
					if scene_sprites is Array:
						sprites_to_process.append_array(scene_sprites)
						
		_:
			var main_tex: Sprite2D = get_node_or_null("%MainTexture")
			if main_tex and main_tex.texture:
				sprites_to_process.append(main_tex)
				
	for s in sprites_to_process:
		if is_instance_valid(s) and s is Sprite2D and s.visible and s.texture:
			shadow_dict.textures.append(s.texture)
			if is_custom_image:
				shadow_dict.positions.append(custom_global_pos)
				shadow_dict.mask_offsets.append(s.offset)
			else:
				shadow_dict.positions.append(s.global_position)
				shadow_dict.mask_offsets.append(s.offset)
			var h_half = s.texture.get_size().y / 2.0
			var region_rect = Rect2(Vector2.ZERO, s.texture.get_size())
			if s.region_enabled:
				region_rect = s.region_rect
				h_half = region_rect.size.y / 2.0
			shadow_dict.regions.append(region_rect)
			if is_custom_image:
				shadow_dict.feet_offsets.append(h_half)
			else:
				shadow_dict.feet_offsets.append(16.0)
			if s.flip_h:
				shadow_dict.flip_h = true
				
	if shadow_dict.textures.is_empty():
		return {}
		
	return shadow_dict


#region event's functions
## Returns whether this event can be passed through.
func is_passable() -> bool:
	return EventManager.is_passable(self)


## Returns whether this event can be lifted.
func is_liftable() -> bool:
	return EventManager.is_liftable(self)


## Returns whether this event can be moved.
func is_moveable() -> bool:
	return EventManager.is_moveable(self)


## Returns whether this event is currently pressed.
func is_pressed() -> bool:
	return EventManager.is_pressed(self)


## Calculates the next tile coordinate to move toward the target event.
func _get_next_move_toward_event() -> Vector2i:
	return EventManager.get_next_move_toward_event(self)


## Starts the lifting animation logic.
func _start_lift_animation() -> void:
	EventManager.start_lift_animation(self)


## Starts the event interaction.
func start(obj: Node, launcher_mode: RPGEnums.LauncherMode) -> bool:
	return EventManager.start_event(self, obj, launcher_mode)
#endregion
