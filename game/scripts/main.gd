extends Node
class_name Main

var _ticks_per_second_internal := 30.0
var _tick_step := 1.0 / 30.0
var _tick_accumulator := 0.0
var _tick_counter := 0

var _time_scale_target := 1.0
var _effective_time_scale := 1.0
var _paused := false

enum TimeControl { PAUSED, NORMAL, DOUBLE, TRIPLE }
const TIME_MULTIPLIERS := {
    TimeControl.NORMAL: 1.0,
    TimeControl.DOUBLE: 2.0,
    TimeControl.TRIPLE: 3.0,
}

var _current_time_control: TimeControl = TimeControl.NORMAL
var _last_active_time_control: TimeControl = TimeControl.NORMAL

var tick_dispatcher: TickDispatcher

@export var ticks_per_second: float = 30.0:
    get:
        return _ticks_per_second_internal
    set(value):
        _ticks_per_second_internal = max(value, 1.0)
        _tick_step = 1.0 / _ticks_per_second_internal

func _ready() -> void:
    tick_dispatcher = TickDispatcher.new()
    tick_dispatcher.name = "TickDispatcher"
    add_child(tick_dispatcher)
    tick_dispatcher.emit_time_scale_changed(_effective_time_scale)
    tick_dispatcher.emit_pause_state_changed(_paused)

func _process(delta: float) -> void:
    if _effective_time_scale == 0.0:
        return

    var scaled_delta := delta * _effective_time_scale
    _tick_accumulator += scaled_delta

    while _tick_accumulator >= _tick_step:
        _tick_accumulator -= _tick_step
        _tick_counter += 1
        _process_tick(_tick_step)

func _process_tick(step: float) -> void:
    tick_dispatcher.emit_tick_started(_tick_counter, step)
    entropy_phase(step)
    player_phase(step)
    resolution_phase(step)
    tick_dispatcher.emit_tick_completed(_tick_counter, step)

func entropy_phase(step: float) -> void:
    tick_dispatcher.emit_entropy_phase(step)

func player_phase(step: float) -> void:
    tick_dispatcher.emit_player_phase(step)

func resolution_phase(step: float) -> void:
    tick_dispatcher.emit_resolution_phase(step)

func get_tick_count() -> int:
    return _tick_counter

func get_tick_dispatcher() -> TickDispatcher:
    return tick_dispatcher

func is_paused() -> bool:
    return _paused

func get_time_scale() -> float:
    return _effective_time_scale

func set_time_control(mode: TimeControl) -> void:
    if mode == TimeControl.PAUSED:
        _set_paused(true)
        return

    _current_time_control = mode
    _last_active_time_control = mode
    _set_paused(false)
    var multiplier := TIME_MULTIPLIERS.get(mode, 1.0)
    _set_time_scale_target(multiplier)

func pause_game() -> void:
    set_time_control(TimeControl.PAUSED)

func resume_game() -> void:
    set_time_control(_last_active_time_control)

func play_normal() -> void:
    set_time_control(TimeControl.NORMAL)

func play_double() -> void:
    set_time_control(TimeControl.DOUBLE)

func play_triple() -> void:
    set_time_control(TimeControl.TRIPLE)

func toggle_pause() -> void:
    if _paused:
        resume_game()
    else:
        pause_game()

func _set_time_scale_target(multiplier: float) -> void:
    _time_scale_target = max(multiplier, 0.0)
    if _paused:
        return
    _update_effective_time_scale(_time_scale_target)

func _set_paused(value: bool) -> void:
    if _paused == value:
        return
    _paused = value
    if _paused:
        _update_effective_time_scale(0.0)
    else:
        _update_effective_time_scale(_time_scale_target)
    if tick_dispatcher:
        tick_dispatcher.emit_pause_state_changed(_paused)

func _update_effective_time_scale(multiplier: float) -> void:
    if is_equal_approx(_effective_time_scale, multiplier):
        return
    _effective_time_scale = multiplier
    if tick_dispatcher:
        tick_dispatcher.emit_time_scale_changed(_effective_time_scale)
