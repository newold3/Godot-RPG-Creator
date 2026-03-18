@tool
extends InputNumberBase


func _ready() -> void:
	super()


func _update_config() -> void:
	# This scene overrides this method so that the command text settings are
	# not used. Instead, this scene manages its own colors.
	pass
