class_name CampaignDefinition
extends Resource

@export var campaign_id: StringName
@export var display_name := ""
@export var waves: Array[WaveDefinition] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if campaign_id == &"":
		errors.append("campaign_id must not be empty")
	if display_name.is_empty():
		errors.append("display_name must not be empty")
	if waves.is_empty():
		errors.append("campaign must contain at least one wave")
	var seen := {}
	for wave in waves:
		if wave == null:
			errors.append("campaign contains a null wave")
			continue
		if seen.has(wave.wave_id):
			errors.append("duplicate wave_id: %s" % wave.wave_id)
		seen[wave.wave_id] = true
		for error in wave.validation_errors():
			errors.append("%s: %s" % [wave.wave_id, error])
	return errors

func wave_count() -> int:
	return waves.size()

func get_wave(index: int) -> WaveDefinition:
	if waves.is_empty():
		return null
	return waves[clampi(index, 0, waves.size() - 1)]
