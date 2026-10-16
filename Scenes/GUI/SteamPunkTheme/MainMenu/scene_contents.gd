extends GuiCoreMainMenuContents

#region ThemeExportsAndNodes
@export var initial_container: Control
@export var help_label: Label

@onready var main_menu_items: Control = %MainMenuItems
@onready var party_menu: Control = %PartyMenu

var VIEWPORT_SAFETY_MARGIN: int = 50
var _original_position: Vector2
#endregion

#region HookOverrides
func get_main_menu_items() -> Control:
	if not main_menu_items and has_node("%MainMenuItems"):
		main_menu_items = %MainMenuItems
	return main_menu_items


func get_party_menu() -> Control:
	if not party_menu and has_node("%PartyMenu"):
		party_menu = %PartyMenu
	return party_menu


var is_closing_animating: bool = false
const SUBMENU_ANIM_DURATION: float = 0.45


func animate_submenu_open(on_complete: Callable = Callable()) -> void:
	if not initial_container:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	_original_position = initial_container.position
	initial_container.modulate.a = 1.0
	var t = create_tween()
	var target_x = initial_container.position.x - initial_container.size.x - VIEWPORT_SAFETY_MARGIN
	t.tween_property(initial_container, "position:x", target_x, SUBMENU_ANIM_DURATION).set_trans(Tween.TRANS_SINE)
	await t.finished
	if on_complete.is_valid():
		on_complete.call()


func animate_submenu_close(on_complete: Callable = Callable()) -> void:
	if not initial_container:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	is_closing_animating = true
	initial_container.position.x = _original_position.x - initial_container.size.x - VIEWPORT_SAFETY_MARGIN
	initial_container.modulate.a = 1.0
	var t = create_tween()
	t.tween_property(initial_container, "position", _original_position, SUBMENU_ANIM_DURATION).set_trans(Tween.TRANS_SINE)
	await t.finished
	is_closing_animating = false
	if on_complete.is_valid():
		on_complete.call()
#endregion
