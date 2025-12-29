@tool
extends Panel


## Text Displayed in the label.
@export var current_title: String = "" :
	set(value):
		current_title = value
		var node = get_node_or_null("%DialogTitle")
		if node:
			node.text = value.to_upper()


@export_category("textures")

## Mask For this label
@export var mask: StyleBox:
	set(value):
		mask = value
		set("theme_override_styles/panel", mask)


## Filler style for this label
@export var fill: StyleBox:
	set(value):
		fill = value
		var node = get_node_or_null("Panel")
		if node:
			node.set("theme_override_styles/panel", fill)

## Border style for this label
@export var border: StyleBox:
	set(value):
		border = value
		var node = get_node_or_null("Panel2")
		if node:
			node.set("theme_override_styles/panel", border)


func set_title(title: String) -> void:
	current_title = title
	
