@tool
class_name GuiCoreSaveSlotPanel
extends NinePatchRect

#region Variables
@export var slot_container: Node
@export var slot_offset: Vector2 = Vector2(25, 7)
@export var slot_id: int = 0

var is_disabled: bool = false
var scroll_container: Node
#endregion

#region Signals
signal slot_selected(slot_id: int)
signal slot_clicked(slot_id: int)
#endregion

#region VirtualGetters
func get_contents_container() -> Control:
	if has_node("%ContentsContainer"): return get_node("%ContentsContainer")
	return null


func get_no_data_container() -> Control:
	if has_node("%NoDataContainer"): return get_node("%NoDataContainer")
	return null


func get_map() -> TextureRect:
	if has_node("%Map"): return get_node("%Map")
	return null


func get_chapter_name() -> Control:
	if has_node("%ChapterName"): return get_node("%ChapterName")
	return null


func get_timer() -> Control:
	if has_node("%Timer"): return get_node("%Timer")
	return null


func get_gold() -> Control:
	if has_node("%Gold"): return get_node("%Gold")
	return null


func get_hero_container() -> Control:
	if has_node("%HeroContainer"): return get_node("%HeroContainer")
	return null


func get_slot_position() -> Control:
	if has_node("%SlotPosition"): return get_node("%SlotPosition")
	return null


func get_slot() -> Control:
	if has_node("%Slot"): return get_node("%Slot")
	return null


func get_slot_name() -> Control:
	if has_node("%SlotName"): return get_node("%SlotName")
	return null


func get_cursor() -> Control:
	if has_node("%Cursor"): return get_node("%Cursor")
	return null


func get_gear() -> Control:
	if has_node("%Gear"): return get_node("%Gear")
	return null
#endregion

#region VirtualHooks
func _on_rebuild_cursor_tween() -> void:
	pass


func _on_focus_entered_visual() -> void:
	pass


func _on_focus_exited_visual() -> void:
	pass


func _animate_highlight(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _animate_start(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _animate_end(on_complete: Callable = Callable()) -> void:
	if on_complete:
		on_complete.call()


func _set_disabled_visual(_disabled: bool) -> void:
	pass
#endregion

#region Lifecycle & Setup
func _ready() -> void:
	_set_slot_name()
	_move_slot()
	_try_load_save_data()
	_on_rebuild_cursor_tween()
	_setup_focus_and_mouse()


func _process(_delta: float) -> void:
	var sl = get_slot()
	var sp = get_slot_position()
	if slot_container and is_instance_valid(sl) and is_instance_valid(sp):
		sl.global_position = sp.global_position - sl.size * 0.5
		sl.position += slot_offset


func initialize_slot(index: int) -> void:
	slot_id = index


func _set_slot_name() -> void:
	var name_lbl = get_slot_name()
	if not name_lbl: return
	if slot_id == 0:
		if "label_text" in name_lbl:
			name_lbl.label_text = "AUTO SAVE"
		elif name_lbl.has_method("set_text"):
			name_lbl.text = "AUTO SAVE"
	else:
		var text = tr("Slot %s" % slot_id)
		if "label_text" in name_lbl:
			name_lbl.label_text = text
		elif name_lbl.has_method("set_text"):
			name_lbl.text = text


func _move_slot() -> void:
	var sl = get_slot()
	var sp = get_slot_position()
	if slot_container and is_instance_valid(sl) and is_instance_valid(sp):
		sl.name = "SlotName%s" % slot_id
		sl.reparent(slot_container)
		sl.global_position = sp.global_position - sl.size * 0.5
		sl.position += slot_offset
		tree_exiting.connect(sl.queue_free)
		set_process(true)
	else:
		set_process(false)


func _setup_focus_and_mouse() -> void:
	mouse_entered.connect(func(): select())
	focus_entered.connect(
		func():
			_on_focus_entered_visual()
	)
	focus_exited.connect(
		func():
			_on_focus_exited_visual()
	)
#endregion

#region Data Loading & UI Population
func refresh() -> void:
	_try_load_save_data()


func _try_load_save_data() -> void:
	if Engine.is_editor_hint():
		set_disabled()
		return
		
	var preview_data = SaveLoadManager.get_slot_preview_data(slot_id)
	if not preview_data:
		set_disabled()
		return

	var image_path = SaveLoadManager.get_slot_image_path(slot_id)
	_populate_ui(preview_data, image_path)
	set_enabled()


func _populate_ui(data: RPGSavedGamePreview, image_path: String) -> void:
	var ch = get_chapter_name()
	if ch:
		if ch.has_method("set_text"):
			ch.text = data.current_chapter_name
		elif "label_text" in ch:
			ch.label_text = data.current_chapter_name

	var g = get_gold()
	if g:
		if g.has_method("set_text"):
			g.text = str(data.current_gold)
		elif "label_text" in g:
			g.label_text = str(data.current_gold)
	
	var tm = get_timer()
	var time_str = GameManager.format_game_time(data.play_time)
	if tm:
		if tm.has_method("set_text"):
			tm.text = time_str
		elif "label_text" in tm:
			tm.label_text = time_str
		
	var m = get_map()
	if m:
		if FileAccess.file_exists(image_path):
			var img = Image.load_from_file(image_path)
			if img:
				m.texture = ImageTexture.create_from_image(img)
		else:
			m.texture = null
	
	var heroes = get_hero_container()
	if heroes:
		_update_party_icons(data.current_party_ids)


func _update_party_icons(party_ids: Array) -> void:
	var heroes = get_hero_container()
	if not heroes: return
	for child in heroes.get_children():
		child.queue_free()
		heroes.remove_child(child)
		
	for id in party_ids:
		var uid = id
		if uid > 0 and uid < 1000000:
			uid = RPGSYSTEM.id_to_uid("actors", uid)
			
		if uid > 0:
			var actor: RPGActor = RPGSYSTEM.get_data("actors", uid)
			if actor:
				var scene = actor.character_scene
				var image_path = scene.trim_suffix(".tscn") + "_character.png"
				
				if AssetManager.exists(image_path):
					var tex = load(image_path)
					var node = TextureRect.new()
					node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					node.custom_minimum_size.x = 36
					node.texture = tex
					heroes.add_child(node)
#endregion

#region State & Actions
func highlight() -> void:
	_animate_highlight()


func start() -> void:
	disable_input()
	_animate_start(func():
		enable_input()
		if get_index() == GameManager.current_save_slot:
			_initial_selection()
	)


func _initial_selection() -> void:
	enable_input()
	if scroll_container and scroll_container.has_method("bring_target_into_view"):
		scroll_container.bring_target_into_view(self, true, false)
		
	select()
	GameManager.force_hand_position_over_node.call_deferred(GameManager.get_cursor_manipulator())
	GameManager.set_fx_busy(false)


func end() -> void:
	disable_input()
	GameManager.set_fx_busy(true)
	await get_tree().process_frame
	_animate_end(Callable())


func select() -> void:
	if not is_disabled and is_visible_in_tree():
		grab_focus()


func set_disabled() -> void:
	is_disabled = true
	var contents = get_contents_container()
	var no_data = get_no_data_container()
	if contents: contents.visible = false
	if no_data: no_data.visible = true
	_set_disabled_visual(true)


func set_enabled() -> void:
	is_disabled = false
	var contents = get_contents_container()
	var no_data = get_no_data_container()
	if contents: contents.visible = true
	if no_data: no_data.visible = false
	_set_disabled_visual(false)


func disable_input() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func enable_input() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
#endregion
