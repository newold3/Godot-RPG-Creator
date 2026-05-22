@tool
class_name MapGeneratorFloatingPanel
extends PanelContainer


#region VARIABLES
var current_generator: Node
var is_dragging_panel: bool = false
var is_collapsed: bool = false

var presets_data: MapGeneratorPresets
var _save_preset_dialog: ConfirmationDialog
var _preset_name_input: LineEdit
var _preset_seed_check: CheckBox
var _preset_variable_size_check: CheckBox

var _generator_backup: Dictionary = {}

@onready var content_vbox: VBoxContainer = %ContentVBox
@onready var top_mini_bar: HBoxContainer = %TopMiniBar
@onready var collapse_btn: Button = %CollapseBtn
@onready var drag_handle: Panel = %DragHandle

@onready var layer_select: OptionButton = %LayerSelect
@onready var mode_option: OptionButton = %ModeOption
@onready var width_spin: SpinBox = %WidthSpin
@onready var height_spin: SpinBox = %HeightSpin
@onready var collision_check: CheckBox = %CollisionCheck
@onready var debug_btn: Button = %BtnDebugPath

@onready var btn_gen_map: Button = %BtnGenMap
@onready var btn_clear_maps: Button = %BtnClearMaps
@onready var btn_gen_events: Button = %BtnGenEvents
@onready var btn_clear_events: Button = %BtnClearEvents
@onready var btn_decorators: Button = %BtnDecorators
@onready var btn_edit_events: Button = %BtnEditEvents
@onready var btn_export: Button = %BtnExport
@onready var mini_gen_btn: Button = %MiniGenBtn
@onready var mini_exp_btn: Button = %MiniExpBtn

@onready var preset_list: OptionButton = %PresetList
@onready var btn_save_preset: Button = %BtnSavePreset
@onready var btn_edit_presets: Button = %BtnEditPresets

@onready var btn_compact1: Button = %BtnCompact1
@onready var btn_compact2: Button = %BtnCompact2
#endregion



## Enlaza los eventos internos de la interfaz al cargarse
func _ready() -> void:
	if not Engine.is_editor_hint(): return
	
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	collapse_btn.pressed.connect(_on_collapse_toggled)
	
	layer_select.item_selected.connect(_on_target_layer_selected)
	mode_option.item_selected.connect(_on_mode_selected)
	width_spin.value_changed.connect(_on_width_changed)
	height_spin.value_changed.connect(_on_height_changed)
	collision_check.toggled.connect(_on_collisions_toggled)
	debug_btn.toggled.connect(_on_debug_toggled)
	
	btn_gen_map.pressed.connect(_on_generate_pressed)
	mini_gen_btn.pressed.connect(_on_generate_pressed)
	btn_clear_maps.pressed.connect(_on_clear_maps_pressed)
	btn_gen_events.pressed.connect(_on_generate_events_pressed)
	btn_clear_events.pressed.connect(_on_clear_events_pressed)
	btn_decorators.pressed.connect(_on_decorators_pressed)
	btn_edit_events.pressed.connect(_on_edit_events_pressed)
	btn_export.pressed.connect(_on_export_pressed)
	mini_exp_btn.pressed.connect(_on_export_pressed)
	
	preset_list.item_selected.connect(_on_preset_selected)
	btn_save_preset.pressed.connect(_on_save_preset_pressed)
	btn_edit_presets.pressed.connect(_on_edit_preset_pressed)
	
	btn_compact1.shunked.connect(_on_compact1_toggled)
	btn_compact2.shunked.connect(_on_compact2_toggled)
	
	visibility_changed.connect(_on_visibility_changed)
	
	_apply_visual_styles()
	_load_presets_ui()
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(self)
	
	_restore_ui_persistence.call_deferred()



func _on_visibility_changed() -> void:
	if visible:
		_restore_ui_persistence()


func _process(delta: float) -> void:
	var saved_pos: Vector2 = FileCache.options.get("map_generator_panel_pos", Vector2(40, 40))
	if saved_pos != global_position:
		_restore_ui_persistence()


## Recupera todos los estados guardados del panel esperando un frame para calcular dimensiones
func _restore_ui_persistence() -> void:
	while not is_inside_tree() or not FileCache.cache_setted:
		await RenderingServer.frame_post_draw
	
	var saved_pos: Vector2 = FileCache.options.get("map_generator_panel_pos", Vector2(40, 40))
	global_position = saved_pos
	
	if FileCache.options.get("map_gen_main_collapsed", false):
		_on_collapse_toggled()
		
	btn_compact1.set_state(FileCache.options.get("map_gen_comp1_shrunk", false))
		
	btn_compact2.set_state(FileCache.options.get("map_gen_comp2_shrunk", false))
		
	_clamp_panel_position()



#region Presets
func _load_presets_ui() -> void:
	if not presets_data:
		presets_data = MapGeneratorPresets.load_presets()
		
	preset_list.clear()
	preset_list.add_item("None", 0)
	
	var idx: int = 1
	
	for preset in presets_data.presets_list:
		preset_list.add_item(preset.get("preset_name", "Unknown"), idx)
		idx += 1



func _build_save_preset_dialog() -> void:
	_save_preset_dialog = ConfirmationDialog.new()
	_save_preset_dialog.title = "Save Map Preset"
	
	var vbox: VBoxContainer = VBoxContainer.new()
	_preset_name_input = LineEdit.new()
	_preset_name_input.placeholder_text = "Preset Name"
	vbox.add_child(_preset_name_input)
	
	_preset_seed_check = CheckBox.new()
	_preset_seed_check.text = "Save exact seed (Exact copy)"
	vbox.add_child(_preset_seed_check)
	
	_save_preset_dialog.add_child(vbox)
	_save_preset_dialog.confirmed.connect(_on_save_preset_confirmed)
	add_child(_save_preset_dialog)



func _force_apply_preset(index: int) -> void:
	if index == 0 or not current_generator or not presets_data:
		return
		
	var preset_dict: Dictionary = presets_data.presets_list[index - 1]
	
	var layer_map: Dictionary = {
		"ts_base_path": current_generator.layer_ground_base,
		"ts_walls_path": current_generator.layer_walls,
		"ts_detail_path": current_generator.layer_ground_detail,
		"ts_shadows_path": current_generator.layer_shadows,
		"ts_env_path": current_generator.layer_environment
	}
	
	for key in layer_map.keys():
		if preset_dict.has(key):
			var saved_path: String = preset_dict[key]
			var target_layer = layer_map[key]
			
			if is_instance_valid(target_layer) and not saved_path.is_empty() and ResourceLoader.exists(saved_path):
				target_layer.tile_set = ResourceLoader.load(saved_path)
				
	var forbidden_keys: Array = ["preset_name", "ts_base_path", "ts_walls_path", "ts_detail_path", "ts_shadows_path", "ts_env_path", "preset_events", "custom_decorator_data"]
	
	for prop in preset_dict.keys():
		if not prop in forbidden_keys and prop in current_generator:
			current_generator.set(prop, preset_dict[prop])
			
	if preset_dict.has("preset_events"):
		current_generator.set_meta("preset_events_data", preset_dict["preset_events"])
	else:
		current_generator.set_meta("preset_events_data", [])
		
	if preset_dict.has("custom_decorator_data"):
		current_generator.decorator_data = preset_dict["custom_decorator_data"].duplicate(true)
		
	sync_with_generator(current_generator)


func _on_preset_selected(index: int) -> void:
	if index == 0:
		if current_generator:
			current_generator.remove_meta("preset_events_data")
			current_generator.use_fixed_seed = false
			sync_with_generator(current_generator)
	else:
		_force_apply_preset(index)



func _on_save_preset_pressed() -> void:
	if not current_generator:
		return
		
	if not is_instance_valid(_save_preset_dialog):
		_build_save_preset_dialog()
		
	_preset_name_input.text = "Preset " + str(presets_data.presets_list.size() + 1)
	_preset_seed_check.button_pressed = false
	_save_preset_dialog.popup_centered(Vector2(300, 150))


func _on_edit_preset_pressed() -> void:
	var path: String = "res://addons/CustomControls/Dialogs/edit_map_generator_presets_dialog.tscn"
	var dialog: Window = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	if dialog:
		dialog.set_data(presets_data)
		var current_preset_name: String = preset_list.get_item_text(preset_list.get_selected_id())
		
		dialog.tree_exited.connect(func():
			_load_presets_ui()
			
			var found_idx: int = 0
			for i in range(preset_list.item_count):
				if preset_list.get_item_text(i) == current_preset_name:
					found_idx = i
					break
					
			preset_list.select(found_idx)
		)



func _on_save_preset_confirmed() -> void:
	var new_preset: Dictionary = {}
	new_preset["preset_name"] = _preset_name_input.text
	
	var props: Array = current_generator.get_script().get_script_property_list()
	
	for p in props:
		var usage: int = p.usage
		if usage & PROPERTY_USAGE_STORAGE or usage & PROPERTY_USAGE_EDITOR:
			var prop_name: String = p.name
			
			if prop_name == "current_map_events":
				continue
				
			var val: Variant = current_generator.get(prop_name)
			
			if val is Resource:
				new_preset[prop_name] = val.duplicate(true)
			elif typeof(val) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_VECTOR2I, TYPE_STRING, TYPE_DICTIONARY, TYPE_ARRAY]:
				new_preset[prop_name] = val
				
	var layer_map: Dictionary = {
		"ts_base_path": current_generator.layer_ground_base,
		"ts_walls_path": current_generator.layer_walls,
		"ts_detail_path": current_generator.layer_ground_detail,
		"ts_shadows_path": current_generator.layer_shadows,
		"ts_env_path": current_generator.layer_environment
	}
	
	for key in layer_map.keys():
		var layer = layer_map[key]
		if is_instance_valid(layer) and layer.tile_set and not layer.tile_set.resource_path.is_empty():
			new_preset[key] = layer.tile_set.resource_path
			
	var event_counts: Dictionary = {}
	for ev in current_generator.current_map_events:
		if event_counts.has(ev.template_uid):
			event_counts[ev.template_uid] += 1
		else:
			event_counts[ev.template_uid] = 1
			
	var optimized_events: Array = []
	for uid in event_counts.keys():
		optimized_events.append({"uid": uid, "count": event_counts[uid]})
		
	new_preset["preset_events"] = optimized_events
	
	var optimized_decorators: Array[Dictionary] = []
	var env_layer: TileMapLayer = current_generator.layer_environment
	var det_layer: TileMapLayer = current_generator.layer_ground_detail
	var dec_data: Array = current_generator.decorator_data
	
	for dec in dec_data:
		var config_copy: Dictionary = dec.duplicate(true)
		var count: int = 0
		var is_detail: bool = config_copy.get("is_detail", false)
		var target_layer = det_layer if is_detail else env_layer
		
		if is_instance_valid(target_layer):
			for cell in target_layer.get_used_cells():
				var s_id: int = target_layer.get_cell_source_id(cell)
				var a_crd: Vector2i = target_layer.get_cell_atlas_coords(cell)
				
				var match_p: bool = (s_id == config_copy.get("source_id", -1) and a_crd == config_copy.get("atlas_coords", Vector2i(-1,-1)))
				var match_a: bool = (s_id == config_copy.get("source_id", -1) and a_crd == config_copy.get("alt_atlas_coords", Vector2i(-1,-1)))
				
				if match_p or match_a:
					count += 1
					
		config_copy["appear_percent"] = 100.0
		config_copy["max_quantity"] = count
		optimized_decorators.append(config_copy)
		
	new_preset["custom_decorator_data"] = optimized_decorators
	
	if _preset_seed_check.button_pressed:
		new_preset["use_fixed_seed"] = true
		new_preset["map_seed"] = current_generator.map_seed
		new_preset["use_random_noise"] = false
	else:
		new_preset["use_fixed_seed"] = false
		new_preset["use_random_noise"] = true
		
	presets_data.presets_list.append(new_preset)
	presets_data.save_presets()
	
	_load_presets_ui()
	var new_index: int = presets_data.presets_list.size()
	preset_list.select(new_index)
	_on_preset_selected(new_index)


#endregion



## Sincroniza los valores visuales del panel con los del generador activo
func sync_with_generator(generator: Node) -> void:
	current_generator = generator
	if not current_generator: return
	
	# Limpieza de seguridad: Si la UI dice "None", destruimos la metadata fantasma del nodo
	if preset_list.selected == 0 and current_generator.has_meta("preset_events_data"):
		current_generator.remove_meta("preset_events_data")
	
	layer_select.select(current_generator.target_layer_mode)
	
	_update_mode_options()
	width_spin.set_value_no_signal(current_generator.map_width)
	height_spin.set_value_no_signal(current_generator.map_height)
	collision_check.set_pressed_no_signal(current_generator.add_collisions_after_generation)
	debug_btn.set_pressed_no_signal(current_generator.debug_path_enabled)
	
	_update_debug_btn_color(current_generator.debug_path_enabled)


func _update_mode_options() -> void:
	mode_option.clear()
	var names = current_generator.get_mode_names()
	for i in range(names.size()):
		mode_option.add_item(names[i], i)
		
	mode_option.select(current_generator.generation_mode)


## Restaura los estilos por código para asegurar los colores de interacción
func _apply_visual_styles() -> void:
	btn_clear_maps.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	btn_clear_events.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	btn_decorators.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	btn_edit_events.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	mini_exp_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	
	var style_export = StyleBoxFlat.new()
	style_export.bg_color = Color(0.15, 0.40, 0.15, 1.0)
	style_export.set_corner_radius_all(4)
	btn_export.add_theme_stylebox_override("normal", style_export)
	
	var style_export_hover = style_export.duplicate()
	style_export_hover.bg_color = Color(0.20, 0.50, 0.20, 1.0)
	btn_export.add_theme_stylebox_override("hover", style_export_hover)
	
	var style_export_pressed = style_export.duplicate()
	style_export_pressed.bg_color = Color(0.10, 0.30, 0.10, 1.0)
	btn_export.add_theme_stylebox_override("pressed", style_export_pressed)



#region INTERACTION LOGIC
## Expande o colapsa el panel conservando acciones principales
func _on_collapse_toggled() -> void:
	is_collapsed = !is_collapsed
	content_vbox.visible = !is_collapsed
	top_mini_bar.visible = is_collapsed
	collapse_btn.text = "+" if is_collapsed else " - "
	size.y = 0
	FileCache.options["map_gen_main_collapsed"] = is_collapsed



## Intercepta el ratón en la barra superior para mover el panel por el editor
func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			is_dragging_panel = true
		else:
			is_dragging_panel = false
			FileCache.options["map_generator_panel_pos"] = global_position
			
	elif event is InputEventMouseMotion and is_dragging_panel:
		position += event.relative
		FileCache.options["map_generator_panel_pos"] = global_position
		_clamp_panel_position()



## Asegura que el panel no se salga de los bordes del editor
func _clamp_panel_position() -> void:
	var viewport = EditorInterface.get_editor_viewport_2d()
	if not viewport: return
	
	var vp_container = viewport.get_parent()
	var parent_rect: Rect2 = vp_container.get_global_rect()
	var margin: float = 20.0
	
	var min_x = parent_rect.position.x + margin
	var min_y = parent_rect.position.y + margin
	var max_x = parent_rect.end.x - size.x - 10.0
	var max_y = parent_rect.end.y - size.y - 10.0
	
	var current_pos = global_position
	current_pos.x = clamp(current_pos.x, min_x, max_x)
	current_pos.y = clamp(current_pos.y, min_y, max_y)
	
	if global_position != current_pos:
		global_position = current_pos



## Cambia el color del botón de debug según su estado
func _update_debug_btn_color(toggled_on: bool) -> void:
	return
	debug_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2) if toggled_on else Color(0.6, 0.9, 0.6))



## Guarda el estado del primer botón compactado
func _on_compact1_toggled(is_shrunk: bool) -> void:
	FileCache.options["map_gen_comp1_shrunk"] = is_shrunk



## Guarda el estado del segundo botón compactado
func _on_compact2_toggled(is_shrunk: bool) -> void:
	FileCache.options["map_gen_comp2_shrunk"] = is_shrunk
#endregion



#region SIGNAL FORWARDING
## Pasa las señales de los botones a la instancia del generador
func _on_target_layer_selected(id: int) -> void:
	if current_generator:
		current_generator.target_layer_mode = id
		EditorInterface.mark_scene_as_unsaved()



func _on_mode_selected(id: int) -> void:
	if current_generator:
		current_generator.generation_mode = id
		EditorInterface.mark_scene_as_unsaved()
		current_generator.notify_property_list_changed()



func _on_width_changed(val: float) -> void:
	if current_generator:
		current_generator.map_width = int(val)
		EditorInterface.mark_scene_as_unsaved()



func _on_height_changed(val: float) -> void:
	if current_generator:
		current_generator.map_height = int(val)
		EditorInterface.mark_scene_as_unsaved()



func _on_collisions_toggled(pressed: bool) -> void:
	if current_generator:
		current_generator.add_collisions_after_generation = pressed
		EditorInterface.mark_scene_as_unsaved()



func _on_generate_pressed() -> void:
	if not current_generator:
		return
	
	propagate_call("apply")
		
	current_generator._start_generation_thread()



func _on_clear_maps_pressed() -> void:
	if current_generator and not current_generator.is_generating:
		current_generator.clear_all_maps()



func _on_generate_events_pressed() -> void:
	if current_generator: current_generator.generate_random_events()



func _on_clear_events_pressed() -> void:
	if current_generator: current_generator.clear_all_events()



func _on_decorators_pressed() -> void:
	if current_generator: current_generator.open_environment_decorator_dialog()



func _on_edit_events_pressed() -> void:
	if current_generator: current_generator.open_event_editor_dialog()



func _on_debug_toggled(toggled_on: bool) -> void:
	if current_generator:
		current_generator.debug_path_enabled = toggled_on
		_update_debug_btn_color(toggled_on)
		if toggled_on: current_generator._draw_debug_path()
		else: current_generator._clear_debug_path()
		EditorInterface.mark_scene_as_unsaved()



func _on_export_pressed() -> void:
	if current_generator: current_generator.export_to_rpgmap()
#endregion


func _on_update_modes_pressed() -> void:
	if current_generator: current_generator._load_modes()
	_update_mode_options()
