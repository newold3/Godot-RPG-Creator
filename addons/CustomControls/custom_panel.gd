@tool
extends PanelContainer


@export var style1: StyleBox :
	set(value):
		style1 = value
		set("theme_override_styles/panel", style1)

@export var style2: StyleBox :
	set(value):
		style2 = value
		var node = get_node_or_null("%Panel1")
		if node:
			node.set("theme_override_styles/panel", style2)

@export var style3: StyleBox :
	set(value):
		style3 = value
		var node = get_node_or_null("%Panel2")
		if node:
			node.set("theme_override_styles/panel", style3)


func _ready() -> void:
	self.set("theme_override_styles/panel", style1)
	%Panel1.set("theme_override_styles/panel", style2)
	%Panel2.set("theme_override_styles/panel", style3)
	notify_property_list_changed()
