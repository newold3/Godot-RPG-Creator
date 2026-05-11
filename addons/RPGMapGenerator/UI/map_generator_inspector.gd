extends EditorInspectorPlugin


## Checks if this inspector should handle the given object type
func _can_handle(object: Object) -> bool:
	return object is MapGenerator


## Injects the custom progress UI at the beginning of the inspector
func _parse_begin(object: Object) -> void:
	var progress_ui: ProgressUI = ProgressUI.new()
	progress_ui.target = object
	add_custom_control(progress_ui)


## Intercepts specific properties to assign them custom UI editors
func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, usage_flags: int, _wide: bool) -> bool:
	if not (usage_flags & PROPERTY_USAGE_EDITOR):
		return false
		
	if name in ["use_single_floor", "single_floor_tile", "use_single_wall", "single_wall_tile", "use_single_roof", "single_roof_tile"]:
		return true
		
	if name in ["terrain_floor", "terrain_wall", "terrain_roof", "terrain_water", "terrain_snow", "terrain_desert", "terrain_mountain", "terrain_tree", "large_tile_shadow", "small_tile_shadow", "terrain_land", "terrain_volcano", "terrain_swamp"]:
		var property_script = load("res://addons/RPGMapGenerator/UI/terrain_single_editor_property.gd")
		
		if property_script:
			var editor_property = property_script.new(name)
			add_property_editor(name, editor_property)
			return true
			
	return false


#region INNER CLASSES
class ProgressUI extends VBoxContainer:
	var target: MapGenerator
	var progress_bar: ProgressBar
	var status_label: Label
	
	func _init() -> void:
		custom_minimum_size = Vector2(0, 50)
		visible = false
		status_label = Label.new()
		status_label.text = "Ready"
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(status_label)
		progress_bar = ProgressBar.new()
		progress_bar.min_value = 0.0
		progress_bar.max_value = 100.0
		add_child(progress_bar)
		
	func _process(_delta: float) -> void:
		if is_instance_valid(target):
			if target.is_generating:
				visible = true
				var data = target.get_progress_data()
				progress_bar.value = data["progress"]
				status_label.text = data["status"]
			else:
				visible = false
#endregion
