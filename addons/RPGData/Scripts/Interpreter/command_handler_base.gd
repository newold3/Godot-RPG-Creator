class_name CommandHandlerBase
extends RefCounted

# Referencia al intérprete principal (GameInterpreter)
var interpreter: MainInterpreter: 
	get: return GameInterpreter

# Métodos de conveniencia para acceder a propiedades del intérprete
var current_command: RPGEventCommand:
	get: return GameInterpreter.current_command

var current_interpreter:
	get: return interpreter.current_interpreter

# Métodos útiles que pueden ser usados por los manejadores de comandos
func end_message() -> void:
	if GameManager.message.dialog_is_paused:
		interpreter.showing_message = false
	else:
		await interpreter.end_message()


# Método para depuración con el mismo estilo que el intérprete
func debug_print(text: String) -> void:
	if interpreter.prints_debugs:
		print(text)
