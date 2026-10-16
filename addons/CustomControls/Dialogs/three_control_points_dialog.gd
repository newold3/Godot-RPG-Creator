@tool
extends Window


var real_data: PackedInt32Array
var min_value: int
var max_value: int


signal data_changed()


func _ready() -> void:
	close_requested.connect(queue_free)


func set_data(data: PackedInt32Array, new_min_value: int, new_max_value: int) -> void:
	real_data = data
	min_value = new_min_value
	max_value = new_max_value
	
	_reverse_calculate_sliders(real_data)
	
	await get_tree().process_frame
	_on_slider_value_changed(0.0)


func _on_ok_button_pressed() -> void:
	_update_real_data()
	data_changed.emit()
	queue_free()


func _get_value_at_t(target_array: Array, t: float) -> float:
	var max_idx: float = float(target_array.size() - 1)
	var pos: float = t * max_idx
	var idx: int = int(pos)
	var frac: float = pos - float(idx)
	
	if idx >= target_array.size() - 1:
		return target_array[-1]
	
	return lerpf(target_array[idx], target_array[idx + 1], frac)


func _reverse_calculate_sliders(target_array: Array) -> void:
	var total_elements: int = target_array.size()
	if total_elements < 2:
		return
	
	var range_val: float = max_value - min_value
	if range_val <= 0.0:
		return
	
	var val_t1: float = _get_value_at_t(target_array, 0.25)
	var val_t2: float = _get_value_at_t(target_array, 0.50)
	var val_t3: float = _get_value_at_t(target_array, 0.75)
	
	var y1: float = (val_t1 - min_value) / range_val
	var y2: float = (val_t2 - min_value) / range_val
	var y3: float = (val_t3 - min_value) / range_val
	
	var rhs1: float = y1 - 0.00390625
	var rhs2: float = y2 - 0.0625
	var rhs3: float = y3 - 0.31640625
	
	var s1: float = (4.0 * rhs1) - (3.0 * rhs2) + ((4.0 / 3.0) * rhs3)
	var s2: float = ((-32.0 / 9.0) * rhs1) + ((20.0 / 3.0) * rhs2) - ((32.0 / 9.0) * rhs3)
	var s3: float = ((4.0 / 3.0) * rhs1) - (3.0 * rhs2) + (4.0 * rhs3)
	
	%EarlySlider.set_value_no_signal(clampf(s1, 0.0, 1.0))
	%MidSlider.set_value_no_signal(clampf(s2, 0.0, 1.0))
	%EndSlider.set_value_no_signal(clampf(s3, 0.0, 1.0))


func _update_real_data(target_data: Variant = null) -> void:
	var early_val: float = %EarlySlider.value
	var mid_val: float = %MidSlider.value
	var end_val: float = %EndSlider.value
	
	var data = real_data if target_data == null else target_data
	
	var max_levels: int = data.size() - 1
	if max_levels <= 0:
		return
	
	var p0: float = min_value
	var p1: float = lerpf(min_value, max_value, early_val)
	var p2: float = lerpf(min_value, max_value, mid_val)
	var p3: float = lerpf(min_value, max_value, end_val)
	var p4: float = max_value
	
	for i in range(max_levels + 1):
		var t: float = float(i) / float(max_levels)
		
		var a: float = lerpf(p0, p1, t)
		var b: float = lerpf(p1, p2, t)
		var c: float = lerpf(p2, p3, t)
		var d: float = lerpf(p3, p4, t)
		
		var ab: float = lerpf(a, b, t)
		var bc: float = lerpf(b, c, t)
		var cd: float = lerpf(c, d, t)
		
		var abc: float = lerpf(ab, bc, t)
		var bcd: float = lerpf(bc, cd, t)
		
		var final_val: float = lerpf(abc, bcd, t)
		
		data[i] = int(clampf(final_val, min_value, max_value))
	
	%CurvePreview.draw_curve(data)


func _on_cancel_button_pressed() -> void:
	queue_free()


func _on_slider_value_changed(_value: float) -> void:
	_update_real_data(real_data.duplicate())
