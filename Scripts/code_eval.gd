class_name CodeEval
extends Node2D 

## This script allows for the secure evaluation of limited GDScript code at runtime,
## ensuring unsafe operations are blocked.

## Main thread used to run script code safely in parallel.
var main_thread: Thread

## The dynamically created GDScript to evaluate.
var _script: GDScript

## Error code returned from the last operation.
var _error: int = OK

## Final value returned from the evaluated code.
var final_value: Variant

## Instance of the script used during execution.
var _instance: RefCounted

## Called when the node is added to the scene. Initializes the thread and sets up cleanup on exit.
func _ready() -> void:
	main_thread = Thread.new()
	tree_exiting.connect(
		func():
			if main_thread and main_thread.is_alive():
				main_thread.wait_to_finish()
	)

## Executes the given GDScript code string securely.
## Filters out dangerous operations and runs the code in a separate thread.
## Returns the result of the evaluated code, or null if an error or forbidden keyword is found.
func execute(code: String) -> Variant:
	# Check if the code contains any blacklisted keywords and block it if found
	var blacklist_keywords = [
		"OS", "File", "Directory", "ResourceLoader", "Engine", "preload", "load", 
		"System.exit", "open", "remove", "rename", "eval", "exec", "compile", 
		"import", "global", "class", "extends", "override", "Expression", "http",
		"func", "FileAccess", "DirAccess", "get_tree", "get_editor_interface",
		"EditorPlugin", "ProjectSettings", "await", "call", "callv",
		"connect", "disconnect", "HTTPRequest", "HTTPClient",
		"PacketPeerUDP", "TCPServer", "StreamPeerTCP", "WebSocket",
		"Thread", "Mutex", "Semaphore", "WorkerThreadPool", "MultiplayerAPI",
		"Input", "ClassDB", "assert", "get_script", "set_script",
		"free", "queue_free", "SceneTree", "add_child", "remove_child", "move_child",
		"popagate_call", "propagate_notification", "rpc"
	]
	
	var forbidden_words = []
	var regex = RegEx.new()
	
	for keyword in blacklist_keywords:
		# Create a regex pattern to match whole words
		var pattern = "\\b" + keyword + "\\b"
		regex.compile(pattern)

		# Perform case-insensitive match
		var result = regex.search(code)
		if result:
			forbidden_words.append(keyword)
	
	if not forbidden_words.is_empty():
		push_error("Error compiling script: ", code)
		var fws = str(forbidden_words)
		push_error("Code contains one or more forbidden keyword: %s" % fws)
		return null
	
	var lines = code.split("\n")
	
	var cleaned_code = ""
	for line in lines:
		cleaned_code += "\t" + line + "\n"

	
	# Create script and execute it
	if _script:
		_script = null
		
	_script = GDScript.new()
	_script.source_code = "func eval():\n" + cleaned_code
	
	_error = OK
	if not main_thread:
		main_thread = Thread.new()
	var thread_error = main_thread.start(_reload_in_thread)
	main_thread.wait_to_finish()

	if _error != OK:
		push_error("Error compiling script: ", code)
		push_error("Error code: ", error_string(_error))
		return null
	elif thread_error != OK:
		push_error("Error compiling script: ", code)
		push_error("Error code: ", error_string(thread_error))
		return null
	
	_instance = RefCounted.new()
	_instance.set_script(_script)
	final_value = null
	thread_error = main_thread.start(_execute_in_thread.bind(_instance))
	main_thread.wait_to_finish()
	
	if thread_error != OK:
		push_error("Error compiling script: ", code)
		push_error("Error code: ", error_string(thread_error))
		return null
	
	_instance = null
	return final_value

## Function executed in a separate thread to run the eval method of the script instance.
## Stores the returned value in `final_value`.
func _execute_in_thread(instance) -> void:
	final_value = instance.eval()

## Reloads the script source in a separate thread and stores the result in `_error`.
func _reload_in_thread() -> void:
	# Reload script in secondary thread
	_error = _script.reload(true)
