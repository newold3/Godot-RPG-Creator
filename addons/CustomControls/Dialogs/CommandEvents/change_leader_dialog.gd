@tool
extends CommandBaseDialog

#region Variables
var leader_id: int = -1
#endregion



#region Lifecycle & Setup
## Initializes the base configuration for the Leader command
func _ready() -> void:
	super()
	parameter_code = 36



## Parses the initial command data and configures the UI state
func set_data() -> void:
	var uid = parameters[0].parameters.get("leader_id", 1)
	var is_locked = parameters[0].parameters.get("is_locked", false)
	set_leader(uid, is_locked)



## Updates the visually selected leader safely translating the UID
func set_leader(uid: int = -1, is_locked: bool = false) -> void:
	uid = RPGSYSTEM.id_to_uid("actors", uid) if uid > 0 else -1
	self.leader_id = uid
	%Lock.set_pressed(is_locked)
	
	var classic_id = RPGSYSTEM.uid_to_id("actors", uid)
	var actors = RPGSYSTEM.database.actors
	
	if classic_id > 0 and classic_id < actors.size():
		%ChoseActorButton.text = TranslationManager.tr("%s: %s ") % [classic_id, actors[classic_id].name]
	else:
		%ChoseActorButton.text = TranslationManager.tr("Select a leader")



## Compiles the UI state back into an Event Command array
func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.leader_id = leader_id
	commands[-1].parameters.is_locked = %Lock.is_pressed()
	return commands
#endregion



#region Selection Logic
## Opens the selection dialog converting UID to classic ID dynamically
func _on_chose_actor_button_pressed() -> void:
	var actors = RPGSYSTEM.database.actors

	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.database = RPGSYSTEM.database
	dialog.data = actors
	dialog.destroy_on_hide = true

	dialog.selected.connect(_on_leader_selected)
	
	var classic_id = RPGSYSTEM.uid_to_id("actors", leader_id) if leader_id > 0 else 1
	dialog.setup(actors, classic_id, "Actors", %ChoseActorButton)



## Converts classic ID returned from dialog back to secure UID
func _on_leader_selected(id: int, target: Variant) -> void:
	leader_id = RPGSYSTEM.id_to_uid("actors", id)
	var actors = RPGSYSTEM.database.actors
	target.text = "%s: %s " % [id, actors[id].name]
#endregion
