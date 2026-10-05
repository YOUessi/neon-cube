class_name RuntimePerformanceMonitor
extends Node

signal report_ready(report: Dictionary)
signal budget_warning(messages: PackedStringArray)

@export var budget: PerformanceBudget
@export var sample_frames := 120

var _frame_count := 0
var _frame_sum_ms := 0.0
var _peak_frame_ms := 0.0
var _last_report: Dictionary = {}

func _process(delta: float) -> void:
	var frame_ms := delta * 1000.0
	_frame_count += 1
	_frame_sum_ms += frame_ms
	_peak_frame_ms = maxf(_peak_frame_ms, frame_ms)
	if _frame_count < maxi(1, sample_frames):
		return
	_publish_report()

func _publish_report() -> void:
	var average := _frame_sum_ms / float(maxi(1, _frame_count))
	var enemy_count := get_tree().get_nodes_in_group("enemies").size()
	var pickup_count := get_tree().get_nodes_in_group("pickups").size()
	var warnings := PackedStringArray()
	if budget != null:
		warnings = budget.evaluate(average, _peak_frame_ms, enemy_count, pickup_count)
	_last_report = {
		"average_frame_ms": average,
		"peak_frame_ms": _peak_frame_ms,
		"active_enemies": enemy_count,
		"active_pickups": pickup_count,
		"warnings": warnings,
	}
	report_ready.emit(_last_report.duplicate(true))
	if not warnings.is_empty():
		budget_warning.emit(warnings)
	_reset_window()

func _reset_window() -> void:
	_frame_count = 0
	_frame_sum_ms = 0.0
	_peak_frame_ms = 0.0

func last_report() -> Dictionary:
	return _last_report.duplicate(true)
