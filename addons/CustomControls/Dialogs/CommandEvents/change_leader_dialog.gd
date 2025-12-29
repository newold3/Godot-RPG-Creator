@tool
extends CommandBaseDialog

var leader_id: int = -1


func _ready() -> void:
	super()
	parameter_code = 36


func set_data() -> void:
	var leader_id = parameters[0].parameters.get("leader_id", 1)
	var is_locked = parameters[0].parameters.get("is_locked", false)
	set_leader(leader_id, is_locked)

func set_leader(leader_id: int = -1, is_locked: bool = false) -> void:
	var actors = RPGSYSTEM.database.actors
	if actors.size() > leader_id and leader_id != -1:
		%ChoseActorButton.text = TranslationManager.tr("%s: %s ") % [leader_id, actors[leader_id].name]
	else:
		%ChoseActorButton.text = TranslationManager.tr("Select a leader")

	self.leader_id = leader_id
	%Lock.set_pressed(is_locked)

func build_command_list() -> Array[RPGEventCommand]:
	var commands = super()
	commands[-1].parameters.leader_id = leader_id
	commands[-1].parameters.is_locked = %Lock.is_pressed()
	return commands

func _on_chose_actor_button_pressed() -> void:
	var actors = RPGSYSTEM.database.actors

	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)

	dialog.database = RPGSYSTEM.database
	dialog.data = actors
	dialog.destroy_on_hide = true

	dialog.selected.connect(_on_leader_selected)

	dialog.setup(actors, leader_id, "Actors", %ChoseActorButton)

func _on_leader_selected(id: int, target: Variant) -> void:
	leader_id = id
	var actors = RPGSYSTEM.database.actors
	target.text = "%s: %s " % [leader_id, actors[leader_id].name]
