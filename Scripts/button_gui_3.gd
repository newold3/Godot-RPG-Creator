@tool
class_name SpecialGuiButton1
extends PanelContainer


## normal texture for the button
@export var button_normal_texture: Texture :
	set(value):
		button_normal_texture = value
		refresh()

## hover texture for the button
@export var button_hover_texture: Texture :
	set(value):
		button_hover_texture = value
		refresh()

## button text
@export var label_text: String :
	set(value):
		label_text = value
		refresh()

## modulate for the background
@export var background_modulate: Color = Color.WHITE :
	set(value):
		background_modulate = value
		refresh()

## modulate for the text
@export var text_modulate: Color = Color.WHITE :
	set(value):
		text_modulate = value
		refresh()

## Apply patch margins to the button
@export_category("Patch Margins")
@export var patch_left: int :
	set(value):
		patch_left = value
		refresh()
@export var patch_right: int :
	set(value):
		patch_right = value
		refresh()
@export var patch_up: int :
	set(value):
		patch_up = value
		refresh()
@export var patch_down: int :
	set(value):
		patch_down = value
		refresh()


signal pressed()


func _ready() -> void:
	refresh()
	mouse_entered.connect(func(): %Background.texture = button_hover_texture)
	mouse_exited.connect(func(): %Background.texture = button_normal_texture)
	focus_entered.connect(func(): %Background.texture = button_hover_texture)
	focus_exited.connect(func(): %Background.texture = button_normal_texture)
	gui_input.connect(_on_gui_input)


func refresh() -> void:
	if is_node_ready():
		%Background.set("patch_margin_left", patch_left)
		%Background.set("patch_margin_top", patch_up)
		%Background.set("patch_margin_right", patch_right)
		%Background.set("patch_margin_bottom", patch_down)
		%Background.modulate = background_modulate
		%Background.texture = button_normal_texture
		%LabelContainer.set("patch_margin_left", patch_left)
		%LabelContainer.set("patch_margin_top", patch_up)
		%LabelContainer.set("patch_margin_right", patch_right)
		%LabelContainer.set("patch_margin_bottom", patch_down)
		%MainLabel.text = label_text
		%MainLabel.set("theme_override_colors/font_color", text_modulate)


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") or event.is_action_pressed("Mouse Left"):
		pressed.emit()
