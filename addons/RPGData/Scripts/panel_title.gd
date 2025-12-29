@tool
extends PanelContainer


@export var text: String = "Title" :
	set(value):
		text = value
		var node = get_node_or_null("%Label")
		if node:
			node.text = text
