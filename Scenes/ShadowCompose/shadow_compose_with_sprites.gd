@tool
extends Node2D


@export var shadow_component: ShadowComponent :
	set(value):
		if shadow_component and shadow_component.shadow_updated.is_connected(update):
			shadow_component.shadow_updated.disconnect(update)
		shadow_component = value
		if shadow_component:
			if Engine.is_editor_hint():
				if not shadow_component.shadow_updated.is_connected(update):
					shadow_component.shadow_updated.connect(update)
				if is_node_ready():
					shadow_component.shadow_updated.emit()
			elif is_node_ready():
				update()


var shadow_data: Array :
	set(value):
		value.sort_custom(
			func(a: Dictionary, b: Dictionary):
				return a.position.y < b.position.y
		)
		shadow_data = value
		if is_node_ready():
			need_refresh = true


var need_refresh: bool = false

var current_sprites_to_draw = []
var current_sprite_index = 0
var current_pool = {}

const MAX_POOL = 150


func update():
	if shadow_component:
		self_modulate = shadow_component.shadow_color
	need_refresh = true


func set_current_map_rect(_rect: Rect2) -> void:
	pass


func _process(delta: float) -> void:
	if need_refresh:
		refresh_all()
		need_refresh = false
	
	if current_sprites_to_draw.size() > 0:
		create_shadow_sprites(15)


func create_shadow_sprites(amount: int) -> void:
	for i in amount:
		if current_sprites_to_draw.size() > 0:
			var data: Dictionary = current_sprites_to_draw.pop_back()
			var sprite = Sprite2D.new()
			if data.has("texture_viewport"):
				sprite.centered = true
				sprite.texture = data.texture_viewport
				sprite.offset = Vector2.ZERO
				sprite.modulate = Color.BLACK
				sprite.y_sort_enabled = true
				add_child(sprite)
				update_shadow(sprite, data)
				var rid = data.texture_viewport.get_rid()
				current_pool[rid] = sprite
			elif data.has("texture"):
				sprite.centered = false
				sprite.texture = data.texture
				sprite.modulate = Color.BLACK
				sprite.y_sort_enabled = true
				sprite.offset = Vector2(sprite.texture.get_width() / 2, sprite.texture.get_height())
				add_child(sprite)
				update_shadow(sprite, data)
				var rid = data.texture.get_rid()
				current_pool[rid] = sprite
		else:
			break


func refresh_all() -> void:
	if not shadow_component: return
	
	for data: Dictionary in shadow_data:
		if data.has("texture_viewport"):
			var rid = data.texture_viewport.get_rid()
			if rid in current_pool:
				update_shadow(current_pool[rid], data)
			else:
				current_sprites_to_draw.append(data)
		elif data.has("texture"):
			var rid = data.texture.get_rid()
			if rid in current_pool:
				update_shadow(current_pool[rid], data)
			else:
				current_sprites_to_draw.append(data)


func update_shadow(sprite: Sprite2D, data: Dictionary) -> void:
	var sk = shadow_component.dynamic_skew * -1
	var el = shadow_component.elongation * -1
	var max_skew = 1.2
	if abs(sk) > max_skew:
		var scy = abs(sk) - max_skew
		sk = max_skew * sign(sk)
		el.y += abs(scy) * sign(el.y)
	var default_scale = data.get("scale", Vector2.ONE)
	sprite.skew = sk
	sprite.scale.x = -el.x * default_scale.x
	sprite.scale.y = -el.y * default_scale.y
	sprite.position = data.position
