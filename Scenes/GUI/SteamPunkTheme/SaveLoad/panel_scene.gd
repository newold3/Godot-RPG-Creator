@tool
extends NinePatchRect

@export var slot_container: Node
@export var slot_offset: Vector2 = Vector2(25, 7)
@export var slot_id: int = 0


@onready var cursor: NinePatchRect = %Cursor
@onready var slot_position: Control = %SlotPosition
@onready var slot: NinePatchRect = %Slot
@onready var slot_name: Control = %SlotName
@onready var map: TextureRect = %Map
@onready var chapter_name: Control = %ChapterName
@onready var timer: Control = %Timer
@onready var gold: Control = %Gold
@onready var hero_container: HBoxContainer = %HeroContainer
@onready var contents_container: MarginContainer = %ContentsContainer
@onready var gear: TextureRect = %Gear


var is_disabled: bool = false
var main_tween: Tween
var gear_tween: Tween
var scroll_container: Node


func _ready() -> void:
	_set_slot_name()
	_move_slot()
	_try_load_save_data()
	_rebuild_cursor_tween()
	_set_cursor_visibility()


func disable_input() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func enable_input() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func initialize_slot(index: int) -> void:
	slot_id = index


func _set_slot_name() -> void:
	if slot_id == 0:
		if "label_text" in slot_name:
			slot_name.label_text = "AUTO SAVE"
		elif slot_name.has_method("set_text"):
			slot_name.text = "AUTO SAVE" 
	else:
		var text = tr("Slot %s" % slot_id)
		if "label_text" in slot_name:
			slot_name.label_text = text
		elif slot_name.has_method("set_text"):
			slot_name.text = text


func _move_slot() -> void:
	if slot_container:
		slot.name = "SlotName%s" % slot_id
		slot.reparent(slot_container)
		slot.global_position = slot_position.global_position - slot.size * 0.5
		slot.position += slot_offset
		tree_exiting.connect(slot.queue_free)
		set_process(true)
	else:
		set_process(false)


func _animate_gear(value: float):
	if gear_tween:
		gear_tween.kill()
	gear_tween = create_tween()
	gear_tween.set_speed_scale(0.25)
	if value > 0:
		gear_tween.set_loops()
		gear_tween.tween_property(gear, "rotation", value, 2.0).from(0.0)
	else:
		gear_tween.tween_property(gear, "rotation", gear.rotation + value, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	


func _set_cursor_visibility() -> void:
	cursor.visible = false
	mouse_entered.connect(
		func():
			select()
	)
	focus_entered.connect(
		func():
			_animate_gear(TAU)
			cursor.visible = true
	)
	focus_exited.connect(
		func():
			_animate_gear(-0.65)
			cursor.visible = false
	)


func _rebuild_cursor_tween() -> void:
	if main_tween:
		main_tween.kill()
		
	main_tween = create_tween()
	main_tween.set_loops()
	main_tween.tween_interval(0.5)
	main_tween.tween_property(cursor, "modulate:a", 0.8, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	main_tween.tween_property(cursor, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)


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
	if chapter_name.has_method("set_text"):
		chapter_name.text = data.current_chapter_name
	elif "label_text" in chapter_name:
		chapter_name.label_text = data.current_chapter_name

	if gold.has_method("set_text"):
		gold.text = str(data.current_gold)
	elif "label_text" in gold:
		gold.label_text = str(data.current_gold)
	
	var time_str = GameManager.format_game_time(data.play_time)
	if timer.has_method("set_text"):
		timer.text = time_str
	elif "label_text" in timer:
		timer.label_text = time_str
		
	if FileAccess.file_exists(image_path):
		var img = Image.load_from_file(image_path)
		if img:
			map.texture = ImageTexture.create_from_image(img)
	else:
		map.texture = null
	
	_update_party_icons(data.current_party_ids)


func _update_party_icons(party_ids: Array) -> void:
	for child in hero_container.get_children():
		child.queue_free()
		hero_container.remove_child(child)
		
	for id in party_ids:
		if id > 0 and RPGSYSTEM.database.actors.size() > id:
			var actor: RPGActor = RPGSYSTEM.database.actors[id]
			var scene = actor.character_scene
			var image_path = scene.trim_suffix(".tscn") + "_character.png"
			if ResourceLoader.exists(image_path):
				var tex = load(image_path)
				var node = TextureRect.new()
				node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				node.custom_minimum_size.x = 36
				node.texture = tex
				hero_container.add_child(node)



func _process(_delta: float) -> void:
	if slot_container and is_instance_valid(slot):
		slot.global_position = slot_position.global_position - slot.size * 0.5
		slot.position += slot_offset


func set_disabled() -> void:
	%ContentsContainer.visible = false
	%NoDataContainer.visible = true
	is_disabled = true


func set_enabled() -> void:
	%ContentsContainer.visible = true
	%NoDataContainer.visible = false
	is_disabled = false


func highlight() -> void:
	var t = create_tween()
	t.set_parallel(true) # Todo corre simultáneamente
	
	t.tween_property(self, "modulate", Color(2.35, 2.35, 2.35, 1), 0.1)
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3).set_delay(0.1)
	
	var strength: float = 6.0
	var duration: float = 0.05
	if not has_meta("original_x"):
		set_meta("oroginal_x", position.x)
		
	t.tween_property(self, "position:x", strength, duration).as_relative()
	t.tween_property(self, "position:x", -strength * 2, duration).set_delay(duration).as_relative()
	t.tween_property(self, "position:x", strength, duration).set_delay(duration * 2).as_relative()
	t.tween_property(self, "position:x", get_meta("oroginal_x"), duration).set_delay(duration * 2 + 0.01)


func start() -> void:
	disable_input()
	contents_container.pivot_offset = Vector2(0, size.y * 0.5)
	gear.pivot_offset = gear.size * 0.5
	var t = create_tween()
	t.set_parallel(true)
	if get_index() % 2 == 0:
		t.tween_property(self, "position:x", 0.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).from(-size.x)
	else:
		t.tween_property(self, "position:x", 0.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).from(size.x)
	t.tween_property(gear, "rotation", gear.rotation - PI, 0.85).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)

	var target_index = GameManager.current_save_slot
	t.tween_callback(enable_input).set_delay(0.35)
	if get_index() == target_index:
		t.tween_callback(_initial_selection).set_delay(0.35)
		if scroll_container:
			scroll_container.bring_target_into_view.call_deferred(self, true, false)
			GameManager.force_hand_position_over_node.call_deferred(GameManager.get_cursor_manipulator())
	elif not SaveLoadManager.has_any_save_file() and (slot_id == RPGSavedGameData.AUTO_SAVE_SLOT_ID or slot_id == RPGSavedGameData.AUTO_SAVE_SLOT_ID + 1):
		t.tween_callback(_initial_selection).set_delay(0.35)
		if scroll_container:
			scroll_container.bring_target_into_view.call_deferred(self, true, false)
			GameManager.force_hand_position_over_node.call_deferred(GameManager.get_cursor_manipulator())
	else:
		t.tween_callback(enable_input).set_delay(0.35)


func _initial_selection():
	enable_input()
	if scroll_container and scroll_container is SmoothScrollContainer:
		scroll_container.bring_target_into_view(self, true, false)
	select()
	GameManager.force_hand_position_over_node.call_deferred(GameManager.get_cursor_manipulator())
	GameManager.set_fx_busy(false)


func end() -> void:
	disable_input()
	GameManager.set_fx_busy(true)
	await get_tree().process_frame
	var t = create_tween()
	t.set_parallel(true)
	if get_index() % 2 == 1:
		t.tween_property(self, "position:x", -size.x, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	else:
		t.tween_property(self, "position:x", size.x, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	t.tween_property(gear, "rotation", gear.rotation - PI, 0.85).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)


func select() -> void:
	grab_focus()
