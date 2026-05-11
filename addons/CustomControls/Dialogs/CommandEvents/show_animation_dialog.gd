@tool
extends CommandBaseDialog

#region Variables
var current_animation_id: int = 1
var current_event: RPGEvent
#endregion



#region Lifecycle & Setup
## Initializes base dialog parameters
func _ready() -> void:
	super()
	parameter_code = 72



## Populates the target dropdown handling the Player, "This Event", and all map events securely
func set_targets(events: Array, append_player: bool = true) -> void:
	var node = %TargetOptions
	node.clear()
	
	if append_player:
		node.add_item("Player")
		node.set_item_metadata(node.get_item_count() - 1, -1)
	
	if current_event:
		node.add_item("This Event")
		node.set_item_metadata(node.get_item_count() - 1, 0)
	
	for event: RPGEvent in events:
		if event.name:
			node.add_item(event.name)
		else:
			node.add_item("Event #%s" % event.id)
		node.set_item_metadata(node.get_item_count() - 1, event._uniq_id)
	
	if node.get_item_count():
		node.select(0)
	
	node.set_disabled(false)



## Parses the initial command data handling target UIDs and animation UIDs
func set_data() -> void:
	var uid_anim = parameters[0].parameters.get("animation_id", 1)
	current_animation_id = uid_anim if uid_anim > 0 else RPGSYSTEM.id_to_uid("animations", 1)
	
	var target_id = parameters[0].parameters.get("target_id", 0)
	var wait = parameters[0].parameters.get("wait", false)
	
	var items = %TargetOptions.get_item_count()
	if items > 0:
		%TargetOptions.select(0)
		for i in items:
			var real_index = %TargetOptions.get_item_metadata(i)
			if real_index == target_id:
				%TargetOptions.select(i)
				break
	
	%Wait.set_pressed(wait)
	fill_animation()



## Restructures current memory variables back into an Event Command
func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.animation_id = current_animation_id
	var selected_id = %TargetOptions.get_selected_id()
	var target_id = %TargetOptions.get_item_metadata(selected_id)
	commands[-1].parameters.target_id = target_id
	commands[-1].parameters.wait = %Wait.is_pressed()
	
	return commands
#endregion



#region Animation Selection
## Spawns the dialog to select an Animation resolving classic ID
func _on_animation_button_pressed() -> void:
	var database = RPGSYSTEM.database
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	var current_data = database.animations
	var id_selected = RPGSYSTEM.uid_to_id("animations", current_animation_id) if current_animation_id > 0 else 1
	var title = TranslationManager.tr("Animations")
	dialog.selected.connect(_on_animation_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, null)
	dialog.set_animation_mode()



## Receives the classic ID from the dialog and stores it as a secure UID
func _on_animation_selected(id: int, _target: Variant) -> void:
	current_animation_id = RPGSYSTEM.id_to_uid("animations", id)
	fill_animation()



## Refreshes the Animation text display converting UID back to classic ID
func fill_animation() -> void:
	var database = RPGSYSTEM.database
	var node = %AnimationButton
	var classic_id = RPGSYSTEM.uid_to_id("animations", current_animation_id) if current_animation_id > 0 else 1

	if database.animations.size() > classic_id and classic_id > 0:
		var animation_name = "%s: %s" % [classic_id, database.animations[classic_id].name]
		node.text = animation_name
	elif classic_id > 0:
		node.text = "⚠ Invalid Data"
	else:
		node.text = TranslationManager.tr("none")
#endregion
