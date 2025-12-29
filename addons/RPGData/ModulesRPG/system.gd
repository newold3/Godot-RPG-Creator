@tool
class_name System
extends Resource


func get_class(): return "RPGSystem"


@export var switches: Switches
@export var self_switches: SelfSwitches
@export var variables: Variables
@export var text_variables: TextVariables
@export var initial_map_and_position: Array


func build() -> void:
	switches = Switches.new()
	switches.resize(100)
	variables = Variables.new()
	variables.resize(100)
	text_variables = TextVariables.new()
	text_variables.resize(10)
	self_switches = SelfSwitches.new()
	changed.emit()
