class_name CampaignCatalog
extends RefCounted

const MAIN_CAMPAIGN_PATH := "res://data/campaigns/neon_cube_campaign.tres"

static func primary() -> CampaignDefinition:
	var resource := load(MAIN_CAMPAIGN_PATH)
	if resource is CampaignDefinition:
		return resource as CampaignDefinition
	push_error("CampaignCatalog could not load typed campaign resource")
	return null

static func validate_all() -> PackedStringArray:
	var campaign := primary()
	if campaign == null:
		return PackedStringArray(["primary campaign failed to load as CampaignDefinition"])
	return campaign.validation_errors()
