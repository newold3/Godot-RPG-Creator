@tool
extends CommandBaseDialog


var current_animation_id: int = 1
var current_event: RPGEvent


func _ready() -> void:
	super()
	parameter_code = 72


func set_targets(events: Array, append_player: bool = true) -> void:
	var node = %TargetOptions
	node.clear()
	
	if append_player:
		node.add_item("Player")
	
	if current_event:
		node.add_item("This Event")
	
	for event: RPGEvent in events:
		if event.name:
			node.add_item(event.name)
		else:
			node.add_item("Event #%s" % event.id)
	
	if node.get_item_count():
		node.select(0)
	
	node.set_disabled(false)


func set_data() -> void:
	current_animation_id = parameters[0].parameters.get("animation_id", 1)
	var target_id = parameters[0].parameters.get("target_id", 0)
	var wait = parameters[0].parameters.get("wait", false)
	
	%TargetOptions.select(target_id if %TargetOptions.get_item_count() > target_id else 0)
	%Wait.set_pressed(wait)
	fill_animation()


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = super()

	commands[-1].parameters.animation_id = current_animation_id
	commands[-1].parameters.target_id = %TargetOptions.get_selected_id()
	commands[-1].parameters.wait = %Wait.is_pressed()
	
	return commands


func _on_animation_button_pressed() -> void:
	var database = RPGSYSTEM.database
	var path = "res://addons/CustomControls/Dialogs/select_any_data_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.database = database
	dialog.destroy_on_hide = true
	var current_data = database.animations
	var id_selected = current_animation_id
	var title = TranslationManager.tr("Animations")
	dialog.selected.connect(_on_animation_selected, CONNECT_ONE_SHOT)
	dialog.setup(current_data, id_selected, title, null)
	dialog.set_animation_mode()


func _on_animation_selected(id: int, _target: Variant) -> void:
	current_animation_id = id
	fill_animation()


func fill_animation() -> void:
	var database = RPGSYSTEM.database
	
	var node = %AnimationButton

	if database.animations.size() > current_animation_id and current_animation_id > 0:
		var animation_name = "%s: %s" % [current_animation_id, database.animations[current_animation_id].name]
		node.text = animation_name
	elif current_animation_id > 0:
		node.text = "⚠ Invalid Data"
	else:
		node.text = TranslationManager.tr("none")
