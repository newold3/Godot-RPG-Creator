@tool
extends MarginContainer

@export var title: String = "" : set = _set_title
@export var initial_position: Vector2
@export var end_position: Vector2

var animation_time = 0.7

var main_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		visibility_changed.connect(%MenuTitle._fix_label.bind(3))
	call_deferred("start")
	_set_title(title)
	await get_tree().process_frame
	_set_title(title)


func _set_title(_title: String) -> void:
	title = _title
	if is_node_ready():
		%MenuTitle.label_text = tr(title)


func start() -> void:
	if main_tween:
		main_tween.kill()
		
	main_tween = create_tween()
	main_tween.set_parallel(true)
	
	main_tween.tween_property(self, "position", end_position, animation_time * 0.5).set_trans(Tween.TRANS_SINE).from(initial_position)
	
	var gears = [%GearLeft1, %GearLeft4]
	for i in gears.size():
		var gear = gears[i]
		gear.rotation = PI if i == 0 else -PI
		main_tween.tween_property(gear, "rotation", 0.0, animation_time*2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	gears = [%GearLeft2, %GearLeft3]
	for i in gears.size():
		var gear = gears[i]
		gear.rotation = PI/2 if i == 0 else -PI/2
		main_tween.tween_property(gear, "rotation", 0.0, animation_time*2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func end() -> void:
	if main_tween:
		main_tween.kill()
		
	main_tween = create_tween()
	main_tween.set_parallel(true)
	
	main_tween.tween_property(self, "position", initial_position, animation_time).set_trans(Tween.TRANS_SINE)
	
	var gears = [%GearLeft1, %GearLeft4]
	for i in gears.size():
		var gear = gears[i]
		gear.rotation = PI if i == 0 else -PI
		main_tween.tween_property(gear, "rotation", 0.0, animation_time).set_trans(Tween.TRANS_SINE)
	
	gears = [%GearLeft2, %GearLeft3]
	for i in gears.size():
		var gear = gears[i]
		gear.rotation = PI/2 if i == 0 else -PI/2
		main_tween.tween_property(gear, "rotation", 0.0, animation_time).set_trans(Tween.TRANS_SINE)
