class_name MissionRuntime
extends RefCounted

enum State { NOT_STARTED, ACTIVE, COMPLETED, FAILED }

signal state_changed(state: int)
signal encounter_started(index: int, encounter: EncounterDefinition)
signal checkpoint_changed(checkpoint_id: StringName)
signal mission_completed

var definition: MissionDefinition
var state := State.NOT_STARTED
var encounter_index := 0
var checkpoint_id: StringName = &""
var completed_encounters: Array[StringName] = []

func start(mission: MissionDefinition) -> void:
	definition = mission
	state = State.ACTIVE
	encounter_index = 0
	checkpoint_id = &""
	completed_encounters.clear()
	state_changed.emit(state)
	_emit_current_encounter()

func current_encounter() -> EncounterDefinition:
	if definition == null:
		return null
	return definition.get_encounter(encounter_index)

func complete_current_encounter() -> bool:
	if state != State.ACTIVE:
		return false
	var encounter := current_encounter()
	if encounter == null:
		return false
	if not completed_encounters.has(encounter.encounter_id):
		completed_encounters.append(encounter.encounter_id)
	if encounter.checkpoint_id != &"":
		checkpoint_id = encounter.checkpoint_id
		checkpoint_changed.emit(checkpoint_id)

	if encounter_index >= definition.encounter_count() - 1:
		state = State.COMPLETED
		state_changed.emit(state)
		mission_completed.emit()
		return true

	encounter_index += 1
	_emit_current_encounter()
	return true

func fail() -> void:
	if state == State.COMPLETED:
		return
	state = State.FAILED
	state_changed.emit(state)

func restart_from_checkpoint() -> void:
	if definition == null:
		return
	state = State.ACTIVE
	if checkpoint_id == &"":
		encounter_index = 0
	else:
		var checkpoint_index := _index_for_checkpoint(checkpoint_id)
		encounter_index = maxi(0, checkpoint_index + 1)
		encounter_index = mini(encounter_index, definition.encounter_count() - 1)
	state_changed.emit(state)
	_emit_current_encounter()

func snapshot() -> Dictionary:
	return {
		"mission_id": definition.mission_id if definition != null else &"",
		"state": int(state),
		"encounter_index": encounter_index,
		"checkpoint_id": checkpoint_id,
		"completed_encounters": completed_encounters.duplicate(),
	}

func restore(mission: MissionDefinition, snapshot_data: Dictionary) -> void:
	definition = mission
	encounter_index = clampi(int(snapshot_data.get("encounter_index", 0)), 0, maxi(0, mission.encounter_count() - 1))
	checkpoint_id = StringName(snapshot_data.get("checkpoint_id", ""))
	completed_encounters.clear()
	for item in snapshot_data.get("completed_encounters", []):
		completed_encounters.append(StringName(item))
	state = clampi(int(snapshot_data.get("state", State.NOT_STARTED)), State.NOT_STARTED, State.FAILED)
	state_changed.emit(state)
	if state == State.ACTIVE:
		_emit_current_encounter()

func _index_for_checkpoint(id: StringName) -> int:
	if definition == null:
		return -1
	for i in range(definition.encounter_count()):
		if definition.encounters[i].checkpoint_id == id:
			return i
	return -1

func _emit_current_encounter() -> void:
	var encounter := current_encounter()
	if encounter != null:
		encounter_started.emit(encounter_index, encounter)
