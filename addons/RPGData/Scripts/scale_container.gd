@tool
extends Container


## Simple script to scale any control added as a child to fill the full width and height of this control.
func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c is Control:
				var sc = size / c.size
				c.scale = sc
				c.position = Vector2.ZERO
