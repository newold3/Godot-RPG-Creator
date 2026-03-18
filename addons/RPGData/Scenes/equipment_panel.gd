@tool
extends Control

## Wrapper to unify Weapons, Armors, and Sets in a single view.
## It manages visibility and forces data application when switching tabs.

var database: RPGDATA

## Cache to store instances and keep them in the tree.
var panels_instances: Dictionary = {}

## Configure here the paths to your scenes.
var panels_path: Dictionary = {
	0: "uid://hphhu5u2nxnw", # Weapons
	1: "uid://b1xfkgujscdkn", # Armors
	2: "uid://dvw1swl3nfwa4" # Sets/Costumes
}

var current_panel: Control

@onready var main_panel_container: Control = %MainPanelContainer
@onready var panel_selector: OptionButton = %PanelSelected


func _ready() -> void:
	panel_selector.item_selected.connect(_on_panel_selected)
	call_deferred("_on_panel_selected", panel_selector.get_selected_id())


## Modified to ignore the incoming array and use self.database.
func set_data(_data: Array) -> void:
	_refresh_current_panel_data()


func _refresh_current_panel_data() -> void:
	if not current_panel or not database:
		return
	
	current_panel.database = database
	
	var selected_id = panel_selector.get_selected_id()
	
	match selected_id:
		0:
			if current_panel.has_method("set_data"):
				current_panel.set_data(database.weapons)
		1:
			if current_panel.has_method("set_data"):
				current_panel.set_data(database.armors)
		2:
			if current_panel.has_method("set_data"):
				current_panel.set_data(database.costumes)


func _on_panel_selected(index: int) -> void:
	# 1. Force update and hide the current panel.
	if current_panel:
		# CRITICAL: Force the panel to write any pending changes to the database
		# before it becomes invisible.
		current_panel.propagate_call("apply")
		current_panel.hide()
	
	# 2. Check if the panel already exists in memory.
	if panels_instances.has(index):
		current_panel = panels_instances[index]
		current_panel.show()
	else:
		# 3. If it doesn't exist, instantiate it.
		var path = panels_path.get(index)
		
		if path and ResourceLoader.exists(path):
			var ins = load(path).instantiate()
			main_panel_container.add_child(ins)
			ins.set_anchors_preset(Control.PRESET_FULL_RECT)
			
			panels_instances[index] = ins
			current_panel = ins
		else:
			printerr("EquipmentWrapper: Scene not found for index ", index)
			return
	
	# 4. Refresh data for the newly shown panel.
	_refresh_current_panel_data()


## Called from MainDatabasePanel when saving the whole DB.
func apply() -> void:
	# We still propagate call here to ensure even the visible panel saves 
	# if the user hits "Save" without changing tabs.
	if current_panel:
		current_panel.propagate_call("apply")
