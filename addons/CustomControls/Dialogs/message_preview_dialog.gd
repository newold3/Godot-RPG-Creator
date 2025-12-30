@tool
extends Window


var original_text: String = ""
var is_setted: bool = false
var new_size: Vector2
var initial_config: Dictionary = {}

var old_text: String
var old_config: String

var main_dialog


func _ready() -> void:
	main_dialog = %Dialog
	main_dialog.is_editor_prevew = true
	close_requested.connect(queue_free, CONNECT_DEFERRED)
	main_dialog.all_messages_finished.connect(_repeat_message)
	focus_entered.connect(
		func():
			if main_dialog:
				main_dialog.set_process_input(true)
				main_dialog.can_play_sound = true
				main_dialog.busy_when_preview = false
	)
	focus_exited.connect(
		func():
			if main_dialog:
				main_dialog.set_process_input(false)
				main_dialog.can_play_sound = false
				main_dialog.busy_when_preview = true
	)
	
	%Timer.start()
	#always_on_top = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()


func _repeat_message() -> void:
	set_text(original_text, initial_config, true)


func set_text(test_message: String, config: Dictionary, force: bool = false) -> void:
	if !force and test_message == old_text and old_config == str(config):
		return
	old_text = test_message
	old_config = str(config)
	if !is_setted:
		main_dialog.setup()
		is_setted = true
		await get_tree().process_frame
	
	#await get_tree().process_frame
	main_dialog.reset()
	main_dialog.set_initial_config(config)
	main_dialog.call_deferred("setup_text", test_message)
	original_text = test_message
	initial_config = config


func set_main_config(config: Dictionary) -> void:
	var scene_path = config.get("scene_path", "res://Scenes/DialogTemplates/base_dialog.tscn")
	if scene_path != main_dialog.get_scene_file_path() and ResourceLoader.exists(scene_path):
		var old_node = main_dialog
		old_node.disconnect("all_messages_finished", _repeat_message)
		var dialog_parent = old_node.get_parent()
		dialog_parent.remove_child(old_node)
		old_node.queue_free()
		var new_node: DialogBase = load(scene_path).instantiate()
		dialog_parent.add_child(new_node)
		new_node.name = "Dialog"
		new_node.set_unique_name_in_owner(true)
		main_dialog = new_node
		main_dialog.all_messages_finished.connect(_repeat_message)
		is_setted = false
			
	main_dialog.set_message_config(config)


func _on_ok_button_pressed() -> void:
	queue_free()


func _on_timer_timeout() -> void:
	pass
	#if %Dialog.size + Vector2(80, 80) > Vector2(size):
		#size = %Dialog.size + Vector2(80, 80)
	#if new_size and (size.x < new_size.x or size.y < new_size.y):
		#size = Vector2(max(size.x, new_size.x), max(size.y, new_size.y))
		##wrap_controls = true
		##wrap_controls = false


func _on_margin_container_item_rect_changed() -> void:
	new_size = $MarginContainer.size


func _on_size_changed() -> void:
	var node = get_node_or_null("%Dialog")
	if node and is_instance_valid(node):
		node._on_message_item_rect_changed()


func _on_dialog_message_started() -> void:
	pass
	#size = Vector2i.ONE
