class_name GameState
extends Resource

## Represents an active instance of a status effect applied to a character or entity.
##
## This class tracks the state’s duration, behavior, and application context.
## It supports both time-based and turn-based durations, as well as tick-based logic
## for states that trigger effects at regular intervals.
## It also handles cumulative stacking through [member cumulative_effect].

enum STATE_MODE {
	STATE_CONTEXT_GLOBAL = 1,       ## Applies in all contexts (exploration and battle).
	STATE_CONTEXT_BATTLE_ONLY = 2,  ## Applies only during battles.
	STATE_DURATION_TURNS = 4,       ## Duration is measured in turns.
	STATE_DURATION_SECONDS = 8,     ## Duration is measured in seconds.
	STATE_DURATION_PERMANENT = 16,  ## State lasts indefinitely within its context.
	STATE_TICKS_ENABLED = 32        ## State triggers actions at regular intervals (ticks).
}

## Real database ID of the state.
@export var id: int = 0

## Remaining duration of the state (in seconds or turns, depending on the mode).
@export var duration: float = 0.0

## Time between each tick (only used if ticks are enabled).
@export var tick_interval: float = 1.0

## Internal timer to track when the next tick should occur.
@export var tick_timer: float = 0.0

## Bitmask that defines the state's context, duration type, and tick behavior.
@export var state_mode: STATE_MODE = STATE_MODE.STATE_CONTEXT_GLOBAL | STATE_MODE.STATE_DURATION_SECONDS

## Value used to amplify the effect (typically increased by stacking cumulative states).
@export var cumulative_effect: int = 1

## Number of times this state has been applied (used to track usage or scale effects).
@export var usage_count: int = 0


signal state_ended(state: GameState)   ## Emitted when the state expires (duration reaches 0).
signal state_tick(state: GameState)    ## Emitted every time a tick interval is completed.


## Initializes a new GameState instance with the given parameters.
func _init(
	_id: int = 0,
	_duration: float = 0.0,
	_tick_interval: float = 1.0,
	_state_mode: STATE_MODE = STATE_MODE.STATE_CONTEXT_GLOBAL | STATE_MODE.STATE_DURATION_SECONDS
) -> void:
	id = _id
	duration = _duration
	tick_interval = _tick_interval
	state_mode = _state_mode


## Returns true if the state is active only during battles.
func is_battle_only() -> bool:
	return (state_mode & STATE_MODE.STATE_CONTEXT_BATTLE_ONLY) != 0

## Returns true if the state’s duration is measured in turns.
func is_duration_turn_based() -> bool:
	return (state_mode & STATE_MODE.STATE_DURATION_TURNS) != 0

## Returns true if the state’s duration is measured in real-time seconds.
func is_duration_time_based() -> bool:
	return (state_mode & STATE_MODE.STATE_DURATION_SECONDS) != 0

## Returns true if the state is permanent and does not expire.
func is_permanent() -> bool:
	return (state_mode & STATE_MODE.STATE_DURATION_PERMANENT) != 0

## Returns true if the state has ticking behavior enabled.
func has_ticks() -> bool:
	return (state_mode & STATE_MODE.STATE_TICKS_ENABLED) != 0

## Updates the state's lifetime.
## - If the state is permanent, it remains active indefinitely and does not update.
## - If ticks are enabled, it accumulates time and emits [signal state_tick] when the interval is reached.
## - In battle, both [b]delta[/b] and [b]tick_interval[/b] are always 1. Out of battle, [b]delta[/b] is the process time, and [b]tick_interval[/b] is defined in the database.
## - Decreases the duration based on time or turns, depending on the state's mode.
## - Emits [signal state_ended] when the duration reaches zero.
func update_lifetime(delta: float) -> void:
	if has_ticks():
		tick_timer += delta
		if tick_timer >= tick_interval:
			tick_timer = 0.0
			state_tick.emit()
	
	if is_permanent():
		return
	
	if is_duration_turn_based():
		duration = maxf(0.0, duration - 1)
	else:
		duration = maxf(0.0, duration - delta)
	
	if duration <= 0:
		state_ended.emit(self)
