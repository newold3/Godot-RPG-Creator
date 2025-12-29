@tool
extends Window

var data: RPGScope
var original_data: RPGScope


func _ready() -> void:
	close_requested.connect(queue_free)
	set_connections()


func set_connections() -> void:
	# Set Left
	var group = ButtonGroup.new()
	var children = %LeftPanel.get_child(0).get_children()
	var index = 0
	for child in children:
		if child is CheckBox:
			child.button_group = group
			child.toggled.connect(_on_left_toggled.bind(index))
			index += 1
	# Set Mid
	group = ButtonGroup.new()
	children = %MidPanel.get_child(0).get_children()
	index = 0
	for child in children:
		if child is CheckBox:
			child.button_group = group
			child.toggled.connect(_on_mid_toggled.bind(index))
			index += 1
	# Set Right
	group = ButtonGroup.new()
	children = %RightPanel.get_child(0).get_children()
	index = 0
	for child in children:
		if child is CheckBox:
			child.button_group = group
			child.toggled.connect(_on_right_toggled.bind(index))
			index += 1


func set_data(_data: RPGScope) -> void:
	original_data = _data
	data = _data.clone()
	for child in %LeftPanel.get_child(0).get_children():
		if child.name == "CheckBox%s" % (data.faction + 1):
			child.set_pressed(true)
			break
	for child in %MidPanel.get_child(0).get_children():
		if child.name == "CheckBox%s" % (data.number + 1):
			child.set_pressed(true)
			break
	for child in %RightPanel.get_child(0).get_children():
		if child.name == "CheckBox%s" % (data.number + 1):
			child.set_pressed(true)
			break
	%RandomSpinBox.value = data.random
	%RandomSpinBox.set_disabled(data.number != 2)


func _on_left_toggled(toggled_on: bool, id: int) -> void:
	if toggled_on:
		data.faction = id
		if id == 0 or id == 4:
			%MidPanel.propagate_call("set_disabled", [true])
			%RightPanel.propagate_call("set_disabled", [true])
		elif id == 1:
			%MidPanel.propagate_call("set_disabled", [false])
			%RightPanel.propagate_call("set_disabled", [true])
			%RandomSpinBox.set_disabled(data.number != 2)
		elif id == 2:
			%MidPanel.propagate_call("set_disabled", [false])
			%RightPanel.propagate_call("set_disabled", [false])
			%RandomSpinBox.set_disabled(true)
			for child in %MidPanel.get_child(0).get_children():
				if child.name == "CheckBox3":
					child.set_disabled(true)
					break
			if data.number == 2:
				for child in %MidPanel.get_child(0).get_children():
					if child.name == "CheckBox1":
						child.set_pressed(true)
						break
		else:
			%MidPanel.propagate_call("set_disabled", [true])
			%RightPanel.propagate_call("set_disabled", [true])
			for child in %MidPanel.get_child(0).get_children():
				if child.name == "CheckBox2":
					child.set_disabled(false)
					child.set_pressed(true)
					break


func _on_mid_toggled(toggled_on: bool, id: int) -> void:
	if toggled_on:
		data.number = id
		%RandomSpinBox.set_disabled(data.number != 2)


func _on_right_toggled(toggled_on: bool, id: int) -> void:
	if toggled_on:
		data.status = id


func _on_random_spin_box_value_changed(value: float) -> void:
	data.random = value


func _on_ok_button_pressed() -> void:
	original_data.faction = data.faction
	original_data.number = data.number
	original_data.random = data.random
	original_data.status = data.status
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()
