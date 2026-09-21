-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(LibAPH, "LibAPH must be loaded before APH-OnManager")

AoMCore = AoMCore or {}
local AoM = AoMCore
local LibAPH = LibAPH
AoM.name = "APH-OnManager"
AoM.VERSION = "0.0.1"

local SUGGESTED_CATEGORIES_VERSION = 2
local RETIRED_SUGGESTED_CATEGORIES = {
	"QoL", "Utility", "Crafting", "Inventory", "Trackers", "UI", "Bank", "Overland",
	"PvE", "Combat", "Guild", "Map", "Trial", "PvP", "Housing", "Class",
}

local MIGRATED_FIELDS = {
	"categories", "addon_category_assignment", "default_category_display_names",
	"suggested_categories_applied", "suggested_categories_version", "addon_version_warned", "pending_optional_report",
}

local function MigrateFromLibAPHSavedVars()
	if AoM.saved.migrated_from_libaph_sv or not LibAPH.saved then return end
	AoM.saved.migrated_from_libaph_sv = true
	for _, field in ipairs(MIGRATED_FIELDS) do
		if AoM.saved[field] == nil and LibAPH.saved[field] ~= nil then
			AoM.saved[field] = LibAPH.saved[field]
		end
		LibAPH.saved[field] = nil
	end
end

ZO_CreateStringId("SI_BINDING_NAME_AOM_NEW_CATEGORY", "New Category")
ZO_CreateStringId("SI_BINDING_NAME_AOM_RESET_LIST", "Reset List")
ZO_CreateStringId("SI_BINDING_NAME_AOM_RESET_CATEGORIES", "Reset Categories")
ZO_CreateStringId("SI_BINDING_NAME_AOM_SELECT_ALL_LIBRARIES", "Select All Libraries")
ZO_CreateStringId("SI_BINDING_NAME_AOM_DESELECT_ALL_LIBRARIES", "Deselect All Libraries")

AoM.KEYBIND_LAYER = "APH-On Manager"
AoM.LIBRARIES_KEYBIND_LAYER = "APH-On Manager Libraries"

EVENT_MANAGER:RegisterForEvent("AoM_Init", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= AoM.name then return end
	EVENT_MANAGER:UnregisterForEvent("AoM_Init", EVENT_ADD_ON_LOADED)
	AoM.saved = ZO_SavedVars:NewAccountWide("APHOnManager", 1, GetWorldName() or "Default", {})
	MigrateFromLibAPHSavedVars()
	AoM.saved.addon_version_warned = AoM.saved.addon_version_warned or {}
	LibAPH.RegisterKeybindDefaults("AoM", AoM.saved, {
		AOM_NEW_CATEGORY = KEY_F,
		AOM_RESET_LIST = KEY_Q,
		AOM_RESET_CATEGORIES = KEY_Z,
		AOM_SELECT_ALL_LIBRARIES = KEY_F,
		AOM_DESELECT_ALL_LIBRARIES = KEY_R,
	})

	LibAPH.RegisterAddonDependencies(AoM.name, { "LibAPH" }, { "AddonSelector", "PerfectPixel" })

	LibAPH.SetAddonMetadataProvider(function(name)
		return AoM.KnownLibraries[name] or AoM.KnownAddonVersions[name]
	end)
	AoM.bug_reporter = LibAPH.CreateAddonBugReporter({
		addonName = AoM.name,
		title = "APH-On Manager",
		version = AoM.VERSION,
		boxName = "AoMBugReportBox",
		getStore = function() return AoM.saved end,
	})
	if not IsConsoleUI() then
		SLASH_COMMANDS["/aombugreport"] = AoM.bug_reporter.Show
	end

	LibAPH.CheckAddonVersions(AoM.KnownAddonVersions, AoM.saved.addon_version_warned, function(name, installedVer, expected)
		d(string.format("|c9CD04C[AoM]|r %s is outdated (installed v%d, expected v%s or newer). Update it for the best experience.",
			name, installedVer, expected.displayVersion))
	end)

	if AoM.saved.suggested_categories_version ~= SUGGESTED_CATEGORIES_VERSION then
		if AoM.saved.suggested_categories_applied then
			AoM.RetireSuggestedCategories(RETIRED_SUGGESTED_CATEGORIES)
		end
		AoM.saved.suggested_categories_applied = true
		AoM.saved.suggested_categories_version = SUGGESTED_CATEGORIES_VERSION
		AoM.ApplySuggestedCategories(AoM.SuggestedCategories, false)
	end

	EVENT_MANAGER:RegisterForEvent("AoM_PendingReport", EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent("AoM_PendingReport", EVENT_PLAYER_ACTIVATED)
		AoM.ReportPendingOptionalLibraryChanges()
	end)
end)
