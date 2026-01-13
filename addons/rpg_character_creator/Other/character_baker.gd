class_name CharacterBaker
extends Node2D

## Emitted when the full character update is finished.
signal character_baked(id: String)

## Emitted when the weapon batch process is finished.
## The dictionary passed in the request is returned filled with textures.
signal weapon_baked(id: String, result: Dictionary)


@onready var vp_wings: SubViewport = %WingsBack
@onready var vp_offhand_back: SubViewport = $OffhandBack
@onready var vp_weapon_back: SubViewport = %WeaponBack
@onready var vp_body: SubViewport = %Body
@onready var vp_offhand_front: SubViewport = $OffHandFront
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

const MAINHAND_KEYS = ["mainhand"]
const OFFHAND_KEYS = ["offhand"]


var _queue: Array[Dictionary] = []
var _is_baking: bool = false


## Queues a request to bake the character and update specific Sprite2D nodes.
## This handles the 6 layers (Wings, Offhand Back, Weapon Back, Body, Offhand Front, Weapon Front).
func request_bake_character(id: String, data: RPGLPCCharacter, weapon_anim: String, 
		target_wings: Sprite2D, 
		target_off_back: Sprite2D,
		target_wb: Sprite2D, 
		target_body: Sprite2D, 
		target_off_front: Sprite2D,
		target_wf: Sprite2D) -> void:
	
	_queue.append({
		"type": "character",
		"id": id,
		"data": data,
		"anim": weapon_anim,
		"target_wings": target_wings,
		"target_off_back": target_off_back,
		"target_wb": target_wb,
		"target_body": target_body,
		"target_off_front": target_off_front,
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
	_clear_viewport(vp_offhand_back)
	_clear_viewport(vp_weapon_back)
	_clear_viewport(vp_body)
	_clear_viewport(vp_offhand_front)
	_clear_viewport(vp_weapon_front)
	
	# Setup layers
	_setup_wings_viewport(data)
	_setup_body_viewport(data)
	
	# Setup Offhand (Shields) - Independent Layer
	_setup_specific_weapon_viewports(data, task.anim, OFFHAND_KEYS, vp_offhand_back, vp_offhand_front)
	
	# Setup Mainhand (Weapons) - Independent Layer
	_setup_specific_weapon_viewports(data, task.anim, MAINHAND_KEYS, vp_weapon_back, vp_weapon_front)
	
	# Apply visibility rules (uses default logic: hide if always_show_weapon is false)
	_apply_visibility_rules(task.data)
	
	# Render
	vp_wings.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_offhand_back.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_body.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_offhand_front.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	await RenderingServer.frame_post_draw
	
	# Update Targets
	_update_sprite(task.target_wings, _get_img(vp_wings))
	_update_sprite(task.target_off_back, _get_img(vp_offhand_back))
	_update_sprite(task.target_wb, _get_img(vp_weapon_back))
	_update_sprite(task.target_body, _get_img(vp_body))
	_update_sprite(task.target_off_front, _get_img(vp_offhand_front))
	_update_sprite(task.target_wf, _get_img(vp_weapon_front))
	
	character_baked.emit(task.id)


func _bake_weapon_batch_internal(task: Dictionary) -> void:
	var data: RPGLPCCharacter = task.data
	var animations: Array = task.anims
	var results: Dictionary = task.target
	
	for anim in animations:
		_clear_viewport(vp_weapon_back)
		_clear_viewport(vp_weapon_front)
		
		_setup_specific_weapon_viewports(data, anim, MAINHAND_KEYS, vp_weapon_back, vp_weapon_front)
		
		_apply_visibility_rules(task.data, true)
		
		vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
		
		await RenderingServer.frame_post_draw
		
		var tex_wb = _get_img(vp_weapon_back)
		var tex_wf = _get_img(vp_weapon_front)
		
		results[anim] = {
			"back": tex_wb,
			"front": tex_wf
		}
	
	var ammo_part = data.equipment_parts.get("ammo")
	if ammo_part:
		_clear_viewport(vp_weapon_back)
		
		_apply_single_weapon_layer(vp_weapon_back, "mainhandBack", ammo_part, ammo_part.front_texture)
		
		_apply_visibility_rules(task.data, true)
		
		vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		
		var tex_ammo = _get_img(vp_weapon_back)
		
		results["ammo"] = {
			"back": tex_ammo,
			"front": tex_ammo
		}

	weapon_baked.emit(task.id, results)


func _update_sprite(node: Sprite2D, texture: Texture2D) -> void:
	if is_instance_valid(node):
		node.texture = texture


func _get_img(vp: SubViewport) -> ImageTexture:
	return ImageTexture.create_from_image(vp.get_texture().get_image())


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


## Sets up weapon viewports for a specific list of keys (Separates Mainhand from Offhand).
func _setup_specific_weapon_viewports(data: RPGLPCCharacter, animation_id: String, keys: Array, vp_back: SubViewport, vp_front: SubViewport) -> void:
	for key in keys:
		var part = data.equipment_parts.get(key)
		if part:
			if data.body_type == part.body_type and data.head_type == part.head_type:
				var specific_textures = _get_weapon_paths_for_animation(part, animation_id)
				_apply_single_weapon_layer(vp_back, key + "Back", part, specific_textures.back)
				_apply_single_weapon_layer(vp_front, key + "Front", part, specific_textures.front)


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


## Handles weapon layers. Since we have separated Viewports for Main/Offhand,
## we can safely resize the viewport to match the current texture exactly.
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
## Handles both specific spritesheets (e.g., "slash") and generic fallbacks.
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
	
	var fix_path = func(p: String) -> String:
		if p.is_empty(): return ""
		if p.begins_with("res://"): return p
		return "res://addons/rpg_character_creator/" + p

	var generic_candidate = {"front": "", "back": ""}
	var found_specific = false

	for texture in weapon_data.get("textures", []):
		var t_body = texture.get("body", body_type)
		var t_head = texture.get("head", head_type)
		
		if t_body != body_type or t_head != head_type:
			continue
			
		var t_spriteset = texture.get("spritesheet", "")
		
		if t_spriteset != "" and t_spriteset.find(animation_id) != -1:
			paths.front = fix_path.call(texture.get("front", ""))
			paths.back = fix_path.call(texture.get("back", ""))
			found_specific = true
			break 
		
		if t_spriteset == "" or t_spriteset == "char_base":
			generic_candidate.front = fix_path.call(texture.get("front", ""))
			generic_candidate.back = fix_path.call(texture.get("back", ""))
	
	if not found_specific:
		if generic_candidate.front != "":
			paths.front = generic_candidate.front
		if generic_candidate.back != "":
			paths.back = generic_candidate.back
	
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
	if vp in [vp_offhand_back, vp_weapon_back, vp_offhand_front, vp_weapon_front]:
		vp.size = Vector2i(1, 1)
		
	var container = vp.get_node_or_null("Container")
	if not container: container = vp
	for child in container.get_children():
		if child is TextureRect:
			child.visible = false
			child.position = Vector2.ZERO


## Applies visibility rules. 
## [param force_weapon_visible] Overrides 'always_show_weapon' logic (for baking weapon lists).
func _apply_visibility_rules(data: RPGLPCCharacter, force_weapon_visible: bool = false) -> void:
	if not data.always_show_weapon and not force_weapon_visible:
		
		var weapon_keys = ["mainhand", "ammo"]
		
		for key in weapon_keys:
			_set_nodes_visibility(key, false)

	for key in data.hidden_items:
		_set_nodes_visibility(key, false)


func _set_nodes_visibility(part_id: String, visible_state: bool) -> void:
	var viewports = [vp_wings, vp_offhand_back, vp_weapon_back, vp_body, vp_offhand_front, vp_weapon_front]
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
