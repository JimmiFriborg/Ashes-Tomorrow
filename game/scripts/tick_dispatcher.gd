extends Node
class_name TickDispatcher

signal tick_started(tick_number: int, step: float)
signal entropy_phase(step: float)
signal player_phase(step: float)
signal resolution_phase(step: float)
signal tick_completed(tick_number: int, step: float)
signal time_scale_changed(scale: float)
signal pause_state_changed(paused: bool)

static var _singleton: TickDispatcher

static func get_singleton() -> TickDispatcher:
    return _singleton

func _enter_tree() -> void:
    _singleton = self

func _exit_tree() -> void:
    if _singleton == self:
        _singleton = null

func emit_tick_started(tick_number: int, step: float) -> void:
    tick_started.emit(tick_number, step)

func emit_entropy_phase(step: float) -> void:
    entropy_phase.emit(step)

func emit_player_phase(step: float) -> void:
    player_phase.emit(step)

func emit_resolution_phase(step: float) -> void:
    resolution_phase.emit(step)

func emit_tick_completed(tick_number: int, step: float) -> void:
    tick_completed.emit(tick_number, step)

func emit_time_scale_changed(scale: float) -> void:
    time_scale_changed.emit(scale)

func emit_pause_state_changed(paused: bool) -> void:
    pause_state_changed.emit(paused)
