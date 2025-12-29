@tool
class_name LPCEditorDialog
extends Window

var busy: bool = false
var busy_timer: float = 0.0
var confirm_dialog_options: RPGCharacterCreationOptions = RPGCharacterCreationOptions.new()
var void_focus_fuction: bool = false
var focus_counter: int = 0

var palette_dialog: LPCPaletteDialog

@onready var current_position: Vector2i = position


func _ready() -> void:
	RPGMapPlugin.reload_inputs_safely()
	#InputMap.load_from_project_settings()
	
	close_requested.connect(_on_close_requested)
	visibility_changed.connect(_on_visibility_changed)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	window_input.connect(_on_window_input)
	
	%CharacterCreatorMainPanel.saving_container = %SavingContainer
	
	(%AnimationPlayer as AnimationPlayer).play("saving")
	(%AnimatedSprite2D as AnimatedSprite2D).play("default")
	
	
	palette_dialog = %CharacterCreatorMainPanel.palette_dialog
	palette_dialog.hide()
	
	%CharacterCreatorMainPanel.start()
	
	%CharacterCreatorMainPanel.main_dialog = self
	
	%CharacterCreatorMainPanel.remove_child(palette_dialog)
	
	add_child(palette_dialog)


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		try_focus_palette_window()


func _on_close_requested() -> void:
	if RPGDialogFunctions.get_current_dialog() == self:
		hide_me()


func _on_cancel_button_pressed() -> void:
	hide_me()


func _on_ok_button_pressed() -> void:
	hide_me()


func hide_me() -> void:
	if is_inside_tree():
		await get_tree().process_frame
		hide()
	else:
		hide()


func _on_visibility_changed() -> void:
	if visible:
		#%CharacterCreatorMainPanel.try_show_palette_dialog()
		pass
	else:
		%CharacterCreatorMainPanel.try_hide_palette_dialog()
		


func _on_focus_entered() -> void:
	if void_focus_fuction:
		void_focus_fuction = false
		return
	
	try_focus_palette_window()


func try_focus_palette_window() -> void:
	return
	var palette_window: Window = %CharacterCreatorMainPanel.get_palette_window()
	if palette_window.visible:
		var rect = Rect2i(Vector2i(0, -22), palette_window.size + Vector2i(0, 22))
		if rect.has_point(Vector2i(palette_window.get_mouse_position())):
			palette_window.grab_focus()


func _on_focus_exited() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false, get_window_id())


func grab_focus() -> void:
	if DisplayServer.window_get_active_popup() != -1:
		return
		
	var palette_window = %CharacterCreatorMainPanel.get_palette_window()
	if palette_window and is_instance_valid(palette_window) and palette_window.visible:
		var rect = Rect2(
			Vector2(-36, -36),
			palette_window.size + Vector2i(72, 72)
		)
		if rect.has_point(palette_window.get_mouse_position()):
			if not palette_window.has_focus():
				palette_window.grab_focus()
		elif not has_focus():
			super()



func _process(delta: float) -> void:
	if !visible: return
	
	if gui_disable_input:
		set_disable_input(false)
	
	if busy_timer > 0.0:
		busy_timer -= delta
		if busy_timer <= 0:
			busy = false
	
	if position != current_position:
		var diff = Vector2i(position) - Vector2i(current_position)
		%CharacterCreatorMainPanel.get_palette_window().position += diff
		current_position = position


func update_controls() -> void:
	%CharacterCreatorMainPanel.update_controls()


func _input(event: InputEvent) -> void:
	if busy:
		return
	#if visible and has_focus() and event is InputEventMouseMotion:
		#if %CharacterCreatorMainPanel.is_mouse_over_palette_window():
			#%CharacterCreatorMainPanel.get_palette_window().grab_focus()
