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


func is_passable() -> bool:
	return character_options.passable


func _update_frame(delta: float = 0.0):
	current_animation = "walk" if is_moving else "idle"
	
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


func get_shadow_data() -> Dictionary:
	if is_on_vehicle or is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
		
	var parent_body = get_node_or_null("%FullBody")
	if not parent_body:
		parent_body = self
		
	var shadow_data = {
		"main_node": parent_body,
		"position": parent_body.global_position,
		"feet_offset": 16,
		"sprites": []
	}
		
	
	match display_mode:
		DisplayMode.CUSTOM_IMAGE:
			if has_node("%MainTexture"):
				shadow_data.sprites.append(%MainTexture)
				shadow_data.event_type = "CUSTOM_IMAGE"
				if %MainTexture.texture:
					var tile_size = GameManager.get_map_tile_size()
					shadow_data.position.y += %MainTexture.offset.y - %MainTexture.texture.get_height() * 0.5 + tile_size.y - 4
					shadow_data.position.x -= tile_size.x / 2
					shadow_data.feet_offset = %MainTexture.texture.get_width() / 2
				
		DisplayMode.CUSTOM_SCENE:
			if instanced_scene:
				# If the scene wants to handle its own shadow data completely
				if instanced_scene.has_method("get_shadow_sprites"):
					shadow_data.sprites = instanced_scene.call("get_shadow_sprites")
				else:
					# Fallback: treat the scene root as the main object
					shadow_data.main_node = instanced_scene
					shadow_data.position = instanced_scene.global_position
				shadow_data.event_type = "CUSTOM_SCENE"
		_: # Default behavior (Legacy/LPC)
			if has_node("%MainTexture"):
				shadow_data.sprites.append(%MainTexture)
				shadow_data.event_type = "EDITOR_LPC"

	if GameManager.current_map:
		var tile_size: Vector2 = GameManager.get_map_tile_size()
		shadow_data.cell = Vector2i(parent_body.global_position / tile_size)
	
	return shadow_data


func _get_next_move_toward_event() -> Vector2i:
	var goal = Vector2i.ZERO
	var target_screen_position: Vector2 = Vector2.ZERO
	
	if current_event_page and GameManager.current_map:
		var event = GameManager.current_map.get_in_game_event_by_uniq_id(current_event_page.movement_to_target)
		if event and event.has_method("get_current_tile"):
			goal = event.get_current_tile()
			target_screen_position = event.get_global_transform_with_canvas().origin
	else:
		return goal
	
	return _get_next_move_toward_target(goal, target_screen_position)


func is_pressed() -> bool:
	if is_in_group("event") and GameManager.current_map:
		if current_event_page and current_event_page.condition.use_pressure:
			return true
	
	return false


func start(obj: Node, launcher_mode: RPGEventPage.LAUNCHER_MODE) -> bool:
	if is_invalid_event: return false
	
	if GameManager.game_state and GameManager.current_map:
		var id = "%s_%s" % [GameManager.current_map.internal_id, current_event.id]
		if not id in GameManager.game_state.stats.interactive_events_found:
			GameManager.game_state.stats.interactive_events_found[id] = true
	
	if obj in targets_over_me:
		return false
	
	if QuestManager.manage_mission_for_event(current_event):
		return false
		
	if current_event_page:
		if current_event_page.launcher != launcher_mode:
			return false
		if not current_event_page.options.fixed_direction and "current_direction" in obj:
			last_direction = get_opposite_direction(obj.current_direction)
			current_direction = last_direction
				
		var interpreter_id = "event_" + str(current_event.id)
		GameInterpreter.start_event(self, current_event_page.list, false, interpreter_id)
	
	targets_over_me.append(obj)
	
	return true
