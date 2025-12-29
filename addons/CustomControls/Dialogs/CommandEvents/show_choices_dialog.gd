@tool
extends CommandBaseDialog


var insert_commands: Dictionary

var current_scene_path: String = ""
var current_cursor_move_fx: Dictionary = {}
var current_selection_fx: Dictionary = {}
var current_cancel_fx: Dictionary = {}
var current_config: Dictionary = {}

const CHOICE_PANEL = preload("res://addons/CustomControls/choice_panel.tscn")


func _ready() -> void:
	super()
	parameter_code = 4


func set_data() -> void:
	var config = parameters[0].parameters
	var choices = PackedStringArray([])
	insert_commands = {}
	var i = -1
	for j in range(1, parameters.size()):
		var current_command = parameters[j]
		if current_command.code == 5 and current_command.indent == parameters[0].indent: # When
			choices.append(current_command.parameters.name)
			i += 1
			insert_commands[i] = []
		elif current_command.code == 6 and current_command.indent == parameters[0].indent: # Cancel
			i = "cancel"
			insert_commands[i] = []
		elif current_command.code != 7 or (current_command.code == 7 and current_command.indent != parameters[0].indent):
			insert_commands[i].append(current_command)
	
	var panel = %ChoiceContainer
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
		
	var default_choices = 8
	var count = choices.size() if choices.size() >= default_choices else default_choices

	for j in count:
		var choice_panel = CHOICE_PANEL.instantiate()
		if choices.size() > j:
			choice_panel.set_choice_name(choices[j])
		elif j == 0:
			choice_panel.set_choice_name("Yes")
		elif j == 1:
			choice_panel.set_choice_name("No")
		else:
			choice_panel.set_choice_name("")
			
		choice_panel.delete_requested.connect(_on_choice_panel_delete_requested)
		panel.add_child(choice_panel)
	
		if j < count - 1:
			choice_panel.disable_remove_button(true)
	
	# Set Config
	if !"scene_path" in config:
		current_scene_path = "res://Scenes/DialogTemplates/choice_scene_1.tscn"
	else:
		current_scene_path = config.get("scene_path", "")
	if !"move_fx" in config:
		current_cursor_move_fx = {"path": "res://Assets/Sounds/SE/button_hover_se.wav", "volume": 0, "pitch": 1}
	else:
		current_cursor_move_fx = config.get("move_fx", {})
	if !"select_fx" in config:
		current_selection_fx = {"path": "res://Assets/Sounds/SE/button_click_se.wav", "volume": 0, "pitch": 1}
	else:
		current_selection_fx = config.get("select_fx", {})
	if !"cancel_fx" in config:
		current_cancel_fx = {"path": "res://Assets/Sounds/SE/cancel1.ogg", "volume": 0, "pitch": 1}
	else:
		current_cancel_fx = config.get("cancel_fx", {})
	
	current_config = config.get("text_format", {})


	%UseMessageBounds.set_pressed(config.get("use_message_bounds", true))
	%Position.select(max(0, min(%Position.get_item_count(), config.get("position", 5))))
	update_default_items(config.get("default", 1))
	update_cancel_items(config.get("cancel", 1))
	%MaxChoices.value = config.get("max_choices", 4)
	%PreviousChoice.text = config.get("previous", "Previous")
	%NextChoice.text = config.get("next", "Next")
	%ScenePath.text = current_scene_path.get_file()
	%CursorMoveFx.text = current_cursor_move_fx.get("path", tr("Select FX")).get_file()
	%SelectionFx.text = current_selection_fx.get("path", tr("Select FX")).get_file()
	%CancelFx.text = current_cancel_fx.get("path", tr("Select FX")).get_file()
	var box_offset = config.get("offset", Vector2.ZERO)
	%OffsetX.value = box_offset.x
	%OffsetY.value = box_offset.y
	%CancelChoice.select(max(0, min(%CancelChoice.get_item_count(), config.get("cancel", 1))))
	%DefaultChoice.select(max(0, min(%DefaultChoice.get_item_count(), config.get("default", 1))))


func update_default_items(item_selected: int = -1) -> void:
	var node = %DefaultChoice
	var container = %ChoiceContainer
	node.clear()
	
	node.add_item("none")
	for i in container.get_child_count():
		node.add_item("#%s" % (i+1))
	
	if node.get_item_count() > item_selected and item_selected != -1:
		node.select(item_selected)
	else:
		node.select(0)


func update_cancel_items(item_selected: int = -1) -> void:
	var node = %CancelChoice
	var container = %ChoiceContainer
	node.clear()
	
	node.add_item("Branch")
	node.add_item("Disallow")
	for i in container.get_child_count():
		node.add_item("#%s" % (i+1))
	
	if node.get_item_count() > item_selected and item_selected != -1:
		node.select(item_selected)
	else:
		node.select(0)


func _on_choice_panel_delete_requested(choice_panel: ChoicePanel) -> void:
	var panel = %ChoiceContainer
	panel.remove_child(choice_panel)
	choice_panel.queue_free()
	for child in panel.get_children():
		child.update_id()
	size.y = 0
	%Choices.size.y = 0
	var id = %CancelChoice.get_selected_id()
	if id >= panel.get_child_count() + 1:
		id = max(id - 1, 0)
	update_cancel_items(id)
	id = %DefaultChoice.get_selected_id()
	if id >= panel.get_child_count() + 1:
		id = max(id - 1, 0)
	update_default_items(id)


func build_command_list() -> Array[RPGEventCommand]:
	var commands: Array[RPGEventCommand] = []
	
	var config = {
		"scene_path": current_scene_path,
		"position": %Position.get_selected_id(),
		"default": %DefaultChoice.get_selected_id(),
		"cancel": %CancelChoice.get_selected_id(),
		"max_choices": %MaxChoices.value,
		"previous": %PreviousChoice.text,
		"next": %NextChoice.text,
		"move_fx": current_cursor_move_fx,
		"select_fx": current_selection_fx,
		"cancel_fx": current_cancel_fx,
		"use_message_bounds": %UseMessageBounds.is_pressed(),
		"offset": Vector2(%OffsetX.value, %OffsetY.value),
		"text_format": current_config
	}

	var choice_panels = %ChoiceContainer.get_children()
	var choices: PackedStringArray = []
	var force_add_choice: bool = false
	for i in range(choice_panels.size() -1, -1, -1):
		if force_add_choice:
			choices.append(choice_panels[i].get_choice_name().strip_edges())
		else:
			var choice_name = choice_panels[i].get_choice_name().strip_edges()
			if choice_name:
				choices.append(choice_name)
				force_add_choice = true
	
	var current_indent = parameters[0].indent
	
	# Choice End command
	var command = RPGEventCommand.new()
	command.code = 7
	command.indent = current_indent
	commands.append(command)
	# Choice Cancel command
	if config.cancel == 0: # using Cancel
		# First insert all commands found in cancel (in reverse) or command 0
		var index = "cancel"
		var extra_commands = insert_commands.get(index, [])
		if extra_commands.size() > 0:
			for i in range(extra_commands.size() - 1, -1, -1):
				command = extra_commands[i]
				commands.append(command)
		else:
			# Insert command 0
			command = RPGEventCommand.new()
			command.code = 0
			command.indent = current_indent + 1
			commands.append(command)
		# Next Create Cancel command
		command = RPGEventCommand.new()
		command.code = 6
		command.indent = current_indent
		commands.append(command)
	# Choice When commands
	for i in choices.size():
		# First insert all commands found in insert_commands at index i (in reverse) or command 0
		var extra_commands = insert_commands.get(choices.size() - i - 1, [])
		if extra_commands.size() > 0:
			for j in range(extra_commands.size() -1, -1, -1):
				command = extra_commands[j]
				commands.append(command)
		else:
			# Insert command 0
			command = RPGEventCommand.new()
			command.code = 0
			command.indent = current_indent + 1
			commands.append(command)
		# Then insert Choice When command
		command = RPGEventCommand.new()
		command.code = 5
		command.indent = current_indent
		command.parameters.name = choices[i]
		commands.append(command)
	# Last insert Choice command
	var main_command = super()
	main_command[-1].parameters = config
	commands.append(main_command[-1])
	
	return commands


func _on_choices_item_rect_changed() -> void:
	if %Choices.size.y < %Choices.get_parent().size.y:
		%Choices.size.y = %Choices.get_parent().size.y

	if size.y < %Choices.size.y + 30:
		size.y = %Choices.size.y + 32
		wrap_controls = true
		wrap_controls = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()


func _on_add_choice_pressed() -> void:
	var panel = %ChoiceContainer
	for child in panel.get_children():
		child.disable_remove_button(true)
	var choice_panel = CHOICE_PANEL.instantiate()
	choice_panel.set_choice_name("")
	choice_panel.disable_remove_button(false)
	choice_panel.delete_requested.connect(_on_choice_panel_delete_requested)
	panel.add_child(choice_panel)
	choice_panel.select()
	update_cancel_items(%CancelChoice.get_selected_id())
	update_default_items(%DefaultChoice.get_selected_id())
	await get_tree().process_frame
	%ChoiceScrollContainer.get_v_scroll_bar().value = %ChoiceScrollContainer.get_v_scroll_bar().max_value


func select_sound(target: Node, id: String) -> void:
	var path = "res://addons/CustomControls/Dialogs/select_sound_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	var parameters :Array[RPGEventCommand] = []
	var param = RPGEventCommand.new(0, 0, get(id))
	parameters.append(param)
	dialog.set_parameters(parameters)
	dialog.set_data()

	dialog.command_changed.connect(
		func(commands: Array[RPGEventCommand]):
			var c = commands[0].parameters
			set(id, {"path": c.get("path", ""), "volume": c.get("volume", ""), "pitch": c.get("pitch", "")})
			target.text = get(id).get("path", "").get_file()
	)


func _on_cursor_move_fx_middle_click_pressed() -> void:
	%CursorMoveFx.text = tr("Select FX")
	current_cursor_move_fx = {}


func _on_cursor_move_fx_pressed() -> void:
	select_sound(%CursorMoveFx, "current_cursor_move_fx")


func _on_selection_fx_middle_click_pressed() -> void:
	%SelectionFx.text = tr("Select FX")
	current_selection_fx = {}


func _on_selection_fx_pressed() -> void:
	select_sound(%SelectionFx, "current_selection_fx")


func _on_cancel_fx_middle_click_pressed() -> void:
	%CancelFx.text = tr("Select FX")
	current_cancel_fx = {}


func _on_cancel_fx_pressed() -> void:
	select_sound(%CancelFx, "current_cancel_fx")


func _on_scene_path_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/select_file_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	await get_tree().process_frame
	
	dialog.destroy_on_hide = true
	
	dialog.set_dialog_mode(0)
	
	dialog.target_callable = func(path: String):
		current_scene_path = path
		%ScenePath.text = current_scene_path.get_file()
		
	dialog.set_file_selected(current_scene_path)
	
	dialog.fill_files("choice_scenes")


func _on_text_format_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/config_options_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	
	dialog.set_data(current_config)
	
	dialog.config_changed.connect(func(config: Dictionary) : current_config = config)
