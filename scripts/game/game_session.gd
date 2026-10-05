class_name GameSession
extends RefCounted

enum State { MENU, PLAYING, PAUSED, VICTORY, GAME_OVER }

signal state_changed(state: State)
signal score_changed(score: int)
signal wave_changed(wave_number: int)
signal hostiles_changed(count: int)

var state: State = State.MENU
var score := 0
var wave_index := 0
var alive_enemies := 0
var kills := 0
var difficulty_name := "OPERATIVE"
var difficulty_scale := 1.0

func reset_run(difficulty: String, scale: float) -> void:
	score = 0
	wave_index = 0
	alive_enemies = 0
	kills = 0
	difficulty_name = difficulty
	difficulty_scale = maxf(0.5, scale)
	set_state(State.PLAYING)
	score_changed.emit(score)
	wave_changed.emit(current_wave_number())
	hostiles_changed.emit(alive_enemies)

func set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)

func add_enemy() -> void:
	alive_enemies += 1
	hostiles_changed.emit(alive_enemies)

func register_kill(score_value: int) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	kills += 1
	score += maxi(0, score_value)
	score_changed.emit(score)
	hostiles_changed.emit(alive_enemies)

func advance_wave() -> void:
	wave_index += 1
	wave_changed.emit(current_wave_number())

func current_wave_number() -> int:
	return wave_index + 1

func is_last_wave(campaign: CampaignDefinition) -> bool:
	return wave_index >= campaign.wave_count() - 1

func snapshot() -> Dictionary:
	return {
		"state": int(state),
		"score": score,
		"wave_index": wave_index,
		"alive_enemies": alive_enemies,
		"kills": kills,
		"difficulty_name": difficulty_name,
		"difficulty_scale": difficulty_scale,
	}
