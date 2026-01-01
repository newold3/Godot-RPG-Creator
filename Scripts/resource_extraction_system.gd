class_name ResourceExtractionSystem
extends Node

# Base system configuration
@export var base_success_step: int = 12
@export var base_failure_step: int = 15
@export var base_failure_rate: int = 30 # %
@export var tick_interval: float = 1.0
@export var bar_animation_duration: float = 0.4

# UI References
@onready var success_bar: ProgressBar
@onready var failure_bar: ProgressBar
@onready var extraction_ui: Control
@onready var player_sprite: AnimatedSprite2D

# Current extraction state
var is_extracting: bool = false
var current_node: GameExtractionItem
var current_player_level: int
var success_progress: float = 0.0
var failure_progress: float = 0.0
var success_step_size: int
var failure_step_size: int
var failure_chance: int
var extraction_timer: Timer

# Signals
signal extraction_completed(items: Array)
signal extraction_failed()
signal extraction_started(node: GameExtractionItem)

func _ready():
	# Create timer for extraction ticks
	extraction_timer = Timer.new()
	extraction_timer.wait_time = tick_interval
	extraction_timer.timeout.connect(_on_extraction_tick)
	extraction_timer.one_shot = false
	add_child(extraction_timer)

func start_extraction(node: GameExtractionItem, player_level: int) -> bool:
	if is_extracting:
		return false
	
	# Check if player meets requirements
	if not _can_extract(node, player_level):
		_show_error_message("No tienes el nivel suficiente en " + str(node.required_profession))
		return false
	
	current_node = node
	current_player_level = player_level
	
	# Calculate extraction parameters
	_calculate_extraction_parameters()
	
	# Initialize UI
	_setup_extraction_ui()
	
	# Start extraction
	is_extracting = true
	success_progress = 0.0
	failure_progress = 0.0
	
	# Start player animation
	if player_sprite:
		player_sprite.play("cast_magic") # LPC magic summon animation
	
	# Start tick timer
	extraction_timer.start()
	
	# Emit signal
	extraction_started.emit(node)
	
	return true

func _can_extract(node: GameExtractionItem, player_level: int) -> bool:
	# Check profession and minimum level
	var player_profession_level = GameManager.get_player_profession_level(node.required_profession)
	
	return player_profession_level >= node.min_

func _calculate_extraction_parameters():
	var level_diff = current_player_level - current_node.level
	
	# Calculate success step (better with higher level)
	success_step_size = base_success_step + (level_diff * 2)
	success_step_size = max(5, success_step_size) # Minimum 5%
	
	# Calculate failure step (worse with higher level difference)
	var reverse_diff = current_node.level - current_player_level
	
	if reverse_diff <= 0:
		failure_step_size = base_failure_step
	elif reverse_diff <= 3:
		failure_step_size = base_failure_step * 2
	elif reverse_diff <= 5:
		failure_step_size = base_failure_step * 4
	else:
		failure_step_size = 100 # Instant failure
	
	# Calculate failure chance
	failure_chance = base_failure_rate - (level_diff * 3)
	failure_chance = clamp(failure_chance, 5, 80) # Between 5% and 80%

func _setup_extraction_ui():
	if extraction_ui:
		extraction_ui.visible = true
	
	if success_bar:
		success_bar.value = 0
		success_bar.max_value = 100
	
	if failure_bar:
		failure_bar.value = 0
		failure_bar.max_value = 100

func _on_extraction_tick():
	if not is_extracting:
		return
	
	var roll = randi_range(1, 100)
	
	if roll <= failure_chance:
		# Failure tick
		_process_failure_tick()
	else:
		# Success tick - check criticals
		_process_success_tick()
	
	# Check completion conditions
	_check_completion()

func _process_failure_tick():
	var fill_amount = failure_step_size
	
	# Animate failure bar fill
	_animate_bar_fill(failure_bar, fill_amount, Color.RED)
	
	failure_progress += fill_amount
	failure_progress = min(failure_progress, 100.0)
	
	# Feedback effects
	_play_failure_sound()

func _process_success_tick():
	var crit_roll = randi_range(1, 100)
	var fill_amount = success_step_size
	var effect_color = Color.GREEN
	
	# Check criticals
	if crit_roll == 1:
		# Super critical (1%)
		fill_amount *= 5
		effect_color = Color.GOLD
		_play_super_critical_effect()
	elif crit_roll <= 10:
		# Critical (10%)
		fill_amount *= 2
		effect_color = Color.YELLOW
		_play_critical_effect()
	else:
		# Normal success
		_play_success_sound()
	
	# Animate success bar fill
	_animate_bar_fill(success_bar, fill_amount, effect_color)
	
	success_progress += fill_amount
	success_progress = min(success_progress, 100.0)

func _animate_bar_fill(bar: ProgressBar, amount: float, color: Color):
	if not bar:
		return
	
	var initial_value = bar.value
	var target_value = min(bar.value + amount, bar.max_value)
	
	# Create tween for smooth animation
	var tween = create_tween()
	tween.tween_property(bar, "value", target_value, bar_animation_duration)
	
	# Visual color effect (optional)
	_create_fill_effect(bar, color)

func _create_fill_effect(bar: ProgressBar, color: Color):
	# Here you can add effects like particles, color flash, etc.
	# Basic example: color flash
	var original_modulate = bar.modulate
	bar.modulate = color
	
	var tween = create_tween()
	tween.tween_property(bar, "modulate", original_modulate, 0.2)

func _check_completion():
	if success_progress >= 100.0:
		_extraction_success()
	elif failure_progress >= 100.0:
		_extraction_failure()

func _extraction_success():
	_stop_extraction()
	
	# Generate rewards
	var rewards = _generate_rewards()
	
	# Update node state
	_update_node_state()
	
	# Emit signal with rewards
	extraction_completed.emit(rewards)
	
	_show_success_message(rewards)

func _extraction_failure():
	_stop_extraction()
	
	# Emit failure signal
	extraction_failed.emit()
	
	_show_failure_message()

func _generate_rewards() -> Array:
	var rewards = []
	
	for drop in current_node.drop_table:
		var roll = randi_range(1, 100)
		if roll <= drop.chance:
			var quantity = randi_range(drop.min_quantity, drop.max_quantity)
			rewards.append({
				"item_id": drop.item_id,
				"quantity": quantity
			})
	
	return rewards

func _update_node_state():
	current_node.current_uses -= 1
	
	if current_node.current_uses <= 0:
		current_node.depletion_time = Time.get_unix_time_from_system()
		_update_node_visual_state()

func _update_node_visual_state():
	# Change node sprite to depleted state
	if current_node.sprite:
		current_node.sprite.modulate = Color.GRAY

func _stop_extraction():
	is_extracting = false
	extraction_timer.stop()
	
	# Stop player animation
	if player_sprite:
		player_sprite.stop()
	
	# Hide UI
	if extraction_ui:
		extraction_ui.visible = false
	
	# Clear references
	current_node = null

# Effect and sound functions (implement according to your audio/effects system)
func _play_success_sound():
	# AudioManager.play_sound("extraction_success")
	pass

func _play_critical_effect():
	# AudioManager.play_sound("extraction_critical")
	# EffectsManager.show_critical_particles()
	pass

func _play_super_critical_effect():
	# AudioManager.play_sound("extraction_super_critical")
	# EffectsManager.show_super_critical_particles()
	pass

func _play_failure_sound():
	# AudioManager.play_sound("extraction_failure")
	pass

# UI and message functions (implement according to your UI system)
func _show_error_message(message: String):
	print("ERROR: " + message)
	# UIManager.show_error_popup(message)

func _show_success_message(rewards: Array):
	print("¡Extracción exitosa! Recompensas: " + str(rewards))
	# UIManager.show_extraction_results(rewards)

func _show_failure_message():
	print("¡Extracción fallida!")
	# UIManager.show_failure_popup()

# Function to check and respawn depleted nodes
func check_node_respawn(node: GameExtractionItem):
	if not node.is_depleted:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var time_passed = current_time - node.depletion_time
	
	if time_passed >= node.respawn_time:
		node.current_uses = node.max_uses
		node.depletion_time = 0
		
		# Restore node visual
		if node.sprite:
			node.sprite.modulate = Color.WHITE
