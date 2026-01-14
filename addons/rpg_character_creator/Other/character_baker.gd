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
## Added [param actor_id] to fetch real equipment from the database.
func request_bake_character(id: String, data: RPGLPCCharacter, weapon_anim: String, 
		target_wings: Sprite2D, 
		target_off_back: Sprite2D,
		target_wb: Sprite2D, 
		target_body: Sprite2D, 
		target_off_front: Sprite2D,
		target_wf: Sprite2D,
		actor_id: int = -1) -> void:

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
		"target_wf": target_wf,
		"actor_id": actor_id
	})
	_process_queue()


## Queues a request to bake a list of weapon animations.
## Added [param actor_id] to fetch real equipment from the database.
func request_bake_weapon(id: String, data: RPGLPCCharacter, animations: Array, result_map: Dictionary, actor_id: int = -1) -> void:
	_queue.append({
		"type": "weapon_batch",
		"id": id,
		"data": data,
		"anims": animations,
		"target": result_map,
		"actor_id": actor_id
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
	# Resolve correct gear data before baking
	var data: RPGLPCCharacter = _get_updated_character_data(task.data, task.actor_id)
	
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
	
	# Apply visibility rules
	_apply_visibility_rules(data)
	
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
	# Resolve correct gear data before baking weapons
	var data: RPGLPCCharacter = _get_updated_character_data(task.data, task.actor_id)
	var animations: Array = task.anims
	var results: Dictionary = task.target
	
	for anim in animations:
		_clear_viewport(vp_weapon_back)
		_clear_viewport(vp_weapon_front)
		
		_setup_specific_weapon_viewports(data, anim, MAINHAND_KEYS, vp_weapon_back, vp_weapon_front)
		
		_apply_visibility_rules(data, true)
		
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
		_clear_viewport(vp_weapon_front)
		
		var ammo_paths = _get_weapon_paths_for_animation(ammo_part, "walk")
		
		_apply_single_weapon_layer(vp_weapon_back, "mainhandBack", ammo_part, ammo_paths.back)
		_apply_single_weapon_layer(vp_weapon_front, "mainhandFront", ammo_part, ammo_paths.front)
		
		_apply_visibility_rules(data, true)
		
		vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp_weapon_front.render_target_update_mode = SubViewport.UPDATE_ONCE
		
		await RenderingServer.frame_post_draw
		
		results["ammo"] = {
			"back": _get_img(vp_weapon_back),
			"front": _get_img(vp_weapon_front)
		}
		
		var projectile_id = _get_projectile_id_from_part(ammo_part)
		
		if projectile_id != "":
			_clear_viewport(vp_weapon_back)
			
			var proj_path = "res://addons/rpg_character_creator/textures/projectiles/" + projectile_id + ".png"
			
			_apply_single_weapon_layer(vp_weapon_back, "mainhandBack", ammo_part, proj_path)
			
			_apply_visibility_rules(data, true)
			
			vp_weapon_back.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			
			var tex_proj = _get_img(vp_weapon_back)
			results["projectile"] = {
				"back": tex_proj,
				"front": tex_proj 
			}
	
	weapon_baked.emit(task.id, results)


## Checks if the actor has specific gear equipped and updates the character data accordingly.
func _get_updated_character_data(base_data: RPGLPCCharacter, actor_id: int) -> RPGLPCCharacter:
	if actor_id == -1:
		return base_data
	
	var actor = GameManager.get_actor(actor_id)
	if not actor:
		return base_data
		
	var new_data = base_data.duplicate()
	
	var ammo_explicitly_equipped = false
	var weapon_embedded_ammo = null
	
	var _resolve_json_path = func(p: String) -> String:
		if p.is_empty(): return ""
		if p.begins_with("res://"): return p
		return "res://addons/rpg_character_creator/" + p
	
	for item_obj in actor.current_gear:
		if not item_obj:
			continue
			
		var db_item = null
		# Type 1 = Weapon, Type 2 = Armor
		if item_obj.type == 1:
			db_item = RPGSYSTEM.database.weapons.get(item_obj.id)
		elif item_obj.type == 2:
			db_item = RPGSYSTEM.database.armors.get(item_obj.id)
			
		if not db_item:
			continue
		
		var lpc_part_path: String = db_item.lpc_part
		if lpc_part_path.is_empty():
			continue
			
		if not FileAccess.file_exists(lpc_part_path):
			continue
			
		var lpc_part = load(lpc_part_path)
		if lpc_part is RPGLPCEquipmentPart:
			if lpc_part.body_type == new_data.body_type and lpc_part.head_type == new_data.head_type:
				new_data.equipment_parts[lpc_part.part_id] = lpc_part
				
				if lpc_part.part_id == "ammo":
					ammo_explicitly_equipped = true
				elif lpc_part.part_id == "mainhand" and lpc_part.ammo:
					weapon_embedded_ammo = lpc_part.ammo
					
			else:
				if lpc_part.config_path.is_empty() or not FileAccess.file_exists(lpc_part.config_path):
					continue
					
				var f = FileAccess.open(lpc_part.config_path, FileAccess.READ)
				var json_data = JSON.parse_string(f.get_as_text())
				f.close()
				
				if not json_data or not "textures" in json_data:
					continue
					
				var best_match = null
				for t in json_data.textures:
					var t_body = t.get("body", "")
					var t_head = t.get("head", "")
					
					if t_body == new_data.body_type and (t_head == "" or t_head == new_data.head_type):
						best_match = t
						break

				if best_match:
					var fixed_part = lpc_part.duplicate()
					fixed_part.body_type = new_data.body_type
					fixed_part.head_type = new_data.head_type
					fixed_part.front_texture = _resolve_json_path.call(best_match.get("front", ""))
					fixed_part.back_texture = _resolve_json_path.call(best_match.get("back", ""))
					
					new_data.equipment_parts[lpc_part.part_id] = fixed_part
					
					if lpc_part.part_id == "ammo":
						ammo_explicitly_equipped = true
					elif lpc_part.part_id == "mainhand" and lpc_part.ammo:
						weapon_embedded_ammo = lpc_part.ammo

	if not ammo_explicitly_equipped and weapon_embedded_ammo:
		new_data.equipment_parts["ammo"] = weapon_embedded_ammo
		
	return new_data


func _get_projectile_id_from_part(part: RPGLPCEquipmentPart) -> String:
	if not FileAccess.file_exists(part.config_path):
		return ""
		
	var f = FileAccess.open(part.config_path, FileAccess.READ)
	var json_data = JSON.parse_string(f.get_as_text())
	f.close()
	
	if json_data and "projectile" in json_data:
		return json_data["projectile"]
	
	return ""


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
