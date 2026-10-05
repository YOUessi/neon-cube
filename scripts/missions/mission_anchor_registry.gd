class_name MissionAnchorRegistry
extends RefCounted

static func collect(root: Node) -> Dictionary:
	var result := {}
	_collect_recursive(root, result)
	return result

static func find_for_encounter(
	anchors: Dictionary,
	encounter_id: StringName,
	kind: int
) -> MissionAnchor:
	for key in anchors:
		var anchor: MissionAnchor = anchors[key]
		if anchor.encounter_id == encounter_id and int(anchor.kind) == kind:
			return anchor
	return null

static func validate(root: Node, mission: MissionDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	var anchors := collect(root)
	var ids := {}
	for key in anchors:
		var anchor: MissionAnchor = anchors[key]
		if ids.has(anchor.anchor_id):
			errors.append("duplicate anchor_id: %s" % anchor.anchor_id)
		ids[anchor.anchor_id] = true
		for error in anchor.validation_errors():
			errors.append("%s: %s" % [anchor.anchor_id, error])

	var has_player_start := false
	for key in anchors:
		var anchor: MissionAnchor = anchors[key]
		if anchor.kind == MissionAnchor.Kind.PLAYER_START:
			has_player_start = true
			break
	if not has_player_start:
		errors.append("mission level requires player start anchor")

	if mission != null:
		for encounter in mission.encounters:
			var has_center := false
			var has_checkpoint := encounter.checkpoint_id == &""
			for key in anchors:
				var anchor: MissionAnchor = anchors[key]
				if anchor.encounter_id != encounter.encounter_id:
					continue
				if anchor.kind == MissionAnchor.Kind.ENCOUNTER_CENTER:
					has_center = true
				if anchor.kind == MissionAnchor.Kind.CHECKPOINT and anchor.anchor_id == encounter.checkpoint_id:
					has_checkpoint = true
			if not has_center:
				errors.append("%s has no encounter center anchor" % encounter.encounter_id)
			if not has_checkpoint:
				errors.append("%s has no checkpoint anchor %s" % [encounter.encounter_id, encounter.checkpoint_id])
	return errors

static func _collect_recursive(node: Node, result: Dictionary) -> void:
	if node is MissionAnchor:
		var anchor := node as MissionAnchor
		result[String(anchor.anchor_id)] = anchor
	for child in node.get_children():
		_collect_recursive(child, result)
