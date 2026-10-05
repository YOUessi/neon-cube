class_name CampaignCatalog
extends RefCounted

const MAIN_CAMPAIGN: CampaignDefinition = preload("res://data/campaigns/neon_cube_campaign.tres")

static func primary() -> CampaignDefinition:
	return MAIN_CAMPAIGN

static func validate_all() -> PackedStringArray:
	return MAIN_CAMPAIGN.validation_errors()
