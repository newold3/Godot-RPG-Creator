@tool
class_name SimpleFocusableControl
extends Resource


## The focusable Control this resource points to
@export var control: NodePath
## Help text associated with this resource
@export var tooltip: String = ""
## Hand cursor style when selecting this node
@export_enum("left", "right", "up", "down") var cursor_position: int = 0
