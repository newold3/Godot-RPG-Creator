@tool
extends PanelContainer

signal tag_removed

const TemplateTagData := preload("res://addons/tile_bit_tools/core/template_tag_data.gd")
const TemplateTag := TemplateTagData.TemplateTag

var tag : TemplateTag

@onready var icon_rect: TextureRect = %IconRect
@onready var label: Label = %Label
@onready var remove_button: Button = %RemoveButton


func _ready() -> void:
	var _err := remove_button.pressed.connect(_on_remove_button_pressed)


func setup(p_tag : TemplateTag, base_control : Control) -> void:
	tag = p_tag

	label.text = tag.text

	icon_rect.texture = tag.get_icon(base_control)

	var stylebox : StyleBoxFlat = base_control.get_theme_stylebox("selected", "ItemList").duplicate(true)
	stylebox.content_margin_left = 6
	stylebox.content_margin_right = 2
	stylebox.content_margin_top = 0
	stylebox.content_margin_bottom = 0
	set("theme_override_styles/panel", stylebox)


	# TODO: implement in future?
#	if tag.color:
#		var stylebox : StyleBoxFlat = get("theme_override_styles/panel")
#		stylebox.bg_color = tag.color


func _on_remove_button_pressed() -> void:
	tag_removed.emit()
	queue_free()
