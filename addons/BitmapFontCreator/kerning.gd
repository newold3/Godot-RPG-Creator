@tool
extends PanelContainer


@onready var preview_label: Label = %PreviewLabel
@onready var kerning: SpinBox = %kerning
@onready var close_button: TextureButton = %RemoveButton


signal remove_requested(index: int)
signal kerning_updated(index: int, kerning: int)


func _ready() -> void:
	close_button.pressed.connect(
		func():
			remove_requested.emit(get_index())
	)
	kerning.value_changed.connect(
		func(value: float):
			kerning_updated.emit(get_index(), int(value))
	)
	CustomTooltipManager.plugin_replace_all_tooltips_with_custom.call_deferred(self)


func update_text(current_letter: String, pair_letter: String, font: Font) -> void:
	preview_label.add_theme_font_override("font", font)
	preview_label.text = current_letter + pair_letter
