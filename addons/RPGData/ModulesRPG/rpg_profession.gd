@tool
class_name RPGProfession
extends  Resource


## Returns the class name of the resource.
## @return String - The class name.
func get_class():
	return "RPGProfession"


## Unique identifier for the Profession.
@export var id: int = 0

## Name of the Profession.
@export var name: String = ""

## Icon associated with the Profession.
@export var icon: RPGIcon = RPGIcon.new()

## Description of the Profession.
@export var description: String = ""

## Color used when the item's level is up to 10 levels below the player's profession level.
@export var name_color_far_below: Color = Color.WEB_GRAY

## Color used when the item's level is 1 to 9 levels below the player's profession level.
@export var name_color_below: Color = Color.LIGHT_GREEN

## Color used when the item's level matches the player's profession level.
@export var name_color_equal: Color = Color.WHITE

## Color used when the item's level is 1 to 9 levels above the player's profession level.
@export var name_color_above: Color = Color.ORANGE

## Color used when the item's level is more than 10 levels above the player's profession level.
@export var name_color_far_above: Color = Color.MAGENTA

## Color used when the player's level does not meet the item's minimum required level.
@export var name_color_requirement_not_met: Color = Color.RED

## Call a global event when the character levels up this profession.
@export var call_global_event_on_level_up: bool = false

## Global event that will be called upon when this profession levels up.
@export var target_global_event: int = 1

## Upon completing all sublevels of a profession level (or rank/category level),
## you will automatically advance to the next level if this option is enabled.
## Otherwise, you will need to use an event command to upgrade to the next level.
@export var auto_upgrade_level: bool = true

## Levels available for this profession. When you gain enough experience to
## complete this level, you are automatically granted the next level if one is available.
@export var levels: Array[RPGExtractionLevelComponent] = []

## Additional notes about the Profession.
@export var notes: String = ""


func _init() -> void:
	var level = RPGExtractionLevelComponent.new(tr("Novice"), 25)
	levels.append(level)


## Clears all the properties of the Profession.
func clear() -> void:
	id = 0
	name = ""
	icon.clear()
	description = ""
	set_default_colors()
	levels.clear()
	var level = RPGExtractionLevelComponent.new(tr("Novice"), 25)
	levels.append(level)
	notes = ""


## Set default color preset
func set_default_colors() -> void:
	name_color_far_below = Color.WEB_GRAY
	name_color_below = Color.LIGHT_GREEN
	name_color_equal = Color.WHITE
	name_color_above = Color.ORANGE
	name_color_far_above = Color.MAGENTA
	name_color_requirement_not_met = Color.RED


## Return interpolated color beetween 2 levels
func get_interpolated_color(level_obj1: int, level_obj2: int) -> Color:
	var colors = [
		name_color_far_below,
		name_color_below,
		name_color_equal,
		name_color_above,
		name_color_far_above
	]
	
	var min_level = -10
	var max_level = 10
	
	var level_diff = level_obj1 - level_obj2
	var clamped_diff = clamp(level_diff, min_level, max_level)
	var t = float(clamped_diff - min_level) / float(max_level - min_level)
	var color_index = t * (colors.size() - 1)
	
	var index_low = int(floor(color_index))
	var index_high = int(ceil(color_index))
	var t_sub = color_index - index_low

	var text_color = colors[index_low].lerp(colors[index_high], t_sub)
	
	return text_color


## Clones the Profession and its properties.
## @param value bool - Whether to perform a deep clone.
## @return RPGProfession - The cloned Profession.
func clone(value: bool = true) -> RPGProfession:
	var new_profession = duplicate(value)
	new_profession.icon = icon.clone(value)
	for i in new_profession.levels.size():
		new_profession.levels[i] = new_profession.levels[i].clone(value)
	
	return new_profession


func _to_string() -> String:
	var colors = [name_color_far_below, name_color_far_above]
	return "<RPGProfession id=%s name=%s levels=%s colors = %s>" % [id, name, levels, colors]
