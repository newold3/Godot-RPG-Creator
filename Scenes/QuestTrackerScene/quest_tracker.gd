extends PanelContainer



#region VARIABLES
@export_group("Design - General")
## StyleBox for each individual quest panel background.
@export var quest_entry_style: StyleBox

## Vertical separation between different quest entries.
@export var quest_separation: int = 10

## Global horizontal alignment for quest names and objectives.
@export var text_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT

@export_group("Design - Icons")
## Icon used for incomplete quest objectives.
@export var icon_incomplete: Texture2D

## Icon used for completed quest objectives.
@export var icon_complete: Texture2D

@export_group("Design - Quest Names")
## Settings for the quest title text.
@export var quest_name_settings: LabelSettings

@export_group("Design - Objectives")
## Settings for the objective description text when incomplete.
@export var objective_settings: LabelSettings

## Settings for the objective description text when completed.
@export var objective_completed_settings: LabelSettings

## Settings for the quantity text (e.g. 1/5).
@export var quantity_settings: LabelSettings

## Settings for the text shown when the entire quest cluster is ready to deliver.
@export var all_completed_settings: LabelSettings

## Settings for the text shown briefly when a quest fails.
@export var failure_settings: LabelSettings

## Horizontal offset applied to objectives to distinguish them from the title.
@export var objective_offset: float = 20.0

@export_group("Design - Progress Bars Templates")
## Template node for the timer. If it has no textures, it will fallback to a default circular fill.
@export var timer_bar_template: TextureProgressBar

## Template node used for objectives (Gather/Kill) and User Quests.
@export var generic_bar_template: TextureProgressBar

@export_group("Design - Gradients")
## Enables color modulation for the timer based on remaining time.
@export var use_timer_gradient: bool = false

## Gradient applied to the timer (from 0.0 = empty to 1.0 = full).
@export var timer_gradient: Gradient

## Enables color modulation for the progress bars based on completion percentage.
@export var use_progress_gradient: bool = false

## Gradient applied to the progress bars (from 0.0 = empty to 1.0 = full).
@export var progress_gradient: Gradient

@export_group("Settings")
## Toggles the tracker logic and visibility.
@export var is_active: bool = true

## Maximum number of main quests displayed in the tracker at the same time.
@export var max_displayed_quests: int = 4

## Maximum width of the tracker panel to enforce text clipping securely.
@export var max_tracker_width: float = 350.0

## Container to add the quest entries.
@export var container: VBoxContainer

var _current_visibility: float = 0.0
var _target_visibility: float = 0.0
var _tween_visibility: Tween
var _known_quest_ids: Array[int] = []
var _is_dirty: bool = false
var _dirty_timer: float = 0.0
var _failing_quests: Dictionary = {}
#endregion



#region CORE LOGIC
## Subscribes to QuestManager signals and initializes the container layout.
func _ready() -> void:
	modulate.a = 0.0
	
	if container:
		container.add_theme_constant_override("separation", quest_separation)
		
	if QuestManager:
		QuestManager.quest_started.connect(_on_quest_state_changed)
		QuestManager.quest_completed.connect(_on_quest_state_changed)
		QuestManager.quest_failed.connect(_on_quest_failure_triggered)
		
	_is_dirty = true



## Handles timer updates for timed quests, dirty UI refreshes, and visibility transitions.
func _process(delta: float) -> void:
	if _is_dirty:
		_dirty_timer += delta
		if _dirty_timer >= 0.1:
			_dirty_timer = 0.0
			_is_dirty = false
			refresh_tracker()
			
	_update_progress_bars_realtime()
	
	if not is_active and modulate.a <= 0.0:
		return
		
	var quests_empty = QuestManager.active_quests.is_empty() and _failing_quests.is_empty()
	_target_visibility = 1.0 if is_active and not quests_empty else 0.0
	
	if _current_visibility != _target_visibility:
		_animate_visibility(_target_visibility)



## Flags the tracker for a delayed refresh when a quest state changes.
func _on_quest_state_changed(_quest: GameQuest) -> void:
	_is_dirty = true



## Initiates the failure animation sequence for a quest and schedules its removal from the tracker.
func _on_quest_failure_triggered(quest: GameQuest) -> void:
	_failing_quests[quest.id] = 2.0
	_is_dirty = true
	
	await get_tree().create_timer(2.0).timeout
	_failing_quests.erase(quest.id)
	_is_dirty = true



## Called externally by the QuestManager's loop to flag the UI for a delayed update.
func update_progress() -> void:
	_is_dirty = true



## Manages the fade-in and fade-out animations of the entire tracker panel.
func _animate_visibility(target_alpha: float) -> void:
	_current_visibility = target_alpha
	
	if _tween_visibility:
		_tween_visibility.kill()
		
	_tween_visibility = create_tween()
	_tween_visibility.set_ease(Tween.EASE_OUT)
	_tween_visibility.set_trans(Tween.TRANS_SINE)
	_tween_visibility.tween_property(self, "modulate:a", target_alpha, 0.4)



## Clears and rebuilds the tracker UI, including failed quest placeholders and active timers.
func refresh_tracker() -> void:
	for child in container.get_children():
		child.queue_free()
		
	if not is_active:
		return
		
	var active_quests = QuestManager.active_quests
	var current_ids: Array[int] = []
	var displayed_count = 0
	
	for active_q in active_quests:
		if displayed_count >= max_displayed_quests: break
		if QuestManager._is_sub_quest_of_active_parent(active_q.id): continue
		
		var db_quest = QuestManager._get_quest_from_database(active_q.id)
		if not db_quest: continue
		
		var is_new = not _known_quest_ids.has(active_q.id)
		current_ids.append(active_q.id)
		_build_quest_entry(active_q, db_quest, is_new)
		displayed_count += 1
		
	for fail_id in _failing_quests.keys():
		var db_quest = QuestManager._get_quest_from_database(fail_id)
		if db_quest:
			_build_failed_entry(db_quest)
			
	_known_quest_ids = current_ids
#endregion



#region UI GENERATION
## Constructs the UI elements for a single quest entry inside a styled PanelContainer.
func _build_quest_entry(active_q: GameQuest, db_quest: RPGQuest, is_new: bool = false) -> void:
	var entry_panel = PanelContainer.new()
	if quest_entry_style:
		entry_panel.add_theme_stylebox_override("panel", quest_entry_style)
	container.add_child(entry_panel)
	
	if is_new:
		entry_panel.modulate.a = 0.0
		
	var content_vbox = VBoxContainer.new()
	entry_panel.add_child(content_vbox)
	
	var title_hbox = HBoxContainer.new()
	_apply_container_alignment(title_hbox)
	content_vbox.add_child(title_hbox)
	
	var title_label = Label.new()
	var safe_w = max_tracker_width - 40.0
	_configure_label(title_label, tr(db_quest.name), quest_name_settings, safe_w)
	title_hbox.add_child(title_label)
	
	var objectives_box = VBoxContainer.new()
	_apply_container_alignment(objectives_box)
	content_vbox.add_child(objectives_box)
	
	if QuestManager._is_cluster_ready_to_deliver(active_q.id):
		_add_simple_label(objectives_box, tr("Completed"), Color.GREEN, all_completed_settings)
	else:
		if active_q.timer > 0.0:
			_add_timer_display(title_hbox, active_q)
		_populate_objectives(objectives_box, active_q, db_quest)
		
	if is_new:
		call_deferred("_play_entry_animation", entry_panel)



## Plays the delayed entrance animation for newly added quest panels avoiding container layout conflicts.
func _play_entry_animation(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
		
	panel.position.x += 50.0
	
	var tw = panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.5)
	tw.tween_property(panel, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)



## Instantiates the timer progress bar using the template or a circular fallback.
func _add_timer_display(parent: Node, active_q: GameQuest) -> void:
	var bar: TextureProgressBar
	
	if timer_bar_template:
		bar = timer_bar_template.duplicate()
		bar.visible = true
	else:
		bar = TextureProgressBar.new()
		bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		bar.custom_minimum_size = Vector2(24, 24)
		
	bar.name = "TimerBar"
	bar.set_meta("quest_id", active_q.id)
	bar.add_to_group("quest_tracker_bars")
	
	var owner_pquest = QuestManager._get_owner_quest_configuration(active_q)
	var db_quest = QuestManager._get_quest_from_database(active_q.id)
	
	if owner_pquest and owner_pquest.use_custom_timer:
		bar.max_value = owner_pquest.custom_timer
	elif db_quest:
		bar.max_value = db_quest.time_limit
	else:
		bar.max_value = active_q.timer
		
	bar.value = active_q.timer
	
	if use_timer_gradient and timer_gradient and bar.max_value > 0.0:
		bar.tint_progress = timer_gradient.sample(1.0 - (bar.value / bar.max_value))
		
	parent.add_child(bar)



## Constructs a temporary entry for failed quests with a relative vibration effect preserving margins.
func _build_failed_entry(db_quest: RPGQuest) -> void:
	var entry_panel = PanelContainer.new()
	if quest_entry_style:
		entry_panel.add_theme_stylebox_override("panel", quest_entry_style)
	container.add_child(entry_panel)
	
	var content = VBoxContainer.new()
	entry_panel.add_child(content)
	
	var title_hbox = HBoxContainer.new()
	_apply_container_alignment(title_hbox)
	content.add_child(title_hbox)
	
	var title = Label.new()
	var safe_w = max_tracker_width - 40.0
	_configure_label(title, tr(db_quest.name), quest_name_settings, safe_w)
	title_hbox.add_child(title)
	
	var fail_hbox = HBoxContainer.new()
	_apply_container_alignment(fail_hbox)
	content.add_child(fail_hbox)
	
	var fail_label = Label.new()
	_configure_label(fail_label, tr("FAILED"), failure_settings, safe_w)
	if not failure_settings:
		fail_label.modulate = Color.RED
	fail_hbox.add_child(fail_label)
	
	var vib_tw = entry_panel.create_tween()
	for i in range(10):
		var rand_pos = Vector2(randf_range(-4, 4), randf_range(-2, 2))
		vib_tw.tween_property(content, "position", rand_pos, 0.05).as_relative()
		vib_tw.tween_property(content, "position", -rand_pos, 0.05).as_relative()



## Populates the objectives container with individual lines, shifting them based on alignment.
func _populate_objectives(box: VBoxContainer, active_q: GameQuest, db_quest: RPGQuest) -> void:
	if db_quest.multi_quests.is_empty():
		_add_objective_line(box, active_q, db_quest)
	else:
		if db_quest.type != RPGEnums.QuestMode.TALK_TO_NPC or db_quest.target_event.event_id != -1:
			_add_objective_line(box, active_q, db_quest)
		for sub_id in db_quest.multi_quests:
			var sub_active = QuestManager._get_active_quest_by_id(sub_id)
			var sub_db = QuestManager._get_quest_from_database(sub_id)
			if sub_active and sub_db:
				_add_objective_line(box, sub_active, sub_db)



## Adds a single objective line including optional icons, progress bars, and custom indentation.
func _add_objective_line(parent_box: Node, active_q: GameQuest, db_quest: RPGQuest) -> void:
	var line_container = HBoxContainer.new()
	line_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_box.add_child(line_container)
	
	_apply_alignment_spacing(line_container)
	
	var is_completed = active_q.status == RPGEnums.QuestStatus.COMPLETED_PENDING_DELIVERY
	var status_texture = icon_complete if is_completed else icon_incomplete
	
	if status_texture:
		var tex = TextureRect.new()
		tex.texture = status_texture
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.custom_minimum_size = Vector2(16, 16)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line_container.add_child(tex)
		
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_container.add_child(content_vbox)
	
	var text_hbox = HBoxContainer.new()
	content_vbox.add_child(text_hbox)
	
	var qty = _get_objective_quantity_text(active_q, db_quest)
	var qty_w = 0.0
	
	if qty != "":
		qty_w = _calculate_text_width(qty, quantity_settings) + 10.0
		
	var safe_w = max_tracker_width - objective_offset - 60.0 - qty_w
	
	var obj_label = Label.new()
	var label_settings = objective_completed_settings if is_completed else objective_settings
	_configure_label(obj_label, _get_objective_text_only(db_quest), label_settings, safe_w)
	text_hbox.add_child(obj_label)
	
	if qty != "":
		var num_label = Label.new()
		num_label.text = qty
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if quantity_settings:
			num_label.label_settings = quantity_settings
		text_hbox.add_child(num_label)
		
	_add_progress_bar_if_needed(content_vbox, active_q, db_quest)



## Creates and configures a progress bar by duplicating the generic template.
func _add_progress_bar_if_needed(parent: Node, active_q: GameQuest, db_quest: RPGQuest) -> void:
	var needs_bar = db_quest.type == RPGEnums.QuestMode.USER_QUEST or \
					db_quest.type == RPGEnums.QuestMode.GATHER_ITEM or \
					db_quest.type == RPGEnums.QuestMode.BOUNTY_HUNTS
					
	if not needs_bar or not generic_bar_template: return
	
	var bar = generic_bar_template.duplicate()
	bar.visible = true
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	bar.custom_minimum_size.y = 8
	bar.min_value = 0
	
	if db_quest.type == RPGEnums.QuestMode.GATHER_ITEM:
		bar.max_value = db_quest.quantity
		bar.value = _get_current_item_amount(db_quest)
	elif db_quest.type == RPGEnums.QuestMode.BOUNTY_HUNTS:
		bar.max_value = db_quest.quantity
		bar.value = int(active_q.current_progress * db_quest.quantity)
	else:
		bar.max_value = 100
		bar.value = active_q.current_progress * 100.0
		
	if use_progress_gradient and progress_gradient and bar.max_value > 0.0:
		bar.tint_progress = progress_gradient.sample(bar.value / bar.max_value)
		
	parent.add_child(bar)
#endregion



#region FORMATTING HELPERS
## Applies clipping parameters and correctly bounds the width for center/right alignments to prevent collapse.
func _configure_label(label: Label, text: String, settings: LabelSettings, max_allowed_w: float) -> void:
	label.text = text
	label.horizontal_alignment = text_alignment
	
	if settings:
		label.label_settings = settings
		
	var actual_w = _calculate_text_width(text, settings)
	
	if text_alignment == HORIZONTAL_ALIGNMENT_LEFT:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.custom_minimum_size.x = min(actual_w, max_allowed_w)
		
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS



## Synchronously calculates the pixel width of a string using the provided settings or the default theme.
func _calculate_text_width(text: String, settings: LabelSettings) -> float:
	var font: Font
	var font_size: int = 16
	
	if settings and settings.font:
		font = settings.font
		font_size = settings.font_size
	else:
		var dummy = Label.new()
		font = dummy.get_theme_font("font")
		font_size = dummy.get_theme_font_size("font_size")
		dummy.free()
		
	if font:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return text.length() * 10.0



## Iterates through all registered progress bars to update their values (timers and progress) in real-time.
func _update_progress_bars_realtime() -> void:
	for bar in get_tree().get_nodes_in_group("quest_tracker_bars"):
		if not is_instance_valid(bar): continue
		
		var q_id = bar.get_meta("quest_id", -1)
		var active_q = QuestManager._get_active_quest_by_id(q_id)
		
		if active_q:
			if bar.name == "TimerBar":
				bar.value = active_q.timer
				if use_timer_gradient and timer_gradient and bar.max_value > 0.0:
					bar.tint_progress = timer_gradient.sample(1.0 - (bar.value / bar.max_value))
			else:
				var db_quest = QuestManager._get_quest_from_database(q_id)
				if db_quest:
					if db_quest.type == RPGEnums.QuestMode.GATHER_ITEM:
						bar.value = _get_current_item_amount(db_quest)
					elif db_quest.type == RPGEnums.QuestMode.BOUNTY_HUNTS:
						bar.value = int(active_q.current_progress * db_quest.quantity)
					else:
						bar.value = active_q.current_progress * 100.0
						
					if use_progress_gradient and progress_gradient and bar.max_value > 0.0:
						bar.tint_progress = progress_gradient.sample(bar.value / bar.max_value)



## Helper to ensure boxes shrink to fit content based on text alignment logic.
func _apply_container_alignment(container_node: Container) -> void:
	if text_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		container_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	elif text_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		container_node.size_flags_horizontal = Control.SIZE_SHRINK_END
	else:
		container_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL



## Applies indentation or alignment spacers based on the global text_alignment setting.
func _apply_alignment_spacing(container_node: HBoxContainer) -> void:
	if text_alignment == HORIZONTAL_ALIGNMENT_LEFT and objective_offset > 0:
		var spacer = Control.new()
		spacer.custom_minimum_size.x = objective_offset
		container_node.add_child(spacer)
	elif text_alignment == HORIZONTAL_ALIGNMENT_RIGHT and objective_offset > 0:
		var end_spacer = Control.new()
		end_spacer.custom_minimum_size.x = objective_offset
		container_node.add_child(end_spacer)
		container_node.move_child(end_spacer, container_node.get_child_count() - 1)



## Helper to add a simple formatted label to a box sharing the same container rules.
func _add_simple_label(box: Node, text: String, color: Color, settings: LabelSettings) -> void:
	var hbox = HBoxContainer.new()
	box.add_child(hbox)
	_apply_alignment_spacing(hbox)
	
	var l = Label.new()
	_configure_label(l, text, settings, max_tracker_width - 60.0)
	if not settings:
		l.modulate = color
	hbox.add_child(l)



## Returns the raw objective description string with applied translations.
func _get_objective_text_only(db_quest: RPGQuest) -> String:
	match db_quest.type:
		RPGEnums.QuestMode.TALK_TO_NPC: return tr("Talk to %s") % _get_npc_name(db_quest)
		RPGEnums.QuestMode.GATHER_ITEM: return tr("Get %s") % _get_item_name(db_quest)
		RPGEnums.QuestMode.BOUNTY_HUNTS: return tr("Defeat %s") % _get_enemy_name(db_quest.enemy_id)
		RPGEnums.QuestMode.FIND_LOCATION: return tr("Reach %s") % RPGSYSTEM.map_infos.get_map_name_from_id(db_quest.target_event.map_id)
		RPGEnums.QuestMode.USER_QUEST: return tr(db_quest.description)
	return ""



## Returns the progress fraction string (e.g., 2/5).
func _get_objective_quantity_text(active_q: GameQuest, db_quest: RPGQuest) -> String:
	match db_quest.type:
		RPGEnums.QuestMode.GATHER_ITEM: return "%d/%d" % [_get_current_item_amount(db_quest), db_quest.quantity]
		RPGEnums.QuestMode.BOUNTY_HUNTS: 
			var req = db_quest.quantity
			return "%d/%d" % [int(active_q.current_progress * req), req]
	return ""
#endregion



#region DATA HELPERS
## Extracts the NPC name from the global database with fallback translation.
func _get_npc_name(db_quest: RPGQuest) -> String:
	var ev = db_quest.target_event
	if ev and ev.map_id != -1 and ev.event_id != -1:
		var data = RPGSYSTEM.map_infos.get_event(ev.map_id, ev.event_id)
		return data.get("name", tr("Someone"))
	return tr("Someone")



## Returns the item name from the database based on category with fallback translations.
func _get_item_name(db_quest: RPGQuest) -> String:
	var id = db_quest.item_id
	match db_quest.item_type:
		0: return RPGSYSTEM.database.items[id].name if id < RPGSYSTEM.database.items.size() else tr("Item")
		1: return RPGSYSTEM.database.weapons[id].name if id < RPGSYSTEM.database.weapons.size() else tr("Weapon")
		2: return RPGSYSTEM.database.armors[id].name if id < RPGSYSTEM.database.armors.size() else tr("Armor")
		3: return RPGSYSTEM.database.costumes[id].name if id < RPGSYSTEM.database.costumes.size() else tr("Costume")
	return tr("Unknown")



## Returns the current item amount in inventory.
func _get_current_item_amount(db_quest: RPGQuest) -> int:
	match db_quest.item_type:
		0: return GameManager.get_item_amount(db_quest.item_id)
		1: return GameManager.get_weapon_amount(db_quest.item_id)
		2: return GameManager.get_armor_amount(db_quest.item_id)
		3: return GameManager.get_costume_amount(db_quest.item_id)
	return 0



## Returns the enemy name from the database with fallback translation.
func _get_enemy_name(enemy_id: int) -> String:
	if enemy_id >= 0 and enemy_id < RPGSYSTEM.database.enemies.size():
		return RPGSYSTEM.database.enemies[enemy_id].name
	return tr("Enemy")
#endregion
