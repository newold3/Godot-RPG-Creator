class_name GuiCoreMainMenuContents
extends MarginContainer

#region ExportsAndVariables
var current_party_buttons_selected: PackedInt32Array = []
var busy: bool = false

signal end()
signal sub_menu_opened()
signal sub_menu_closed()
signal item_menu_requested(id: String)
#endregion

#region VirtualHooks
## Override in themes to return the main buttons menu control
func get_main_menu_items() -> Control:
	if has_node("%MainMenuItems"):
		return %MainMenuItems
	return null


## Override in themes to return the party menu control
func get_party_menu() -> Control:
	if has_node("%PartyMenu"):
		return %PartyMenu
	return null


## Hook for themes to animate container sliding away for sub-menus
func animate_submenu_open(on_complete: Callable) -> void:
	on_complete.call()


## Hook for themes to animate container sliding back in from sub-menus
func animate_submenu_close(on_complete: Callable) -> void:
	on_complete.call()
#endregion

#region Lifecycle
func restart() -> void:
	var party = get_party_menu()
	var items = get_main_menu_items()
	if party and party.has_method("restart"):
		party.restart()
	if items and items.has_method("restart"):
		items.restart()
#endregion

#region PartySelection
func select_party() -> void:
	var items = get_main_menu_items()
	var party = get_party_menu()
	if items and items.has_method("get_button") and "current_button_index" in items:
		var button = items.get_button(items.current_button_index)
		if button and "keep_selected_state" in button:
			button.keep_selected_state = true
	if items and items.has_method("disabled"):
		items.disabled()
	if party and party.has_method("select"):
		party.select()
	GameManager.play_fx("ok")
#endregion

#region FormationAndSubmenus
func _on_main_menu_items_begin_click(id: int) -> void:
	var items = get_main_menu_items()
	var party = get_party_menu()
	if items and "current_button_index" in items and items.current_button_index == 4:
		if not (id in current_party_buttons_selected):
			current_party_buttons_selected.append(id)
			if party and party.has_method("force_selection"):
				party.force_selection(id)
			GameManager.play_fx("ok")
		else:
			current_party_buttons_selected.erase(id)
			if party and party.has_method("clear_force_selection"):
				party.clear_force_selection(id)
			GameManager.play_fx("cancel")
			
		if current_party_buttons_selected.size() == 2:
			busy = true
			if party and party.has_method("change_panels"):
				party.change_panels(current_party_buttons_selected[0], current_party_buttons_selected[1])
			current_party_buttons_selected.clear()
			
			if party and party.has_signal("panels_switched"):
				await party.panels_switched
			
			busy = false


func _on_main_menu_items_finish() -> void:
	var items = get_main_menu_items()
	var party = get_party_menu()
	if items and items.has_method("disabled"):
		items.disabled()
	if party and party.has_method("disabled"):
		party.disabled()
	end.emit()
	if party and party.has_method("end"):
		party.end()


func _show_item_menu(id: String) -> void:
	item_menu_requested.emit(id)
#endregion
