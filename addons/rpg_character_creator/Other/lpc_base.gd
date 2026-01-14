class_name LPCBase
extends CharacterBase


func get_class() -> String: return "LPCBase"
func get_custom_class() -> String: return "LPCBase"


var force_disable_breathing: bool

## Preview Sprite Direction in the editor
@export_enum("Up", "Down", "Left", "Right") var preview_direction = 1 :
	set(value):
		preview_direction = value
		if is_node_ready():
			match value:
				2: current_direction = DIRECTIONS.LEFT
				3: current_direction = DIRECTIONS.RIGHT
				0: current_direction = DIRECTIONS.UP
				_: current_direction = DIRECTIONS.DOWN
			run_animation()


@onready var animations = {
	"player": RPGSYSTEM.player_animations_data.animations,
	"weapon": RPGSYSTEM.weapon_animations_data.animations
}
@onready var full_body: Marker2D = %FullBody
@onready var wings_back: Sprite2D = %WingsBack
@onready var offhand_back: Sprite2D = %OffhandBack
@onready var mainhand_back: Sprite2D = %MainHandBack
@onready var body: Sprite2D = %Body
@onready var offhand_front: Sprite2D = %OffhandFront
@onready var mainhand_front: Sprite2D = %MainHandFront

var ammo_node_back: Sprite2D
var ammo_node_front: Sprite2D


const PROJECTILES = {
	"arrow": preload("res://addons/rpg_character_creator/textures/projectiles/arrow.tscn"),
	"bolt": preload("res://addons/rpg_character_creator/textures/projectiles/bolt.tscn"),
	"rock": preload("res://addons/rpg_character_creator/textures/projectiles/rock.tscn"),
	"arcane1": preload("res://addons/rpg_character_creator/textures/projectiles/arcane1.tscn"),
	"boomerang": preload("res://addons/rpg_character_creator/textures/projectiles/boomerang.tscn")
}

var idle_tween: Tween

var current_data: Variant = null
var current_weapon_images: Dictionary = {}

signal shoot_ammo(ammo_id: String, direction: String, ammo_position: Vector2)


# call only when character creator editor create it
func _build() -> void:
	if get_node_or_null("%FullBody") == null:
		var node = Marker2D.new()
		node.name = "FullBody"
		node.z_index = 1
		node.y_sort_enabled = true
		node.set_unique_name_in_owner(true)
		add_child(node)
		full_body = node
	
	var parent_node = get_node_or_null("%FullBody")
	var mat = CanvasItemMaterial.new()
	var sprites = ["%WingsBack", "%OffhandBack", "%MainHandBack", "%Body", "%OffhandFront", "%MainHandFront"]
	var parts = ["wings_back", "offhand_back", "mainhand_back", "body", "offhand_front", "mainhand_front"]
	for i in sprites.size():
		var node_sprite = get_node_or_null(sprites[i])
		if node_sprite == null:
			var sp = Sprite2D.new()
			sp.name = sprites[i].replace("%", "")
			sp.centered = true
			sp.region_enabled = true
			if i in [0, 2]:
				sp.material = mat
			sp.set_unique_name_in_owner(true)
			parent_node.add_child(sp)
			sp.position = Vector2(0, -32)
			set(parts[i], sp)
		else:
			set(parts[i], node_sprite)
	
	if get_node_or_null("%CollisionShape") == null:
		var node = CollisionShape2D.new()
		node.name = "CollisionShape"
		var shape = CapsuleShape2D.new()
		shape.radius = 5.0
		shape.height = 10.0
		node.shape = shape
		node.set_unique_name_in_owner(true)
		add_child(node)
		node.position = Vector2(0, -7)
	
	if get_node_or_null("%Bounds") == null:
		var node = Node2D.new()
		node.set_unique_name_in_owner(true)
		add_child(node)
	
	var marker_parent = get_node_or_null("%Bounds")
	var markers = ["%Down", "%Up", "%Left", "%Right"]
	var positions = [Vector2(0, 32), Vector2(0, 40), Vector2(0, 32), Vector2(16, 32)]
	for i in markers.size():
		var marker = markers[i]
		var p = positions[i]
		var node_marker = get_node_or_null(marker)
		if node_marker == null:
			var node = Marker2D.new()
			node.name = marker.replace("%", "")
			node.set_unique_name_in_owner(true)
			marker_parent.add_child(node)
			node.texture = ViewportTexture.new()
			node.texture.viewport_path = %ViewportTextures.get_path_to(self)
			node.position = p
		else:
			node_marker.position = p
	
	if get_node_or_null("%ContactArea") == null:
		var node = Area2D.new()
		node.name = "ContactArea"
		node.collision_layer = 7
		node.collision_mask = 7
		node.set_unique_name_in_owner(true)
		add_child(node)
	
	if get_node_or_null("%AreaShape") == null:
		var area_parent = get_node_or_null("%ContactArea")
		var node = CollisionShape2D.new()
		node.name = "AreaShape"
		node.debug_color = Color("#c172356b")
		var shape = RectangleShape2D.new()
		shape.size = Vector2(26, 26)
		node.shape = shape
		area_parent.add_child(node)
		node.position = Vector2(0, -13)


func _ready() -> void:
	if not Engine.is_editor_hint() and full_body and body:
		var s: Sprite2D = body.duplicate()
		s.name = "AmmoBack"
		s.region_enabled = true
		s.unique_name_in_owner = true
		full_body.add_child(s)
		
		ammo_node_back = s
		ammo_node_back.visible = false
		s = body.duplicate()
		s.name = "AmmoFront"
		s.region_enabled = true
		s.unique_name_in_owner = true
		full_body.add_child(s)
		ammo_node_front = s
		ammo_node_front.visible = false
	_setup_contact_shape()
	tree_entered.connect(_on_tree_entered)
	get_tree().create_timer(0.05).timeout.connect(set.bind("can_show_shadows", true))
	install_parts()
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
		shoot_ammo.connect(perform_shoot)
		animation_finished.connect(_on_animation_finished)
		attack.connect(_on_attack)
		calculate_grid_move_duration()
		set_process(true)
		set_process_input(true)
	
	super()


func _process(_delta: float) -> void:
	super(_delta)


func _setup_contact_shape() -> void:
	var node = get_node_or_null("%ContactArea")
	if node and GameManager.current_map:
		var tile_size = GameManager.current_map.tile_size
		var collision_shape = node.get_child(0)
		var shape = collision_shape.shape
		shape.size = tile_size * 0.8
		collision_shape.position = Vector2(0, -shape.size.y / 2)
		if not node.area_entered.is_connected(_on_main_area_entered):
			node.area_entered.connect(_on_main_area_entered)
		node.set_meta("entity", self)
		collision_shape.set_meta("original_data", {"position": collision_shape.position, "shape_size": shape.size})


func _expand_contact_shape(direction: Vector2) -> void:
	var node = get_node_or_null("%ContactArea")
	if not node or not GameManager.current_map:
		return

	var tile_size: Vector2 = GameManager.current_map.tile_size
	var collision_shape: CollisionShape2D = node.get_child(0)
	var shape: RectangleShape2D = collision_shape.shape

	var original_data = collision_shape.get_meta("original_data", null)
	if not original_data:
		return

	var original_size: Vector2 = original_data["shape_size"]
	var original_pos: Vector2 = original_data["position"]

	var expansion: Vector2 = tile_size * 0.4

	var new_size: Vector2 = original_size
	var new_pos: Vector2 = original_pos

	# --- HORIZONTAL ---
	if direction.x > 0:
		new_size.x += expansion.x
		new_pos.x += expansion.x / 2
	elif direction.x < 0:
		new_size.x += expansion.x
		new_pos.x -= expansion.x / 2

	# --- VERTICAL ---
	if direction.y > 0:
		new_size.y += expansion.y
		new_pos.y += expansion.y / 2
	elif direction.y < 0:
		new_size.y += expansion.y
		new_pos.y -= expansion.y / 2

	# Apply
	shape.size = new_size
	collision_shape.position = new_pos


func _reset_contact_shape() -> void:
	var node = get_node_or_null("%ContactArea")
	if not node:
		return

	var collision_shape: CollisionShape2D = node.get_child(0)
	var shape: RectangleShape2D = collision_shape.shape

	var original_data = collision_shape.get_meta("original_data", null)
	if not original_data:
		return

	shape.size = original_data["shape_size"]
	collision_shape.position = original_data["position"]


func _activate_event(entity: Node, list: Array[RPGEventCommand], entity_id: String, is_solid_contact: bool) -> void:
	if is_solid_contact:
		_reset(true)
		entity.look_at_event(self)
		
	var ev = {
		"obj": entity,
		"commands": list,
		"id": entity_id
	}
	var automatic_event: Array[Dictionary] = [ev]
	GameInterpreter.auto_start_automatic_events(automatic_event)
	entity._add_to_ignore(self)


func _on_main_area_entered(area: Area2D) -> void:
	var entity = null if not area.has_meta("entity") else area.get_meta("entity")
	
	if entity:
		if entity._has_ignore_entity(self): return
		var entity_page = entity.get("current_event_page")
		var entity_is_player = entity.is_in_group("player")
		var entity_is_solid = _is_solid(entity)
		var my = self
		var my_page = my.get("current_event_page")
		var my_is_player = my.is_in_group("player")
		var my_is_solid = _is_solid(self)
		
		var is_solid_contact = entity_is_solid and my_is_solid
		
		if entity_page:
			var entity_id = str(entity.get_rid()) + "-Page#" + str(entity_page.page_id)
			if my_is_player and not entity_is_player:
				var entity_page_launcher = entity_page.launcher
				if entity_page_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.PLAYER_COLLISION]:
					_activate_event(entity, entity_page.list, entity_id, is_solid_contact)
			elif not entity_is_player and not my_is_player:
				var entity_page_launcher = entity_page.launcher
				if entity_page_launcher in [RPGEventPage.LAUNCHER_MODE.ANY_CONTACT, RPGEventPage.LAUNCHER_MODE.EVENT_COLLISION]:
					if entity_page_launcher == RPGEventPage.LAUNCHER_MODE.ANY_CONTACT:
						_activate_event(entity, entity_page.list, entity_id, is_solid_contact)
					else:
						var entity_page_id = entity_page.get("id")
						var my_trigger_list = my_page.get("event_trigger_list")
						if entity_page_id in my_trigger_list:
							_activate_event(entity, entity_page.list, entity_id, is_solid_contact)


func _on_tree_entered() -> void:
	var map: RPGMap = GameManager.current_map
	if map:
		current_map_tile_size = map.tile_size


func install_parts() -> void:
	if not current_data: return
	
	var config_path: String = ""
	var actor_id = get_meta("actor_id") if has_meta("actor_id") else -1
	
	if actor_id != -1:
		var actor = GameManager.get_actor(actor_id)
		if actor:
			for item in actor.current_gear:
				if item and item.type == 1:
					var db_item = RPGSYSTEM.database.weapons.get(item.id)
					if db_item:
						var lpc_path = db_item.lpc_part
						if lpc_path and FileAccess.file_exists(lpc_path):
							var lpc_res = load(lpc_path)
							if lpc_res and "config_path" in lpc_res:
								config_path = lpc_res.config_path
					break
	
	if config_path.is_empty():
		var mainhand = current_data.equipment_parts.get("mainhand")
		if mainhand and "config_path" in mainhand:
			config_path = mainhand.config_path
	
	if FileAccess.file_exists(config_path):
		var f = FileAccess.open(config_path, FileAccess.READ)
		current_weapon_data = JSON.parse_string(f.get_as_text())
		f.close()
	else:
		current_weapon_data = {}
	
	for img_id in current_weapon_images:
		current_weapon_images = {}
		
	var bake_id = "build_player" if is_in_group("player") else "build_event%s" % str(current_data) if is_in_group("event") else "build_vehicle%s" % get_instance_id()
	var node: CharacterBaker = GameManager.get_character_baker()
	
	if node:
		node.request_bake_character(
			bake_id,
			current_data,
			"",
			wings_back,
			offhand_back,
			mainhand_back,
			body,
			offhand_front,
			mainhand_front,
			actor_id
		)
		
		if current_weapon_data:
			var actions: Array = current_weapon_data.get("actions", [])
			var actions_to_bake = actions + ["idle", "walk"] 
			
			node.request_bake_weapon(
				bake_id + "_weapons",
				current_data,
				actions_to_bake,
				current_weapon_images,
				actor_id
			)


func adjust_bounds() -> void:
	%Down.position = Vector2(0, 0)
	%Up.position = Vector2(0, -49)
	%Left.position = Vector2(-15, -24)
	%Right.position = Vector2(15, -24)
	%Feet.position = Vector2(0, 0)
	var mouth = get_node_or_null("%Mouth")
	if mouth:
		match current_direction:
			DIRECTIONS.LEFT: mouth.position = Vector2(-6, -30)
			DIRECTIONS.RIGHT: mouth.position = Vector2(5, -30)
			DIRECTIONS.DOWN: mouth.position = Vector2(0, -29)
			DIRECTIONS.UP: mouth.position = Vector2(0, -35)
		if not Engine.is_editor_hint():
			get_tree().create_timer(0.05).timeout.connect(adjust_bounds)


func get_bounds() -> Dictionary:
	return {
		"left": %Left.position,
		"right": %Right.position,
		"up": %Up.position,
		"down": %Down.position
	}


func _manage_animator() -> void:
	var node = get_node_or_null("%MainAnimator")
	if node and node is AnimationPlayer and node.has_animation("Breathing"):
		if node.is_playing():
			node.stop()
		var restart_time: float = randf_range(0.1, 1.2)
		var t = create_tween()
		t.tween_interval(restart_time)
		t.tween_callback(
			func():
				node.speed_scale = randf_range(0.6, 0.7)
				node.play("Breathing")
		)


func run_animation(force_animation: bool = false) -> void:
	if not is_inside_tree(): return
	if frame_delay > 0.0 and not force_animation: return
	
	var should_show_weapon = false
	if current_data:
		should_show_weapon = current_data.always_show_weapon or is_attacking
	
	if current_animation in current_weapon_images:
		var weapon_imgs = current_weapon_images[current_animation]
		if weapon_imgs:
			mainhand_back.texture = weapon_imgs.back
			mainhand_front.texture = weapon_imgs.front
			
			offhand_back.visible = should_show_weapon
			offhand_front.visible = should_show_weapon
			mainhand_back.visible = should_show_weapon
			mainhand_front.visible = should_show_weapon
			
			if "ammo" in current_weapon_images:
				ammo_node_back.texture = current_weapon_images.ammo.back
				ammo_node_front.texture = current_weapon_images.ammo.front
				ammo_node_back.visible = should_show_weapon
				ammo_node_front.visible = should_show_weapon
			else:
				ammo_node_back.visible = false
				ammo_node_front.visible = false
		else:
			mainhand_back.visible = false
			mainhand_front.visible = false
			offhand_back.visible = false
			offhand_front.visible = false
			ammo_node_back.visible = false
			ammo_node_front.visible = false
	else:
		mainhand_back.visible = false
		mainhand_front.visible = false
		offhand_back.visible = false
		offhand_front.visible = false
		ammo_node_back.visible = false
		ammo_node_front.visible = false
	
	if current_animation in current_weapon_images and self == GameManager.current_player:
		var weapon_imgs = current_weapon_images[current_animation]
		if weapon_imgs:
			mainhand_back.texture = weapon_imgs.back
			mainhand_front.texture = weapon_imgs.front
	
	if current_animation == "idle" and "idle" in current_weapon_images:
		mainhand_back.texture = current_weapon_images.idle.back
		mainhand_front.texture = current_weapon_images.idle.front
	elif current_animation == "walk" and "walk" in current_weapon_images:
		mainhand_back.texture = current_weapon_images.walk.back
		mainhand_front.texture = current_weapon_images.walk.front
	
	var current_animation = get_current_animation()
	var current_weapon_animation = get_current_weapon_animation()

	if !current_animation and !current_weapon_animation:
		return
	
	if !current_animation:
		current_animation = current_weapon_animation
	
	if !current_weapon_animation:
		current_weapon_animation = current_animation
	
	# 1. RENDER PHASE
	var weapon_current_frame = min(current_frame, current_weapon_animation.frames.size() - 1)
	var normal_animation_current_frame = min(current_frame, current_animation.frames.size() - 1)
	
	var player_frame: Array = current_animation.frames[normal_animation_current_frame]
	var weapon_frame: Array = current_weapon_animation.frames[weapon_current_frame]
	var player_size = current_animation.frame_size
	
	body.region_rect = Rect2(player_frame[0], player_frame[1], player_size[0], player_size[1])
	wings_back.region_rect = body.region_rect
	offhand_back.region_rect = body.region_rect
	offhand_front.region_rect = body.region_rect
	ammo_node_back.region_rect = body.region_rect
	ammo_node_front.region_rect = body.region_rect
	
	var action_frame = current_animation.get("action_frame", -1)
	if current_frame == action_frame:
		_handle_action_frame(current_animation)
	
	if (
		(mainhand_back.texture and mainhand_back.texture.get_size() == body.texture.get_size()) or
		(mainhand_front.texture and mainhand_front.texture.get_size() == body.texture.get_size())
	):
		mainhand_back.region_rect = body.region_rect
	else:
		mainhand_back.region_rect = Rect2(weapon_frame[0], weapon_frame[1], 192, 192)
	mainhand_front.region_rect = mainhand_back.region_rect
	
	# 2. UPDATE LOGIC
	current_frame += 1
	
	if current_frame >= current_animation.frames.size():
		if current_animation.get("loop", false):
			current_frame = 0
		else:
			if not current_animation.get("keep_last_frame", false):
				animation_finished.emit()
				current_frame = 0
			else:
				# Clamp to the last frame index
				current_frame = current_animation.frames.size() - 1


func _get_direction_string() -> String:
	match current_direction:
		DIRECTIONS.UP: return "up"
		DIRECTIONS.DOWN: return "down"
		DIRECTIONS.LEFT: return "left"
		DIRECTIONS.RIGHT: return "right"
	return "down"


func _handle_action_frame(anim_data: Dictionary) -> void:
	var _data: RPGLPCCharacter = current_data
	if not _data:
		return
	
	if not has_meta("actor_id"): return
	
	var actor_id = get_meta("actor_id")
	var actor = GameManager.get_actor(actor_id)
	
	
	var offset_array = anim_data.get("emiter", [0, 0])
	var emission_point = Vector2(offset_array[0], offset_array[1])
	var anim_id = anim_data.get("id", "")
	
	return
	
	if "shoot" in anim_id or "cast" in anim_id:
		var ammo_id = "arrow"
		
		if "shoot" in anim_id:
			ammo_id = current_data.equipment_parts["ammo"].name.to_lower()
		elif "cast" in anim_id:
			ammo_id = "arcane1"
		
		perform_shoot(ammo_id, _get_direction_string(), emission_point)
		
	elif "slash" in anim_id or "thrust" in anim_id or "smash" in anim_id or "whip" in anim_id:
		pass


func _on_animation_finished() -> void:
	call_deferred("_animation_to_idle")
	if is_attacking:
		attack.emit(current_animation)
		is_attacking = false


func get_baking_nodes() -> Dictionary:
	return {
		"wings": wings_back,
		"offhandback": offhand_back,
		"mainhandback": mainhand_back,
		"body": body,
		"offhandfront": offhand_front,
		"mainhandfront": mainhand_front
	}


func update_player_appearance(char_data: RPGLPCCharacter) -> void:
	if not char_data or not GameManager.main_scene:
		return
		
	var baker = GameManager.get_character_baker()
	if baker:
		baker.request_bake_character(
			str(get_instance_id()),
			char_data,
			"walk",
			wings_back,
			offhand_back,
			mainhand_back,
			body,
			offhand_front,
			mainhand_front,
			get_meta("actor_id") if has_meta("actor_id") else -1
		)


func get_current_animation() -> Dictionary:
	if !animations:
		return {}
		
	var animation_id = current_animation.to_lower() + "_" + str(DIRECTIONS.find_key(current_direction)).to_lower()

	var current_animation = {}
	for animation in animations.player:
		if animation.id == animation_id:
			current_animation = animation
			break
		
	return current_animation


func get_current_weapon_animation() -> Dictionary:
	if !animations:
		return {}
		
	var animation_id = current_animation.to_lower() + "_" + str(DIRECTIONS.find_key(current_direction)).to_lower()
	if ["dagger2"].has(current_weapon_data.get("id", "")) and ["idle", "walk"].has(current_animation.to_lower()):
		animation_id = "small_" + animation_id

	var current_animation = {}

	for animation in animations.weapon:
		if animation.id == animation_id:
			current_animation = animation
			break

	return current_animation


func perform_shoot(ammo_id: String, direction: String, ammo_position: Vector2) -> void:
	print(["shoot ", ammo_id, direction, ammo_position])
	return
	var p = PROJECTILES.get(ammo_id, "")
	if p:
		var blend_color = current_data.equipment_parts.ammo.palette1.blend_color
		var obj = p.instantiate()
		
		# Assuming ammo still needs visual properties from loaded data, 
		# but since we removed get_textures_with_id, we need a safer way to get material if needed.
		# For now, instantiating the projectile directly.
		
		if direction == "up":
			obj.show_behind_parent = true
		obj.set_blend_color(blend_color)
		add_child(obj)
		obj.position = ammo_position
		if ammo_id == "bolt":
			var x = 0
			var y = 0
			if direction == "down":
				x += -6
			elif direction == "left" or direction == "right":
				y += 10
			elif direction == "up":
				x += 6
			obj.position += Vector2(x, y)
		obj.set_direction(direction)
		var audio_path = "res://addons/rpg_character_creator/sounds/swosh-01.ogg" if ammo_id == "arrow" else \
		"res://addons/rpg_character_creator/sounds/swosh-03.ogg" if ammo_id == "bolt" else \
		"res://addons/rpg_character_creator/sounds/swosh-05.ogg" if ammo_id == "rock" else \
		"res://addons/rpg_character_creator/sounds/spell1.ogg" if ammo_id == "arcane1" else \
		""
		if audio_path:
			var fx = ResourceLoader.load(audio_path)
			var audio_stream_player = AudioStreamPlayer.new()
			audio_stream_player.stream = fx
			audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
			add_child(audio_stream_player)
			audio_stream_player.play()


func _on_attack(animation_id: String) -> void:
	pass


func attack_with_weapon() -> void:
	var actions = current_weapon_data.get("actions", [])
	current_animation = actions[randi() % actions.size()]
	if !current_animation:
		attack_without_weapon()
		return

	if current_animation in current_weapon_images:
		mainhand_back.texture = current_weapon_images[current_animation].back
		mainhand_front.texture = current_weapon_images[current_animation].front
		
	if current_animation == "fish_throw":
		current_animation = "fish_full_animation"
	elif current_animation == "shoot":
		var fx = ResourceLoader.load("res://addons/rpg_character_creator/sounds/bow_draw.ogg")
		var audio_stream_player = AudioStreamPlayer.new()
		audio_stream_player.stream = fx
		audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
		add_child(audio_stream_player)
		audio_stream_player.play()

	if current_weapon_data.get("sounds", null):
		var sound_path = current_weapon_data.sounds[randi() % current_weapon_data.sounds.size()]
		sound_path = "res://addons/rpg_character_creator/" + sound_path
		if ResourceLoader.exists(sound_path):
			var fx = ResourceLoader.load(sound_path)
			var audio_stream_player = AudioStreamPlayer.new()
			audio_stream_player.stream = fx
			audio_stream_player.finished.connect(func(): audio_stream_player.queue_free())
			add_child(audio_stream_player)
			audio_stream_player.play()
			
	current_frame = 0
	is_attacking = true
	if current_animation != "fish_full_animation":
		attack.emit(current_animation)
	else:
		attack.emit("fish")


func attack_without_weapon() -> void:
	var actions = ["slash", "islash", "smash"]
	current_animation = actions[randi() % actions.size()]
	current_frame = 0
	is_attacking = true


func can_perform_action() -> bool:
	if Engine.is_editor_hint() or is_on_vehicle: return false
	
	var main_interpreter = GameManager.get_main_interpreter()
	
	if not main_interpreter: return false

	return !busy and !is_attacking and !is_moving and can_attack and can_move and !GameManager.busy and !main_interpreter.is_busy() and !GameInterpreter.is_busy() and !force_locked


func get_shadow_data() -> Dictionary:
	if is_on_vehicle or is_queued_for_deletion() or has_meta("_disable_shadow"):
		return {}
	var sprites = []
	for s in [wings_back, offhand_back, mainhand_back, body, offhand_front, mainhand_front]:
		if s.visible and s.modulate.a > 0.0 and s.self_modulate.a > 0.0: sprites.append(s)
	var shadow = {
		"main_node": full_body,
		"sprites": sprites,
		"position": full_body.global_position,
		"feet_offset": 16
	}
	if GameManager.current_map:
		shadow.cell = Vector2i(global_position / Vector2(GameManager.current_map.tile_size))
	
	return shadow


func shake(shake_offset: Vector2) -> void:
	var node = full_body
	if not node.has_meta("original_position"):
		node.set_meta("original_position", node.position)
	
	node.position = node.get_meta("original_position") + shake_offset
