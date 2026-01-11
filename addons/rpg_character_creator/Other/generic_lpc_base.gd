class_name GenericLPCEvent
extends CharacterBase


func get_class() -> String: return "GenericLPCEvent"
func get_custom_class() -> String: return "GenericLPCEvent"


var force_disable_breathing: bool


#region variables
@export var event_data: RPGLPCCharacter
@export var current_event: RPGEvent
@export var current_event_page: RPGEventPage :
	set(value):
		current_event_page = value
		if value:
			if is_node_ready():
				#%FinalCharacter.get_material().set_shader_parameter("force_disable_breathing", !character_options.idle_animation)
				#%FinalCharacter.get_material().set_shader_parameter("blend_color", current_event_page.modulate)
				force_disable_breathing = !character_options.idle_animation
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


# call only if Main texture is empty
func _build() -> void:
	if not %MainTexture.texture:
		var scene_path: String = event_data.scene_path
		
		var regex = RegEx.new()
		regex.compile("_event\\.tscn$")
		var base_name = regex.sub(scene_path.get_file(), "", true)
		
		var texture_path = scene_path.get_base_dir() + "/" + base_name + "_character_minimalist.png"
		
		if ResourceLoader.exists(texture_path):
			var tex = load(texture_path)
			
			var atlas = AtlasTexture.new()
			atlas.region = Rect2(0, 192, 192, 192) # Starting position = 0, 192 = idle down
			atlas.set_local_to_scene(true)
			atlas.atlas = tex
			%MainTexture.texture = atlas

	if not is_in_group("event"):
		add_to_group("event")


func _ready() -> void:
	super()
	_build()
	
	current_data = event_data
	#%FinalCharacter.get_material().set_shader_parameter("random_offset", randf_range(0, 800.0))
	
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
		


func set_modulate(color: Color) -> void:
	%FinalCharacter.modulate = color


func _manage_animator() -> void:
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
	if GameManager.loading_game:
		return
		
	if frame_delay <= frame_delay_max:
		frame_delay += delta
		if frame_delay >= frame_delay_max:
			frame_delay = 0
			_update_frame()


func is_passable() -> bool:
	return character_options.passable


func _update_frame():
	#if Engine.is_editor_hint(): return
	#%FinalCharacter.get_material().set_shader_parameter("enable_breathing", self.current_animation == "idle")
	current_animation = "walk" if is_moving else "idle"
	if self.current_animation == "idle" and %MainAnimator.get_current_animation() != "Breathing" and not force_disable_breathing:
		%MainAnimator.play("Breathing")
	elif self.current_animation != "idle":
		%MainAnimator.play("RESET")
	var animation_id = current_animation.to_lower() + "_" + str(DIRECTIONS.find_key(current_direction)).to_lower()
	var current_animation = animation_data[animation_id]
	current_frame += 1
	
	if current_frame >= current_animation.size():
		current_frame = 0
	
	if %MainTexture.texture and %MainTexture.texture is AtlasTexture:
		%MainTexture.texture.region.position = current_animation[current_frame]


func get_shadow_data() -> Dictionary:
	if is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
		
	var shadow = {
		"main_node": %FullBody,
		"sprites": [%MainTexture],
		"position": %FullBody.global_position,
		"feet_offset": 16
	}
	if GameManager.current_map:
		shadow.cell = Vector2i(global_position / Vector2(GameManager.current_map.tile_size))
	
	return shadow


func _get_next_move_toward_event() -> Vector2i:
	var goal = Vector2i.ZERO
	var target_screen_position: Vector2 = Vector2.ZERO
	
	if current_event_page and GameManager.current_map:
		var event = GameManager.current_map.get_in_game_event(current_event_page.movement_to_target - 1)
		if event and event.has_method("get_current_tile"):
			goal = event.get_current_tile()
			target_screen_position = event.get_global_transform_with_canvas().origin
	else:
		return goal
	
	return _get_next_move_toward_target(goal, target_screen_position)


func start(obj: Node, launcher_mode: RPGEventPage.LAUNCHER_MODE) -> bool:
	if is_invalid_event: return false
	
	# update interactive_events_found stat
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
