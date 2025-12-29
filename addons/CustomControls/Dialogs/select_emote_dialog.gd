@tool
extends Window


var current_emote: String
var highlight_filter_match_timer = 0.0

@onready var cursor = %Cursor

signal emote_selected(emote: String)


func _ready() -> void:
	close_requested.connect(queue_free)
	create_emote_buttons()


func _process(delta: float) -> void:
	if highlight_filter_match_timer > 0.0:
		highlight_filter_match_timer -= delta
		if highlight_filter_match_timer <= 0:
			highlight_filter_match_timer = 0
			filter_buttons(%MainContainer, %FilterLineEdit.text.to_lower())


func filter_buttons(node: Control, filter: String) -> void:
	if node is CustomSimpleButton:
		var v = true
		
		if filter:
			var text : String
			if node.has_meta("current_tooltip"):
				text = node.get_meta("current_tooltip").to_lower()
			elif node.tooltip_text.length() > 0:
				text = node.tooltip_text.to_lower()
			if text and text.find(filter) == -1:
				v = false
				
		node.visible = v
	
	for child in node.get_children():
		filter_buttons(child, filter)


func create_emote_buttons() -> void:
	const CUSTOM_BUTTON = preload("res://addons/CustomControls/custom_button.tscn")
	const EMOTES ="res://addons/CustomControls/emotes.json"
	var f = FileAccess.open(EMOTES, FileAccess.READ)
	var json = f.get_as_text()
	f.close()
	var emotes = JSON.parse_string(json)
	var container = %MainContainer
	
	for c in container.get_children():
		c.queue_free()
	
	for key in emotes:
		# Create category title
		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = key.to_upper()
		container.add_child(label)
		# create buttons in this category
		var buttons_container = HFlowContainer.new()
		buttons_container.alignment = FlowContainer.ALIGNMENT_CENTER
		buttons_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(buttons_container)
		for key2 in emotes[key]:
			var emote = emotes[key][key2]
			var b = CUSTOM_BUTTON.instantiate()
			b.text = emote
			b.set("theme_override_font_sizes/font_size", 32)
			b.tooltip_text = "[title]%s[/title]" % key2
			b.pressed.connect(_on_emote_selected.bind(b, emote))
			b.double_click.connect(_on_ok_button_pressed)
			buttons_container.add_child(b)


func _on_emote_selected(button: CustomSimpleButton, emote: String) -> void:
	current_emote = emote
	%OKButton.text = TranslationManager.tr("OK (%s)") % emote
	cursor.reparent(button)
	cursor.size = button.size
	cursor.position = Vector2.ZERO


func _on_ok_button_pressed() -> void:
	if current_emote:
		emote_selected.emit(current_emote)
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_filter_line_edit_text_changed(new_text: String) -> void:
	if new_text.length() != 0:
		%FilterLineEdit.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/filter_reset.png")
	else:
		%FilterLineEdit.right_icon = ResourceLoader.load("res://addons/CustomControls/Images/magnifying_glass.png")
	highlight_filter_match_timer = 0.15


func _on_filter_line_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if %FilterLineEdit.text.length() > 0:
					if event.position.x >= %FilterLineEdit.size.x - 22:
						%FilterLineEdit.text = ""
						_on_filter_line_edit_text_changed("")
	elif event is InputEventMouseMotion:
		if event.position.x >= %FilterLineEdit.size.x - 22:
			%FilterLineEdit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else:
			%FilterLineEdit.mouse_default_cursor_shape = Control.CURSOR_IBEAM
