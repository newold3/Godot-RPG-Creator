@tool
extends HSlider


# exported nodes do not work in tool mode
#@onready var current_bit_data_draw: Control = %CurrentBitDataDraw
#@onready var preview_bit_data_draw: Control = %PreviewBitDataDraw
#
#
#
#func _ready() -> void:
#	value_changed.connect(_on_value_changed)
#	_update()
#
#
#func _update() -> void:
#	_update_draw_layer_opacity(current_bit_data_draw)
#	_update_draw_layer_opacity(preview_bit_data_draw)
#
#
#func _update_draw_layer_opacity(control : Control) -> void:
#	control.modulate.a = value
#	control.get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
#
#func _on_value_changed(value : float) -> void:
#	_update()
