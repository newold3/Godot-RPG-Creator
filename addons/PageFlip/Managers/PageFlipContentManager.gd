class_name PageFlipContentManager extends RefCounted

## Reference to the main book node.
var book: Node2D

## Internal cache for interactive scenes.
var _scene_cache: Dictionary = {}


## Initializes the content manager.
func _init(book_node: Node2D) -> void:
	book = book_node


#region Content Management
## Fills the internal arrays based on the requested images or scenes.
func prepare_book_content() -> void:
	book._runtime_pages = book.pages_paths.duplicate()
	
	if book._runtime_pages.size() > 0 and book._runtime_pages.size() % 2 != 0:
		book._runtime_pages.append("internal://blank_page")
		
	var num = book._runtime_pages.size()
	
	if num == 0:
		book.total_spreads = 1
	else:
		book.total_spreads = (num / 2) + 1


## Fills a viewport dynamically rendering content required right in the current spread.
func update_slot_content(slot: SubViewport, content_index: int, is_left: bool) -> void:
	if not slot:
		return
		
	for child in slot.get_children():
		if child is TextureRect:
			child.queue_free()
		else:
			slot.remove_child(child)
			
	var resource_path = ""
	var cover_tex: Texture2D = null
	var is_cover = false
	
	if content_index == -100:
		cover_tex = book.tex_cover_front_out
		is_cover = true
	elif content_index == -101:
		cover_tex = book.tex_cover_front_in
		is_cover = true
	elif content_index == -102:
		cover_tex = book.tex_cover_back_in
		is_cover = true
	elif content_index == -103:
		cover_tex = book.tex_cover_back_out
		is_cover = true
	elif content_index >= 0 and content_index < book._runtime_pages.size():
		resource_path = book._runtime_pages[content_index]
		
	var default_blank = book.left_blank_page_texture if is_left else book.right_blank_page_texture
	
	if is_cover and cover_tex:
		if cover_tex != default_blank:
			setup_texture_in_slot(slot, cover_tex, is_left, is_cover)
		else:
			setup_texture_in_slot(slot, default_blank, is_left, is_cover)
	elif resource_path != "":
		if resource_path == "internal://blank_page":
			setup_texture_in_slot(slot, default_blank, is_left, is_cover)
		elif ResourceLoader.exists(resource_path):
			var res = load(resource_path)
			
			if res is PackedScene:
				setup_scene_in_slot(slot, res, content_index, is_left, is_cover)
			elif res is Texture2D:
				if res != default_blank:
					setup_texture_in_slot(slot, res, is_left, is_cover)
				else:
					setup_texture_in_slot(slot, default_blank, is_left, is_cover)
			else:
				setup_texture_in_slot(slot, default_blank, is_left, is_cover)
	else:
		setup_texture_in_slot(slot, default_blank, is_left, is_cover)
		
	prune_scene_cache.call_deferred()


## Sets textures up inside an isolated slot structure securely.
func setup_texture_in_slot(slot: SubViewport, tex: Texture2D, is_left_page: bool, is_cover: bool) -> void:
	var has_margin = (not is_cover and book.inner_page_margin != Vector2.ZERO)
	
	if has_margin:
		add_composite_blank_bg(slot, is_left_page, true)
	elif book.enable_composite_pages:
		add_composite_blank_bg(slot, is_left_page, false)
		
	if not tex:
		tex = book.left_blank_page_texture if is_left_page else book.right_blank_page_texture
		if not tex:
			return
			
	var expected_bg = book.left_blank_page_texture if is_left_page else book.right_blank_page_texture
	
	if (has_margin or book.enable_composite_pages) and tex == expected_bg:
		return
		
	var rect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = book.page_stretch_mode as TextureRect.StretchMode
	
	if has_margin:
		rect.size.y = slot.size.y - (book.inner_page_margin.y * 2.0)
		rect.size.x = slot.size.x - book.inner_page_margin.x
		rect.position.y = book.inner_page_margin.y
		rect.position.x = book.inner_page_margin.x if is_left_page else 0.0
	else:
		rect.size = slot.size
		rect.position = Vector2.ZERO
		
	slot.add_child(rect)


## Busca una clave en la caché que pertenezca a la misma escena pero no esté activa en pantalla.
func _find_inactive_scene_of_type(scene_path: String) -> String:
	var active_keys = []
	for slot in [book._slot_1, book._slot_2, book._slot_3, book._slot_4]:
		if slot and slot.get_child_count() > 0:
			var node = slot.get_child(-1)
			if node.has_meta("cache_key"):
				active_keys.append(node.get_meta("cache_key"))
				
	var prefix = scene_path + "#"
	for key in _scene_cache.keys():
		if key.begins_with(prefix) and not key in active_keys:
			if is_instance_valid(_scene_cache[key]):
				return key
				
	return ""


## Instantiates packed scenes inside subviewports.
func setup_scene_in_slot(slot: SubViewport, scene_pkg: PackedScene, texture_index: int, is_left_page: bool, is_cover: bool) -> void:
	var has_margin = (not is_cover and book.inner_page_margin != Vector2.ZERO)
	
	if has_margin:
		add_composite_blank_bg(slot, is_left_page, true)
	elif book.enable_composite_pages:
		add_composite_blank_bg(slot, is_left_page, false)
		
	var cache_key = scene_pkg.get_path() + "#" + str(texture_index)
	var instance
	
	if not cache_key in _scene_cache:
		var recycled_key = _find_inactive_scene_of_type(scene_pkg.get_path())
		var can_recycle = false
		
		if recycled_key != "":
			var temp_instance = _scene_cache[recycled_key]
			if is_instance_valid(temp_instance) and temp_instance.has_method("update_page"):
				can_recycle = true
				
		if can_recycle:
			var recycled_key_str: String = recycled_key
			instance = _scene_cache[recycled_key_str]
			_scene_cache.erase(recycled_key_str)
			
			instance.set_meta("page_index", texture_index)
			instance.set_meta("is_left", is_left_page)
			instance.set_meta("cache_key", cache_key)
			
			_scene_cache[cache_key] = instance
			
			if instance.is_inside_tree():
				instance.reparent(slot)
			else:
				slot.add_child(instance)
				
			instance.update_page(texture_index)
		else:
			instance = scene_pkg.instantiate()
			instance.set_meta("_pageflip_node", book)
			instance.set_meta("page_index", texture_index)
			instance.set_meta("is_left", is_left_page)
			instance.set_meta("cache_key", cache_key)
			
			if instance.has_signal("manage_pageflip"):
				instance.connect("manage_pageflip", book._pageflip_set_input_enabled)
				
			slot.add_child(instance)
			_scene_cache[cache_key] = instance
	else:
		instance = _scene_cache[cache_key]
		_scene_cache.erase(cache_key)
		_scene_cache[cache_key] = instance
		
		if instance.is_inside_tree():
			instance.reparent(slot)
		else:
			slot.add_child(instance)
			
	if instance is Control:
		instance.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		
	if has_margin:
		instance.position.y = book.inner_page_margin.y
		instance.position.x = book.inner_page_margin.x if is_left_page else 0.0
		
		if instance is Control:
			instance.size.y = slot.size.y - (book.inner_page_margin.y * 2.0)
			instance.size.x = slot.size.x - book.inner_page_margin.x
	else:
		instance.position = Vector2.ZERO
		
		if instance is Control:
			instance.size = slot.size
			
	instance.set_process_input(false)
	instance.set_process_unhandled_input(false)


## Embeds the configured base empty texture under transparent instances safely.
func add_composite_blank_bg(slot: SubViewport, is_left_page: bool, apply_margin: bool = false) -> void:
	var tex = book.left_blank_page_texture if is_left_page else book.right_blank_page_texture
	
	if not tex:
		return
		
	var bg = TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = book.page_stretch_mode as TextureRect.StretchMode
	
	if apply_margin:
		bg.size.y = slot.size.y - (book.inner_page_margin.y * 2.0)
		bg.size.x = slot.size.x - book.inner_page_margin.x
		bg.position.y = book.inner_page_margin.y
		bg.position.x = book.inner_page_margin.x if is_left_page else 0.0
	else:
		bg.size = slot.size
		bg.position = Vector2.ZERO
		
	slot.add_child(bg)


## Removes older instantiated scenes from memory to prevent memory leaks.
func prune_scene_cache() -> void:
	if _scene_cache.size() <= book.max_cached_scenes:
		return
		
	var active_keys = []
	
	for slot in [book._slot_1, book._slot_2, book._slot_3, book._slot_4]:
		if slot and slot.get_child_count() > 0:
			var node = slot.get_child(-1)
			
			if node.has_meta("cache_key"):
				active_keys.append(node.get_meta("cache_key"))
				
	var keys_to_remove = []
	
	for key in _scene_cache.keys():
		if not key in active_keys:
			keys_to_remove.append(key)
			
	while _scene_cache.size() > book.max_cached_scenes and keys_to_remove.size() > 0:
		var key_to_kill = keys_to_remove.pop_front()
		var instance = _scene_cache[key_to_kill]
		
		if is_instance_valid(instance):
			instance.queue_free()
			
		_scene_cache.erase(key_to_kill)
#endregion
