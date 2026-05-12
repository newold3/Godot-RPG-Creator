@tool
extends EditorPlugin


#region VARIABLES
var toolbar_btn: Button
var custom_popup: PopupPanel
var main_panel: PanelContainer
var content_vbox: VBoxContainer

## Specify the exact order here. Buttons not included in this array will be listed below in alphabetical order.
var priority_order: Array[String] = [
	"DatabaseButton", 
	"CharacterCreatorButton",
	"MapGeneratorButton",
	"RPGSceneManagerButton",
	"ScenePreviewButton"
]
#endregion



func _enter_tree() -> void:
	toolbar_btn = Button.new()
	toolbar_btn.name = "RPGCreatorTools"
	toolbar_btn.text = "RPG Creator Tools"
	toolbar_btn.icon = preload("uid://diqbqkdds7bkm")
	toolbar_btn.pressed.connect(_on_toolbar_pressed)
	toolbar_btn.theme = load("res://addons/CustomControls/Resources/Themes/editor_buitton_themes.tres")
	toolbar_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toolbar_btn.tooltip_text = tr("List of tools available for Godot RPG Maker")
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar_btn)
	
	custom_popup = PopupPanel.new()
	custom_popup.wrap_controls = true
	
	main_panel = PanelContainer.new()
	
	var default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	default_style.set_corner_radius_all(4)
	main_panel.add_theme_stylebox_override("panel", default_style)
	
	content_vbox = VBoxContainer.new()
	
	main_panel.add_child(content_vbox)
	custom_popup.add_child(main_panel)
	
	EditorInterface.get_base_control().add_child(custom_popup)
	
	RPGMenuAPI.attach_menu(custom_popup, main_panel, content_vbox)
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom(toolbar_btn)



func _exit_tree() -> void:
	RPGMenuAPI.detach_menu()
	
	if is_instance_valid(toolbar_btn):
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, toolbar_btn)
		toolbar_btn.queue_free()
		
	if is_instance_valid(custom_popup):
		custom_popup.queue_free()



## Calculates the position on the screen and displays our custom menu.
func _on_toolbar_pressed() -> void:
	_sort_menu_items()
	
	var rect: Rect2 = toolbar_btn.get_global_rect()
	
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(custom_popup)
	custom_popup.popup(Rect2i(rect.position.x, rect.end.y + 26, 0, 0))



## Reorder the children of the VBoxContainer just before displaying the menu.
func _sort_menu_items() -> void:
	if not is_instance_valid(content_vbox): return
	
	var children: Array[Node] = content_vbox.get_children()
	if children.is_empty(): return
	
	children.sort_custom(_compare_buttons)
	
	for i in range(children.size()):
		content_vbox.move_child(children[i], i)



## Custom evaluation function. Returns true if ‘a’ must come before 'b'.
func _compare_buttons(a: Node, b: Node) -> bool:
	var name_a: String = a.name
	var name_b: String = b.name
	
	var idx_a: int = priority_order.find(name_a)
	var idx_b: int = priority_order.find(name_b)
	
	if idx_a == -1: idx_a = 99999
	if idx_b == -1: idx_b = 99999
	
	if idx_a != idx_b:
		return idx_a < idx_b
		
	return name_a.nocasecmp_to(name_b) < 0
