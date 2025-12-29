@tool
extends Window

var need_refresh_timer: float
var new_command: String
var old_command: String
var new_size: Vector2i

var learn_variable_value: int = 1

static var cache: Dictionary


signal command_selected(command: String, args: String)


func _ready() -> void:
	if !cache:
		cache = {}

	close_requested.connect(queue_free)
	%TestRich.custom_effects.clear()
	%TestRich.install_effect(RichTextGhost.new())
	%TestRich.install_effect(RichTextColorMod.new())
	%TestRich.install_effect(RichTextCuss.new())
	%TestRich.install_effect(RichTextHeart.new())
	%TestRich.install_effect(RichTextJump.new())
	%TestRich.install_effect(RichTextL33T.new())
	%TestRich.install_effect(RichTextNervous.new())
	%TestRich.install_effect(RichTextNumber.new())
	%TestRich.install_effect(RichTextRain.new())
	%TestRich.install_effect(RichTextSparkle.new())
	%TestRich.install_effect(RichTextUwU.new())
	%TestRich.install_effect(RichTextWoo.new())
	%TestRich.install_effect(RichTextLanguageLearning.new())
	connect_all(self)
	var b = ButtonGroup.new()
	%LearnExactValueCheckBox.button_group = b
	%LearnVariableValueCheckBox.button_group = b
	%EffectSelection.item_selected.emit(%EffectSelection.get_selected_id())
	await get_tree().process_frame
	size.y = min_size.y


func connect_all(node: Node) -> void:
	if node == %EffectSelection:
		return
	if node.has_signal("item_selected"):
		node.item_selected.connect(_refresh_preview)
	elif node.has_signal("value_changed"):
		node.value_changed.connect(_refresh_preview)
	elif node.has_signal("color_changed"):
		node.color_changed.connect(_refresh_preview)
	elif node.has_signal("toggled"):
		node.toggled.connect(_refresh_preview)
	
	for child in node.get_children():
		connect_all(child)


func set_data(index: int, args: Array) -> void:
	set_initial_values()
	if index == -1:
		index = cache.get("effect_id", 0)
		var args_id = "args%s" % index
		args = cache.get(args_id, [1, Color.RED, 2])
	index = clamp(index, 0, %EffectSelection.get_item_count() - 1)
	%EffectSelection.select(index)
	%EffectSelection.item_selected.emit(index)
	size.y = min_size.y
	if !args: return
	
	match index:
		0: 
			%PulseFrequency.value = args[0]
			%PulseColor.set_pick_color(args[1])
			%PulseEase.value = args[2]
		1: 
			%WaveAmplitude.value = args[0]
			%WaveFrequency.value = args[1]
			var id = clamp(args[2], 0, %WaveConnected.get_item_count() - 1)
			%WaveConnected.select(id)
		2: 
			%TornadoRadius.value = args[0]
			%TornadoFrequency.value = args[1]
			var id = clamp(args[2], 0, %TornadoConnected.get_item_count() - 1)
			%TornadoConnected.select(id)
		3: 
			%ShakeRate.value = args[0]
			%ShakeLevel.value = args[1]
			var id = clamp(args[2], 0, %ShakeConnected.get_item_count() - 1)
			%ShakeConnected.select(id)
		4: 
			%FadeStart.value = args[0]
			%FadeLength.value = args[1]
		5: 
			%RainbowSaturation.value = args[0]
			%RainbowFrequency.value = args[1]
			%RainbowValue.value = args[2]
		6:
			%GhostFrecuency.value = args[0]
			%GhostSpan.value = args[1]
		7:
			%ColorModColor.set_pick_color(args[0])
		8:
			pass
		9:
			%HeartScale.value = args[0]
			%HeartFrequency.value = args[1]
		10:
			%JumpAngle.value = args[0]
		11:
			pass
		12:
			%NervousScale.value = args[0]
			%NervousFrequency.value = args[1]
		13:
			%NumberColor.set_pick_color(args[0])
		14:
			pass
		15:
			%SparkleFrequency.value = args[0]
			%SparkleColor1.set_pick_color(args[1])
			%SparkleColor2.set_pick_color(args[2])
			%SparkleColor3.set_pick_color(args[3])
		16:
			pass
		17:
			%WooScale.value = args[0]
			%WooFrequency.value = args[1]
		18:
			%LearnExactValue.value = args[0]
			if args[1] == 0:
				%LearnExactValueCheckBox.set_pressed(true)
			else:
				%LearnVariableValueCheckBox.set_pressed(true)
			learn_variable_value = args[2]
			_update_learn_variable_id()
			
	
	old_command = "%s-%s" % [index, args]
	await get_tree().process_frame
	size.y = min_size.y


func set_initial_values() -> void:
	for index in range(0, 19, 1):
		var args_id = "args%s" % index
		match index:
			0: 
				var args = cache.get(args_id, [1, Color.RED, 2])
				%PulseFrequency.value = args[0]
				%PulseColor.set_pick_color(args[1])
				%PulseEase.value = args[2]
			1: 
				var args = cache.get(args_id, [50, 5, 0])
				%WaveAmplitude.value = args[0]
				%WaveFrequency.value = args[1]
				var id = clamp(args[2], 0, %WaveConnected.get_item_count() - 1)
				%WaveConnected.select(id)
			2: 
				var args = cache.get(args_id, [10, 1, 0])
				%TornadoRadius.value = args[0]
				%TornadoFrequency.value = args[1]
				var id = clamp(args[2], 0, %TornadoConnected.get_item_count() - 1)
				%TornadoConnected.select(id)
			3: 
				var args = cache.get(args_id, [20, 5, 0])
				%ShakeRate.value = args[0]
				%ShakeLevel.value = args[1]
				var id = clamp(args[2], 0, %ShakeConnected.get_item_count() - 1)
				%ShakeConnected.select(id)
			4: 
				var args = cache.get(args_id, [0.01, 14.01])
				%FadeStart.value = args[0]
				%FadeLength.value = args[1]
			5: 
				var args = cache.get(args_id, [0.8, 1, 0.8])
				%RainbowSaturation.value = args[0]
				%RainbowFrequency.value = args[1]
				%RainbowValue.value = args[2]
			6:
				var args = cache.get(args_id, [5, 10])
				%GhostFrecuency.value = args[0]
				%GhostSpan.value = args[1]
			7:
				var args = cache.get(args_id, [Color("#1ce2d9")])
				%ColorModColor.set_pick_color(args[0])
			8:
				pass
			9:
				var args = cache.get(args_id, [16, 2])
				%HeartScale.value = args[0]
				%HeartFrequency.value = args[1]
			10:
				var args = cache.get(args_id, [3.14])
				%JumpAngle.value = args[0]
			11:
				pass
			12:
				var args = cache.get(args_id, [1, 8])
				%NervousScale.value = args[0]
				%NervousFrequency.value = args[1]
			13:
				var args = cache.get(args_id, [Color("#57f40f")])
				%NumberColor.set_pick_color(args[0])
			14:
				pass
			15:
				var args = cache.get(args_id, [2, Color("#ff0000"), Color("#3eff00"), Color("#002eff")])
				%SparkleFrequency.value = args[0]
				%SparkleColor1.set_pick_color(args[1])
				%SparkleColor2.set_pick_color(args[2])
				%SparkleColor3.set_pick_color(args[3])
			16:
				pass
			17:
				var args = cache.get(args_id, [1, 8])
				%WooScale.value = args[0]
				%WooFrequency.value = args[1]
			18:
				var args = cache.get(args_id, [1.0, 0, 1])
				%LearnExactValue.value = args[0]
				if int(args[1]) == 0:
					%LearnExactValueCheckBox.set_pressed(true)
				else:
					%LearnVariableValueCheckBox.set_pressed(true)
				learn_variable_value = args[2]
				_update_learn_variable_id()
				


func get_bbcode() -> Array:
	var bbcode: Array = []
	var args: String
	var args_array: Array = []
	var index = %EffectSelection.get_selected_id()
	
	var code = ["pulse", "wave", "tornado", "shake", "fade", "rainbow", "ghost", "colormod", "cuss", "heart", "jump", "l33t", "nervous", "number", "rain", "sparkle", "uwu", "woo", "learn"][index]
	
	match index:
		0: 
			var a = %PulseFrequency.value
			var b = %PulseColor.get_pick_color().to_html()
			var c = %PulseEase.value
			args_array = [a, b, c]
			args = "freq=%s color=#%s ease=%s" % [a, b, c]
			new_command = "%s-%s" % [index, [a, %PulseColor.get_pick_color(), c]]
		1: 
			var a = %WaveAmplitude.value
			var b = %WaveFrequency.value
			var c = %WaveConnected.get_selected_id()
			args_array = [a, b, c]
			args = "amp=%s freq=%s connected=%s" % [a, b, c]
			new_command = "%s-%s" % [index, [a, b, c]]
		2: 
			var a = %TornadoRadius.value
			var b = %TornadoFrequency.value
			var c = %TornadoConnected.get_selected_id()
			args_array = [a, b, c]
			args = "radius=%s freq=%s connected=%s" % [a, b, c]
			new_command = "%s-%s" % [index, [a, b, c]]
		3: 
			var a = %ShakeRate.value
			var b = %ShakeLevel.value
			var c = %ShakeConnected.get_selected_id()
			args_array = [a, b, c]
			args = "rate=%s level=%s connected=%s" % [a, b, c]
			new_command = "%s-%s" % [index, [a, b, c]]
		4: 
			var a = %FadeStart.value
			var b = %FadeLength.value
			args_array = [a, b]
			args = "start=%s length=%s" % [a, b]
			new_command = "%s-%s" % [index, [a, b]]
		5: 
			var a = %RainbowSaturation.value
			var b = %RainbowFrequency.value
			var c = %RainbowValue.value
			args_array = [a, b, c]
			args = "freq=%s sat=%s val=%s" % [a, b, c]
			new_command = "%s-%s" % [index, [a, b, c]]
		6:
			var a = %GhostFrecuency.value
			var b = %GhostSpan.value
			args_array = [a, b]
			args = "freq=%s span=%s" % [a, b]
			new_command = "%s-%s" % [index, [a, b]]
		7:
			var a = %ColorModColor.get_pick_color().to_html()
			args_array = [a]
			args = "color=#%s" % [a]
			new_command = "%s-%s" % [index, [%ColorModColor.get_pick_color()]]
		8:
			args = ""
		9:
			var a = %HeartScale.value
			var b = %HeartFrequency.value
			args_array = [a, b]
			args = "scale=%s freq=%s" % [a, b]
			new_command = "%s-%s" % [index, [a, b]]
		10:
			var a = round(%JumpAngle.value * 100) / 100.0
			args_array = [a]
			args = "angle=%s" % [a]
			new_command = "%s-%s" % [index, [%JumpAngle.value]]
		11:
			args = ""
		12:
			var a = %NervousScale.value
			var b = %NervousFrequency.value
			args_array = [a, b]
			args = "scale=%s freq=%s" % [a, b]
			new_command = "%s-%s" % [index, [a, b]]
		13:
			var a = %NumberColor.get_pick_color().to_html()
			args_array = [a]
			args = "color=#%s" % [a]
		14:
			args = ""
		15:
			var a = %SparkleFrequency.value
			var b = %SparkleColor1.get_pick_color().to_html()
			var c = %SparkleColor2.get_pick_color().to_html()
			var d = %SparkleColor3.get_pick_color().to_html()
			args_array = [a, b, c, d]
			args = "freq=%s c1=#%s c2=#%s c3=#%s" % [a, b, c, d]
			new_command = "%s-%s" % [index, [a, %SparkleColor1.get_pick_color(), %SparkleColor2.get_pick_color(), %SparkleColor3.get_pick_color()]]
		16:
			args = ""
		17:
			var a = %WooScale.value
			var b = %WooFrequency.value
			args_array = [a, b]
			args = "scale=%s freq=%s" % [a, b]
			new_command = "%s-%s" % [index, [a, b]]
		18:
			var a = %LearnExactValue.value
			var b = 1 if %LearnVariableValueCheckBox.is_pressed() else 0
			var c = learn_variable_value
			args_array = [a, b, c]
			args = "progress=%s use_var=%s var=%s" % [a, b, c]
			new_command = "%s-%s" % [index, [a, b]]
			
	
	bbcode = [code, args, args_array]
	return bbcode


func _on_ok_button_pressed() -> void:
	propagate_call("apply")
	var command = get_bbcode()
	command_selected.emit(command[0], command[1])
	cache.effect_id = %EffectSelection.get_selected_id()
	var args_id = "args%s" % cache.effect_id
	cache[args_id] = command[2]
	queue_free()


func _on_cancel_button_pressed() -> void:
	queue_free()


func _refresh_preview(_value: Variant) -> void:
	need_refresh_timer = 0.15


func _process(delta: float) -> void:
	if need_refresh_timer > 0:
		need_refresh_timer -= delta
		
		if need_refresh_timer <= 0:
			need_refresh_timer = 0
			var index = %EffectSelection.get_selected_id()
			_on_effect_selection_item_selected(index, false)


func _set_node_visibility(node: Node, value: bool) -> void:
	if not (node is PopupPanel or node is PopupMenu or node is Timer) and "visible" in node:
		node.visible = value
	
	for c in node.get_children():
		_set_node_visibility(c, value)


func _on_effect_selection_item_selected(index: int, change_visibility: bool = true, force_size: bool = false) -> void:
	if change_visibility:
		_set_node_visibility(%EffectContainer, false)
		%EffectContainer.visible = true
		%ParametersTitle.visible = true
	var test_bbcode: String
	var base: String = %PreviewText.text
	match index:
		0: 
			if change_visibility:
				_set_node_visibility(%Pulse, true)
			var a = %PulseFrequency.value
			var b = %PulseColor.get_pick_color().to_html()
			var c = %PulseEase.value
			test_bbcode = "[pulse freq=%s color=#%s ease=%s]%s[/pulse]" % [a, b, c, base]
			%Description.text = TranslationManager.tr("Pulse creates an animated pulsing effect that multiplies each character's opacity and color. It can be used to bring attention to specific text.")
		1: 
			if change_visibility:
				_set_node_visibility(%Wave, true)
			var a = %WaveAmplitude.value
			var b = %WaveFrequency.value
			var c = %WaveConnected.get_selected_id()
			test_bbcode = "[wave amp=%s freq=%s connected=%s]%s[/wave]" % [a, b, c, base]
			%Description.text = TranslationManager.tr("Wave makes the text go up and down.")
		2: 
			if change_visibility:
				_set_node_visibility(%Tornado, true)
			var a = %TornadoRadius.value
			var b = %TornadoFrequency.value
			var c = %TornadoConnected.get_selected_id()
			test_bbcode = "[tornado radius=%s freq=%s connected=%s]%s[/tornado]" % [a, b, c, base]
			%Description.text = TranslationManager.tr("Tornado makes the text move around in a circle.")
		3: 
			if change_visibility:
				_set_node_visibility(%Shake, true)
			var a = %ShakeRate.value
			var b = %ShakeLevel.value
			var c = %ShakeConnected.get_selected_id()
			test_bbcode = "[shake rate=%s level=%s connected=%s]%s[/shake]" % [a, b, c, base]
			%Description.text = TranslationManager.tr("Shake makes the text shake.")
		4: 
			if change_visibility:
				_set_node_visibility(%Fade, true)
			var a = %FadeStart.value
			var b = %FadeLength.value
			test_bbcode = "[fade start=%s length=%s]%s[/fade]" % [a, b, base]
			%Description.text = TranslationManager.tr("Fade creates a static fade effect that multiplies each character's opacity.")
		5: 
			if change_visibility:
				_set_node_visibility(%Rainbow, true)
			var a = %RainbowSaturation.value
			var b = %RainbowFrequency.value
			var c = %RainbowValue.value
			test_bbcode = "[rainbow sat=%s freq=%s val=%s]%s[/rainbow]" % [a, b, c, base]
			%Description.text = TranslationManager.tr("Rainbow gives the text a rainbow color that changes over time.")
		6:
			if change_visibility:
				_set_node_visibility(%Ghost, true)
			var a = %GhostFrecuency.value
			var b = %GhostSpan.value
			test_bbcode = "[ghost freq=%s span=%s]%s[/ghost]" % [a, b, base]
			%Description.text = TranslationManager.tr("Creates a ghostly text effect by oscillating the opacity of each character over time.")
		7:
			if change_visibility:
				_set_node_visibility(%ColorMod, true)
			var a = %ColorModColor.get_pick_color().to_html()
			test_bbcode = "[colormod color=#%s]%s[/colormod]" % [a, base]
			%Description.text = TranslationManager.tr("Smoothly transitions text color based on time.")
		8:
			if change_visibility:
				_set_node_visibility(%Cuss, true)
			test_bbcode = "[cuss]%s[/cuss]" % base
			%Description.text = TranslationManager.tr("Replaces letters with symbols, to censor the word, somewhat.")
		9:
			if change_visibility:
				_set_node_visibility(%Heart, true)
			var a = %HeartScale.value
			var b = %HeartFrequency.value
			test_bbcode = "[heart scale=%s freq=%s]%s[/heart]" % [a, b, base]
			%Description.text = TranslationManager.tr("Simple wave animation, where some letters are replaced by heart emoji (♡)")
		10:
			if change_visibility:
				_set_node_visibility(%Jump, true)
			var a = round(%JumpAngle.value * 100) / 100.0
			test_bbcode = "[jump angle=%s]%s[/jump]" % [a, base]
			%Description.text = TranslationManager.tr("Shows the letters jumping.")
		11:
			if change_visibility:
				_set_node_visibility(%L33T, true)
			test_bbcode = "[l33t]%s[/l33t]" % base
			%Description.text = TranslationManager.tr("Replaces letters with numbers. Only use if you're a hacker.")
		12:
			if change_visibility:
				_set_node_visibility(%Nervous, true)
			var a = %NervousScale.value
			var b = %NervousFrequency.value
			test_bbcode = "[nervous scale=%s freq=%s]%s[/nervous]" % [a, b, base]
			%Description.text = TranslationManager.tr("Gives every word a unique jiggle.")
		13:
			if change_visibility:
				_set_node_visibility(%Number, true)
			var a = %NumberColor.get_pick_color().to_html()
			test_bbcode = "[number color=#%s]%s[/number]" % [a, base]
			%Description.text = TranslationManager.tr("Automatically colorizes numbers and the first word after the number.")
		14:
			if change_visibility:
				_set_node_visibility(%Rain, true)
			test_bbcode = "[rain]%s[/rain]" % base
			%Description.text = TranslationManager.tr("Just a rainy effect.")
		15:
			if change_visibility:
				_set_node_visibility(%Sparkle, true)
			var a = %SparkleFrequency.value
			var b = %SparkleColor1.get_pick_color().to_html()
			var c = %SparkleColor2.get_pick_color().to_html()
			var d = %SparkleColor3.get_pick_color().to_html()
			test_bbcode = "[sparkle freq=%s c1=#%s c2=#%s c3=#%s]%s[/sparkle]" % [a, b, c, d, base]
			%Description.text = TranslationManager.tr("Can take up to 3 colors, which it will interpolate between for every letter.")
		16:
			if change_visibility:
				_set_node_visibility(%UwU, true)
			test_bbcode = "[uwu]%s[/uwu]" % base
			%Description.text = TranslationManager.tr("Replaces all letters R and L with W.")
		17:
			if change_visibility:
				_set_node_visibility(%Woo, true)
			var a = %WooScale.value
			var b = %WooFrequency.value
			test_bbcode = "[woo scale=%s freq=%s]%s[/woo]" % [a, b, base]
			%Description.text = TranslationManager.tr("Alternates between upper and lowercase for all the letters, suggesting a condescending tone.")
		18:
			if change_visibility:
				_set_node_visibility(%Learn, true)
			var a = %LearnExactValue.value
			var b = 1 if %LearnVariableValueCheckBox.is_pressed() else 0
			var c = learn_variable_value
			test_bbcode = "[learn progress=%s use_var=%s var=%s]%s[/learn]" % [a, b, c, base]
			%Description.text = TranslationManager.tr("Display text that is difficult to read, determined by a learning value.")
	
	if index in [8, 11, 14, 16]:
		%ParameterLine.visible = false
		%ParameterContainer.visible = false
	else:
		%ParameterLine.visible = true
		%ParameterContainer.visible = true
			
	%TestRich.text = "[center]" + test_bbcode + "[/center]"
	size.y = 0
	if force_size:
		size.y = min_size.y


func _update_learn_variable_id() -> void:
	var data = RPGSYSTEM.system.text_variables
	var variable_name = data.get_item_name(learn_variable_value)
	
	%LearnVariableValue.text = tr("Var") + " %s: %s" % [learn_variable_value, variable_name]


func _on_timer_timeout() -> void:
	pass


func _on_preview_text_text_changed(new_text: String) -> void:
	var index = %EffectSelection.get_selected_id()
	_on_effect_selection_item_selected(index, false)


func _on_learn_exact_value_check_box_toggled(toggled_on: bool) -> void:
	%LearnExactValue.set_disabled(!toggled_on)
	%LearnVariableValue.set_disabled(toggled_on)


func _on_learn_variable_value_check_box_toggled(toggled_on: bool) -> void:
	%LearnExactValue.set_disabled(toggled_on)
	%LearnVariableValue.set_disabled(!toggled_on)


func _on_learn_variable_value_pressed() -> void:
	var path = "res://addons/CustomControls/Dialogs/switch_variable_dialog.tscn"
	var dialog = RPGDialogFunctions.open_dialog(path, RPGDialogFunctions.OPEN_MODE.CENTERED_ON_MOUSE)
	dialog.data_type = 2
	dialog.target = null
	dialog.selected.connect(func(id: int, _target: Variant):
		learn_variable_value = id
		_update_learn_variable_id()
		_refresh_preview(null)
	)
	dialog.variable_or_switch_name_changed.connect(_update_learn_variable_id)
	dialog.setup(learn_variable_value)
