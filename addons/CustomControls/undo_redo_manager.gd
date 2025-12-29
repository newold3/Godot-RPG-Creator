@tool
class_name UndoRedoManager
extends Node


signal do_action(operation_name, value, extra_data)


# Pilas para comandos undo/redo
var undo_stack = []
var redo_stack = []
var max_history_size = 100  # Limitar el tamaño para evitar problemas de memoria


# Capturar teclas para undo/redo
func _input(event):
	if event is InputEventKey and event.pressed:
		# Ctrl+Z para Undo
		if event.keycode == KEY_Z and event.ctrl_pressed and not event.shift_pressed:
			undo()
			get_viewport().set_input_as_handled()
		# Ctrl+Shift+Z para Redo
		elif event.keycode == KEY_Z and event.ctrl_pressed and event.shift_pressed:
			redo()
			get_viewport().set_input_as_handled()


# Función única para registrar cualquier tipo de comando
func register(operation_name: String, old_value: Variant, new_value: Variant, extra_data: Variant = null):
	if not undo_stack.empty():
		var last_command = undo_stack.back()
		if (
			last_command.operation == operation_name and
			last_command.old_value == old_value and
			last_command.new_value == new_value and
			last_command.extra_data == extra_data
		):
			return
		elif last_command.operation == operation_name and last_command.extra_data == extra_data:
			# Same action, modify new_value
			last_command.new_value = new_value
			return
			
	var command = {
		"operation": operation_name,
		"old_value": old_value,
		"new_value": new_value,
		"extra_data": extra_data
	}
	
	# Ejecutar el comando
	_process_command(command, false)  # false = no es un undo
	
	# Añadir a la pila de undo
	undo_stack.append(command)
	
	# Limpiar la pila de redo ya que hemos realizado una nueva acción
	redo_stack.clear()
	
	# Verificar si se excede el tamaño máximo
	if undo_stack.size() > max_history_size:
		undo_stack.pop_front()  # Eliminar el comando más antiguo


# Deshacer último comando
func undo():
	if undo_stack.empty():
		return
		
	var command = undo_stack.pop_back()
	_process_command(command, true)  # true = es un undo
	redo_stack.append(command)


# Rehacer último comando deshecho
func redo():
	if redo_stack.empty():
		return
		
	var command = redo_stack.pop_back()
	_process_command(command, false)  # false = no es un undo
	undo_stack.append(command)


# Procesar un comando (ejecutarlo o deshacerlo)
func _process_command(command, is_undo):
	var operation_name = command["operation"]
	
	# Determinar qué operación y valor enviar
	if is_undo:
		emit_signal("do_action", operation_name, command["old_value"], command["extra_data"])
	else:
		emit_signal("do_action", operation_name, command["new_value"], command["extra_data"])


# Limpiar historial
func clear_history():
	undo_stack.clear()
	redo_stack.clear()


# Verificar si hay comandos para deshacer
func can_undo() -> bool:
	return not undo_stack.empty()


# Verificar si hay comandos para rehacer
func can_redo() -> bool:
	return not redo_stack.empty()
