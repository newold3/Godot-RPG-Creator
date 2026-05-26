@tool
extends LPCCharacter

func get_class() -> String: return "EmptyPlayableCharacter"
func get_custom_class() -> String: return "EmptyPlayableCharacter"


func _ready() -> void:
	super()
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	is_invalid_event = true
