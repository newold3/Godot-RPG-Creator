@tool
extends StaticBody2D

func get_class() -> String:
	return "RPGExtractionScene"

## Node used as a texture for when the item is not depleted.
@export var main_node: Node
## Node used as a texture for when the item is depleted.
@export var depleted_node: Node
## Particle node used to highlight the item when it can be collected.
@export var particle_node: GPUParticles2D
## Particle node used when this node is being extracted.
@export var extraction_particles: GPUParticles2D
## Label used to show the name of this event.
@export var name_label: Label
## Collision shape used to block pass  for player and events
@export var collision_shape: CollisionShape2D

var data: RPGExtractionItem: set = _set_data
var extraction_data: GameExtractionItem
var is_started: bool = false
var label_animation_tween: Tween
var max_distance_visibility: float = 100_000.0
var is_visible_to_player: bool = false
var need_refresh_collision: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		%FinalShadow.texture = %ViewportTextures.get_texture()
		%FinalSprite.texture = %ViewportTextures.get_texture()
	
	if not is_in_group("extraction_event"):
		add_to_group("extraction_event")

	start()


func _physics_process(_delta):
	var player = GameManager.current_player
	if player:
		var distance_squared = global_position.distance_squared_to(player.get_current_position())
		var should_be_visible = distance_squared <= max_distance_visibility
		if should_be_visible != is_visible_to_player:
			is_visible_to_player = should_be_visible
			(_on_screen_entered() if should_be_visible else _on_screen_exited())
		
		if need_refresh_collision and collision_shape:
			if player.get_current_tile() == get_current_tile() and not collision_shape.is_disabled():
				collision_shape.set_deferred("disabled", true)
				return
			elif player.get_current_tile() != get_current_tile() and collision_shape.is_disabled():
				collision_shape.set_deferred("disabled", false)
				return
			
			if not collision_shape.is_disabled():
				need_refresh_collision = false
			


func _on_screen_entered() -> void:
	if particle_node:
		particle_node.emitting = true
	if label_animation_tween:
		label_animation_tween.kill()
	label_animation_tween = create_tween()
	if name_label:
		label_animation_tween.tween_property(name_label, "modulate:a", 1.0, 2.5).set_trans(Tween.TRANS_SINE)


func _on_screen_exited() -> void:
	if particle_node:
		particle_node.emitting = false
	if label_animation_tween:
		label_animation_tween.kill()
	label_animation_tween = create_tween()
	if name_label:
		label_animation_tween.tween_property(name_label, "modulate:a", 0.0, 2.5).set_trans(Tween.TRANS_SINE)


func refresh() -> void:
	if data:
		_set_data(data)


func _set_data(p_data: RPGExtractionItem) -> void:
	data = p_data
	if name_label:
		var absolute_level: int = data.current_level
		var profession: RPGProfession = data.get_profession()
		
		if profession:
			absolute_level = GameManager.get_profession_absolute_item_level(data, profession)
			var text_color: Color = GameManager.get_profession_extraction_text_color(data, profession)
			name_label.set("theme_override_colors/font_color", text_color)
			
		name_label.text = data.name + " (" + str(absolute_level) + ")"


func start(ignore_animations: bool = false) -> void:
	if not ignore_animations:
		pass
	if main_node:
		main_node.visible = true
	if depleted_node:
		depleted_node.visible = false
	if particle_node:
		particle_node.emitting = true
	if extraction_particles:
		extraction_particles.emitting = false
	is_started = true
	%CollisionShape2D.set_deferred("disabled", false)
	visible = true
	need_refresh_collision = true


func end(ignore_animations: bool = false) -> void:
	if not ignore_animations:
		pass
	is_started = false
	if main_node:
		main_node.visible = false
	if depleted_node:
		depleted_node.visible = true
	if particle_node:
		particle_node.emitting = false
	if extraction_particles:
		extraction_particles.emitting = false
	%CollisionShape2D.set_deferred("disabled", true)
	visible = false


func start_extraction() -> void:
	disable_self_particles(true)
	disable_extraction_particles(false)


func end_extraction() -> void:
	disable_self_particles(false)
	disable_extraction_particles(true)


func disable_self_particles(value: bool) -> void:
	if is_started and particle_node:
		particle_node.emitting = !value


func disable_extraction_particles(value: bool) -> void:
	if is_started and particle_node:
		%ExtractionParticles.emitting = !value
		if not value and GameManager.current_player:
			%ExtractionParticles.look_at(GameManager.current_player.position)


func get_shadow_data() -> Dictionary:
	if is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
		
	var foot_node = get_node_or_null("%Foot")
	var main_sprite = get_node_or_null("%MainNode")
	
	if not foot_node or not main_sprite or not main_sprite.texture:
		return {}
		
	var shadow_dict = {
		"position": foot_node.global_position,
		"textures": [main_sprite.texture],
		"positions": [main_sprite.global_position],
		"regions": [],
		"feet_offsets": [12.0],
		"mask_offsets": [main_sprite.offset],
		"alpha": main_sprite.modulate.a,
		"scale": main_sprite.scale,
		"rotation": main_sprite.rotation,
		"flip_h": main_sprite.flip_h
	}
	
	if main_sprite.region_enabled:
		shadow_dict.regions.append(main_sprite.region_rect)
	else:
		shadow_dict.regions.append(Rect2(Vector2.ZERO, main_sprite.texture.get_size()))
		
	return shadow_dict


func get_current_tile() -> Vector2i:
	var map = GameManager.current_map
	if map:
		return map.get_tile_from_position(global_position)
	
	return Vector2i.ZERO
