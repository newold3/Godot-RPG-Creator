@tool
extends GuiCoreSaveSlotPanel

#region NodeReferences
@onready var cursor: Control = %Cursor if has_node("%Cursor") else null
@onready var slot_position: Control = %SlotPosition if has_node("%SlotPosition") else null
@onready var slot: Control = %Slot if has_node("%Slot") else null
@onready var slot_name: Control = %SlotName if has_node("%SlotName") else null
@onready var map: TextureRect = %Map if has_node("%Map") else null
@onready var chapter_name: Control = %ChapterName if has_node("%ChapterName") else null
@onready var timer: Control = %Timer if has_node("%Timer") else null
@onready var gold: Control = %Gold if has_node("%Gold") else null
@onready var hero_container: HBoxContainer = %HeroContainer if has_node("%HeroContainer") else null
@onready var contents_container: MarginContainer = %ContentsContainer if has_node("%ContentsContainer") else null
@onready var gear: Control = %Gear if has_node("%Gear") else null
@onready var no_data_container: MarginContainer = %NoDataContainer if has_node("%NoDataContainer") else null

var main_tween: Tween
var gear_tween: Tween
#endregion

#region GetterOverrides
func get_contents_container() -> Control:
	if not contents_container and has_node("%ContentsContainer"):
		contents_container = %ContentsContainer
	return contents_container


func get_no_data_container() -> Control:
	if not no_data_container and has_node("%NoDataContainer"):
		no_data_container = %NoDataContainer
	return no_data_container


func get_map() -> TextureRect:
	if not map and has_node("%Map"):
		map = %Map
	return map


func get_chapter_name() -> Control:
	if not chapter_name and has_node("%ChapterName"):
		chapter_name = %ChapterName
	return chapter_name


func get_timer() -> Control:
	if not timer and has_node("%Timer"):
		timer = %Timer
	return timer


func get_gold() -> Control:
	if not gold and has_node("%Gold"):
		gold = %Gold
	return gold


func get_hero_container() -> Control:
	if not hero_container and has_node("%HeroContainer"):
		hero_container = %HeroContainer
	return hero_container


func get_slot_position() -> Control:
	if not slot_position and has_node("%SlotPosition"):
		slot_position = %SlotPosition
	return slot_position


func get_slot() -> Control:
	if not slot and has_node("%Slot"):
		slot = %Slot
	return slot


func get_slot_name() -> Control:
	if not slot_name and has_node("%SlotName"):
		slot_name = %SlotName
	return slot_name


func get_cursor() -> Control:
	if not cursor and has_node("%Cursor"):
		cursor = %Cursor
	return cursor


func get_gear() -> Control:
	if not gear and has_node("%Gear"):
		gear = %Gear
	return gear
#endregion

#region VisualOverrides
func _animate_gear(value: float) -> void:
	var g = get_gear()
	if not g: return
	if gear_tween:
		gear_tween.kill()
		
	gear_tween = create_tween()
	gear_tween.set_speed_scale(0.25)
	
	if value > 0:
		gear_tween.set_loops()
		gear_tween.tween_property(g, "rotation", value, 2.0).from(0.0)
	else:
		gear_tween.tween_property(g, "rotation", g.rotation + value, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _on_rebuild_cursor_tween() -> void:
	var cur = get_cursor()
	if not cur: return
	if main_tween:
		main_tween.kill()
		
	main_tween = create_tween()
	main_tween.set_loops()
	main_tween.tween_interval(0.5)
	main_tween.tween_property(cur, "modulate:a", 0.8, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	main_tween.tween_property(cur, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)


func _on_focus_entered_visual() -> void:
	_animate_gear(TAU)
	var cur = get_cursor()
	if cur:
		cur.visible = true


func _on_focus_exited_visual() -> void:
	_animate_gear(-0.65)
	var cur = get_cursor()
	if cur:
		cur.visible = false


func _animate_highlight(on_complete: Callable = Callable()) -> void:
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate", Color(2.35, 2.35, 2.35, 1), 0.1)
	t.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3).set_delay(0.1)
	
	var strength: float = 6.0
	var duration: float = 0.05
	if not has_meta("original_x"):
		set_meta("original_x", position.x)
		
	t.tween_property(self, "position:x", strength, duration).as_relative()
	t.tween_property(self, "position:x", -strength * 2, duration).set_delay(duration).as_relative()
	t.tween_property(self, "position:x", strength, duration).set_delay(duration * 2).as_relative()
	t.tween_property(self, "position:x", get_meta("original_x"), duration).set_delay(duration * 2 + 0.01)
	if on_complete:
		t.set_parallel(false)
		t.tween_callback(on_complete).set_delay(0.3)


func _animate_start(on_complete: Callable = Callable()) -> void:
	var contents = get_contents_container()
	if contents:
		contents.pivot_offset = Vector2(0, size.y * 0.5)
	var g = get_gear()
	if g:
		g.pivot_offset = g.size * 0.5
	
	var t = create_tween()
	t.set_parallel(true)
	
	var stagger_delay: float = min(get_index(), 6) * 0.035
	var slide_offset: float = 80.0
	var from_x: float = -slide_offset if (get_index() % 2 == 0) else slide_offset
	
	modulate.a = 0.0
	t.tween_property(self, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(stagger_delay)
	t.tween_property(self, "position:x", 0.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).from(from_x).set_delay(stagger_delay)
		
	if g:
		t.tween_property(g, "rotation", g.rotation - PI, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(stagger_delay)

	var target_index = GameManager.current_save_slot
	var finish_delay = stagger_delay + 0.35
	if on_complete:
		t.tween_callback(on_complete).set_delay(finish_delay)
	
	if get_index() == target_index and scroll_container:
		var old_scroll = scroll_container.vertical_scroll_mode if "vertical_scroll_mode" in scroll_container else 0
		if "vertical_scroll_mode" in scroll_container:
			scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			t.tween_callback(func(): scroll_container.vertical_scroll_mode = old_scroll).set_delay(finish_delay + 0.2)
		if scroll_container.has_method("bring_target_into_view"):
			t.tween_callback(scroll_container.bring_target_into_view.bind(self, true, false)).set_delay(finish_delay + 0.2)


func _animate_end(on_complete: Callable = Callable()) -> void:
	var t = create_tween()
	t.set_parallel(true)
	
	var slide_offset: float = 60.0
	var target_x: float = -slide_offset if (get_index() % 2 == 1) else slide_offset
	
	t.tween_property(self, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self, "position:x", target_x, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		
	var g = get_gear()
	if g:
		t.tween_property(g, "rotation", g.rotation - PI, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		
	if on_complete:
		t.set_parallel(false)
		t.tween_callback(on_complete).set_delay(0.3)


func _set_disabled_visual(disabled: bool) -> void:
	modulate = Color(0.5, 0.5, 0.5, 0.8) if disabled else Color(1.0, 1.0, 1.0, 1.0)
#endregion
