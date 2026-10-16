@tool
extends GuiCoreConfirmDialog

@onready var main_container: MarginContainer = $mainContainer
@onready var gear: TextureRect = %Gear
@onready var arm_left: Node2D = $Arms/Left/Arm
@onready var arm_right: Node2D = $Arms/Right/Arm

var gear_tween: Tween


func _animate_start() -> void:
	if arm_left: arm_left.start()
	if arm_right: arm_right.start()
	if main_container: main_container.modulate.a = 1.0

	if gear_tween:
		gear_tween.kill()
	if gear:
		gear_tween = create_tween()
		gear_tween.set_loops()
		gear_tween.tween_property(gear, "rotation", TAU, 2.5).from(0.0)

	if main_container:
		main_container.pivot_offset = main_container.size * 0.5
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(self, "self_modulate:a", 1.0, 0.5).from(0.0)
		t.tween_property(main_container, "scale:x", 1.0, 0.6).from(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_callback(_on_start_completed).set_delay(0.3)
	else:
		_on_start_completed()


func _animate_end(emit_cancel: bool = false) -> void:
	if arm_left: arm_left.end()
	if arm_right: arm_right.end()

	if gear_tween:
		gear_tween.kill()
	if gear:
		gear_tween = create_tween()
		gear_tween.set_loops()
		gear_tween.tween_property(gear, "rotation", -TAU, 1.25)

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "self_modulate:a", 0.2, 0.35)
	if main_container:
		t.tween_property(main_container, "modulate:a", 0.0, 0.15).set_delay(0.2)
		t.tween_property(main_container, "scale:x", 0.8, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if emit_cancel:
		t.tween_callback(func(): cancel.emit()).set_delay(0.25)
	t.set_parallel(false)
	if gear_tween:
		t.tween_callback(gear_tween.kill)
	t.tween_callback(set.bind("visible", false))
