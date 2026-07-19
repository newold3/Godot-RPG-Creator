@tool
class_name InstantText
extends NinePatchRect


var config: Dictionary # {scroll_speed, scroll_direction, scroll_scene, enable_fast_forward}
var enabled: bool = false

@onready var message: RichTextLabel = %Message


func _ready() -> void:

	setup_effects()
	set_process(false)
	if RPGDialogFunctions.there_are_any_dialog_open():
		start()


func setup_effects():
	var paths = [
		"res://addons/CustomControls/Resources/RichTextEffects/ColorMod.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Cuss.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/ghost.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Heart.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Jump.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/L33T.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Nervous.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Number.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Rain.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Sparkle.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/UwU.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/Woo.gd",
		"res://addons/CustomControls/Resources/RichTextEffects/lenguage_learning.gd"
	]
	for path in paths:
		var effect = load(path).new()
		message.install_effect(effect)


func set_config(_config: Dictionary) -> void:
	config = _config


func reset() -> void:
	pass


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
		
	if enabled and ControllerManager.is_cancel_just_pressed():
		end()


func set_text(text: String) -> void:
	var node = message
	node.text = "\n" + text + "\n"
	
	reset()


func start() -> void:
	set_process(true)
	enabled = true


func end() -> void:
	set_process(false)
	queue_free()
