class_name CharacterBaker
extends Node2D

## Emitted when the full character update is finished.
signal character_baked(id: String)

## Emitted when the weapon batch process is finished.
## The dictionary passed in the request is returned filled with textures.
signal weapon_baked(id: String, result: Dictionary)


@onready var vp_wings: SubViewport = %WingsBack
@onready var vp_weapon_back: SubViewport = %WeaponBack
@onready var vp_body: SubViewport = %Body
@onready var vp_weapon_front: SubViewport = %WeaponFront


const BODY_KEYS = [
	"body", "head", "eyes", "wings", "tail", "horns",
	"hair", "hairadd", "ears", "nose", "facial",
	"add1", "add2", "add3"
]

const CLOTHING_KEYS = [
	"mask", "hat", "glasses", "suit", "jacket", "shirt",
	"gloves", "belt", "pants", "shoes", "back", "ammo"
]

const WEAPON_KEYS = [
	"mainhand", "offhand"
]


var _queue: Array[Dictionary] = []
var _is_baking: bool = false


## Queues a request to bake the character and update specific Sprite2D nodes.
## This handles the 4 layers (Wings, Weapon Back, Body, Weapon Front).
func request_bake_character(id: String, data: RPGLPCCharacter, weapon_anim: String, target_wings: Sprite2D, target_wb: Sprite2D, target_body: Sprite2D, target_wf: Sprite2D) -> void:
	_queue.append({
		"type": "character",
		"id": id,
		"data": data,
		"anim": weapon_anim,
		"target_wings": target_wings,
		"target_wb": target_wb,
		"target_body": target_body,
		"target_wf": target_wf
	})
	_process_queue()


## Queues a request to bake a list of weapon animations.
## [param result_map] should be an empty Dictionary; it will be filled with:
## { "anim_name": { "back": ImageTexture, "front": ImageTexture } }
func request_bake_weapon(id: String, data: RPGLPCCharacter, animations: Array, result_map: Dictionary) -> void:
	_queue.append({
		"type": "weapon_batch",
		"id": id,
		"data": data,
		"anims": animations,
		"target": result_map
	})
	_process_queue()


func _process_queue() -> void:
	if _is_baking or _queue.is_empty():
		return
	
	_is_baking = true
	var task = _queue.pop_front()
	match task.type:
		"character":
			await _bake_character_internal(task)
		"weapon_batch":
			await _bake_weapon_batch_internal(task)
	
	# Allow the RenderingServer to catch up before next task
	await RenderingServer.frame_post_draw
	
	_is_baking = false
	
	if not _queue.is_empty():
		_process_queue()


func _bake_character_internal(task: Dictionary) -> void:
	var data: RPGLPCCharacter = task.data
	
	# Reset viewports
	_clear_viewport(vp_wings)
	_clear_viewport(vp_weapon_back)
	_clear_viewport(vp_body)
	_clear_viewport(vp_weapon_front)
	
	# Setup layers
	_setup_wings_viewport(data)
	_setup_body_viewport(data)
	_setup_weapon_viewports(data, task.anim)
	
	_apply_visibility_rules(task.data)
	
	# Render
	vp_wings.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_body.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	await RenderingServer.frame_post_draw
	
	# Capture
	var tex_wings = ImageTexture.create_from_image(vp_wings.get_texture().get_image())
	var tex_wb = ImageTexture.create_from_image(vp_weapon_back.get_texture().get_image())
	var tex_body = ImageTexture.create_from_image(vp_body.get_texture().get_image())
	var tex_wf = ImageTexture.create_from_image(vp_weapon_front.get_texture().get_image())
	
	# Update Targets
	_update_sprite(task.target_wings, tex_wings)
	_update_sprite(task.target_wb, tex_wb)
	_update_sprite(task.target_body, tex_body)
	_update_sprite(task.target_wf, tex_wf)
	
	character_baked.emit(task.id)


func _bake_weapon_batch_internal(task: Dictionary) -> void:
	var data: RPGLPCCharacter = task.data
	var animations: Array = task.anims
	var results: Dictionary = task.target
	
	
	for anim in animations:
		_clear_viewport(vp_weapon_back)
		_clear_viewport(vp_weapon_front)
		
		_setup_weapon_viewports(data, anim)
		_apply_visibility_rules(task.data)
		
		vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
		
		await RenderingServer.frame_post_draw
		
		var tex_wb = ImageTexture.create_from_image(vp_weapon_back.get_texture().get_image())
		var tex_wf = ImageTexture.create_from_image(vp_weapon_front.get_texture().get_image())
		results[anim] = {
			"back": tex_wb,
			"front": tex_wf
		}
	
	weapon_baked.emit(task.id, results)


func _update_sprite(node: Sprite2D, texture: Texture2D) -> void:
	if is_instance_valid(node):
		node.texture = texture


func _setup_wings_viewport(data: RPGLPCCharacter) -> void:
	if data.body_parts.get("wings"):
		_apply_texture_data(vp_wings, "wings", data.body_parts["wings"])


func _setup_body_viewport(data: RPGLPCCharacter) -> void:
	for key in BODY_KEYS:
		if data.body_parts.get(key):
			_apply_texture_data(vp_body, key, data.body_parts[key])
			
	for key in CLOTHING_KEYS:
		if data.equipment_parts.get(key):
			_apply_texture_data(vp_body, key, data.equipment_parts[key])


func _setup_weapon_viewports(data: RPGLPCCharacter, animation_id: String) -> void:
	for key in WEAPON_KEYS:
		var part = data.equipment_parts.get(key)
		if part:
			if data.body_type == part.body_type and data.head_type == part.head_type:
				var specific_textures = _get_weapon_paths_for_animation(part, animation_id)
				_apply_single_weapon_layer(vp_weapon_back, key + "Back", part, specific_textures.back)
				_apply_single_weapon_layer(vp_weapon_front, key + "Front", part, specific_textures.front)


func _apply_texture_data(viewport: SubViewport, part_id: String, part_data: Resource) -> void:
	var container = viewport.get_node_or_null("Container")
	if not container: container = viewport
	
	var node_back = _find_node_insensitive(container, part_id + "Back")
	if node_back:
		_setup_node(node_back, part_data, true, part_data.back_texture)
		
	var node_front = _find_node_insensitive(container, part_id + "Front")
	if node_front:
		_setup_node(node_front, part_data, false, part_data.front_texture)
		
	if not node_back and not node_front:
		var node_single = _find_node_insensitive(container, part_id)
		if node_single:
			_setup_node(node_single, part_data, false, part_data.front_texture)


## Handles weapon layers, ensuring the viewport resizes to match the texture (e.g., for large spritesheets).
func _apply_single_weapon_layer(viewport: SubViewport, node_name: String, part_data: Resource, texture_path: String) -> void:
	var container = viewport.get_node_or_null("Container")
	if not container: container = viewport
	
	var node = _find_node_insensitive(container, node_name)
	if node:
		if not ResourceLoader.exists(texture_path):
			_setup_node(node, part_data, false, texture_path)
			return
			
		var tex = load(texture_path)
		if tex:
			viewport.size = tex.get_size()
			
		_setup_node(node, part_data, false, texture_path)


func _setup_node(node: TextureRect, data: Variant, _is_back: bool, texture_path: String) -> void:
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		node.visible = false
		return

	node.texture = load(texture_path)
	node.size = node.texture.get_size()
	node.position = Vector2.ZERO
	node.visible = true
	
	if node.material is ShaderMaterial:
		var mat = node.material as ShaderMaterial
		mat.set_shader_parameter("palette1", get_gradient(data.palette1.colors))
		mat.set_shader_parameter("palette2", get_gradient(data.palette2.colors))
		mat.set_shader_parameter("palette3", get_gradient(data.palette3.colors))
		mat.set_shader_parameter("lightness1", data.palette1.lightness)
		mat.set_shader_parameter("lightness2", data.palette2.lightness)
		mat.set_shader_parameter("lightness3", data.palette3.lightness)


## Parses the weapon JSON config to find the texture matching the requested animation ID.
func _get_weapon_paths_for_animation(part: RPGLPCEquipmentPart, animation_id: String) -> Dictionary:
	var paths = {"front": "", "back": ""}
	
	if not FileAccess.file_exists(part.config_path):
		paths.front = part.front_texture
		paths.back = part.back_texture
		return paths
		
	var f = FileAccess.open(part.config_path, FileAccess.READ)
	var weapon_data = JSON.parse_string(f.get_as_text())
	f.close()
	
	if not weapon_data:
		return paths
		
	var body_type = part.body_type
	var head_type = part.head_type
	var texture_found = false
	
	# First pass: try to find exact animation match
	for texture in weapon_data.get("textures", []):
		var t_body = texture.get("body", body_type)
		var t_head = texture.get("head", head_type)
		var t_spriteset = texture.get("spritesheet", "")
		
		if t_body == body_type and t_head == head_type and t_spriteset.find(animation_id) != -1:
			paths.front = "res://addons/rpg_character_creator/" + texture.get("front", "")
			paths.back = "res://addons/rpg_character_creator/" + texture.get("back", "")
			texture_found = true
			break
			
	# Second pass: fallback to base char texture
	if not texture_found:
		for texture in weapon_data.get("textures", []):
			var t_body = texture.get("body", body_type)
			var t_head = texture.get("head", head_type)
			var t_spriteset = texture.get("spritesheet", "")
			
			if (t_body == body_type and t_head == head_type and (t_spriteset == "char_base" or t_spriteset == "")):
				paths.front = "res://addons/rpg_character_creator/" + texture.get("front", "")
				paths.back = "res://addons/rpg_character_creator/" + texture.get("back", "")
				break
	
	return paths


func get_gradient(color_array: PackedInt64Array) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray([])
	colors.resize(256)
	if color_array.size() > 0:
		for i in range(0, color_array.size(), 2):
			var index = int(color_array[i])
			var color = Color(int(color_array[i+1]))
			colors[index] = color
	return colors


func _find_node_insensitive(parent: Node, partial_name: String) -> Node:
	for child in parent.get_children():
		if child.name.to_lower() == partial_name.to_lower():
			return child
	return null


func _clear_viewport(vp: SubViewport) -> void:
	if vp == vp_weapon_back or vp == vp_weapon_front:
		vp.size = Vector2i(1, 1)
		
	var container = vp.get_node_or_null("Container")
	if not container: container = vp
	for child in container.get_children():
		if child is TextureRect:
			child.visible = false
			child.position = Vector2.ZERO


## Applies visibility rules based on the character data configuration.
func _apply_visibility_rules(data: RPGLPCCharacter) -> void:
	if not data.always_show_weapon:
		var weapon_keys = ["mainhand", "offhand", "ammo"]
		for key in weapon_keys:
			_set_nodes_visibility(key, false)
	
	for key in data.hidden_items:
		_set_nodes_visibility(key, false)


## Searches across all viewports for nodes matching the part_id and sets their visibility.
## Handles suffixes like "Back" and "Front" automatically.
func _set_nodes_visibility(part_id: String, visible_state: bool) -> void:
	var viewports = [vp_wings, vp_weapon_back, vp_body, vp_weapon_front]
	var suffixes = ["", "Back", "Front"]
	
	for vp in viewports:
		var container = vp.get_node_or_null("Container")
		if not container:
			container = vp
		
		for suffix in suffixes:
			var target_name = part_id + suffix
			var node = _find_node_insensitive(container, target_name)
			if node:
				node.visible = visible_state
