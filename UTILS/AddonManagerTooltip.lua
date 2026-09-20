-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
local AoM = AoMCore
assert(AoM.KnownAddonDependencies, "KnownAddonDependencies.lua must be loaded before this file")
assert(AoM.KnownAddonVersions, "KnownAddonVersions.lua must be loaded before this file")
assert(AoM.KnownLibraries, "KnownLibraries.lua must be loaded before this file")

function AoM.GetOptionalLibsFor(addonName)
	local decl = LibAPH.registered_dependencies and LibAPH.registered_dependencies[addonName]
	local libs = {}
	if decl then
		for lib_name in pairs(decl.optional) do table.insert(libs, lib_name) end
	elseif AoM.KnownAddonDependencies[addonName] then
		for _, lib_name in ipairs(AoM.KnownAddonDependencies[addonName]) do table.insert(libs, lib_name) end
	end
	table.sort(libs)
	return libs
end

local function FormatLibraryStatus(am, lib_name, min_version, show_version)
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, enabled, state = am:GetAddOnInfo(i)
		if name == lib_name then
			local ver = am:GetAddOnVersion(i)
			local ver_suffix = show_version and LibAPH.FormatVersionBare(ver) or ""
			if enabled and state == ADDON_STATE_ENABLED then
				if min_version and min_version > 0 and ver < min_version then
					return "|cFFA500" .. lib_name .. ver_suffix .. "|r"
				end
				return "|c00FF00" .. lib_name .. ver_suffix .. "|r"
			end
			return "|cFF0000" .. lib_name .. ver_suffix .. "|r"
		end
	end
	return "|c888888" .. lib_name .. " (not installed)|r"
end

local function GetRequiredLibsInfo(am, addon_index)
	local list = {}
	for d = 1, am:GetAddOnNumDependencies(addon_index) do
		local dep_name, _, _, minVersion = am:GetAddOnDependencyInfo(addon_index, d)
		table.insert(list, { name = dep_name, minVersion = minVersion })
	end
	return list
end

local function AddTitleLine(tooltip, text)
	local r, g, b = ZO_SELECTED_TEXT:UnpackRGB()
	tooltip:AddLine(text, "ZoFontHeader3", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end
local function AddSubTitleLine(tooltip, text)
	local r, g, b = ZO_SELECTED_TEXT:UnpackRGB()
	tooltip:AddLine(text, "ZoFontWinH5", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end
local function AddCenterLine(tooltip, text)
	local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()
	tooltip:AddLine(text, "", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end

function AoM.FindAddonIndex(am, addonName)
	for i = 1, am:GetNumAddOns() do
		if am:GetAddOnInfo(i) == addonName then return i end
	end
	return nil
end

function AoM.GetLibrarySections(am, index, addonName)
	local sections = {}
	if index then
		local required = GetRequiredLibsInfo(am, index)
		if #required > 0 then
			local parts = {}
			for _, r in ipairs(required) do
				table.insert(parts, FormatLibraryStatus(am, r.name, r.minVersion, true))
			end
			table.insert(sections, { title = #required > 1 and "Required libraries:" or "Required library:", text = table.concat(parts, ", ") })
		end
	end

	local optional_real_libs, optional_addons = {}, {}
	for _, lib_name in ipairs(AoM.GetOptionalLibsFor(addonName)) do
		if string.sub(lib_name, 1, 3) == "Lib" then
			table.insert(optional_real_libs, lib_name)
		else
			table.insert(optional_addons, lib_name)
		end
	end

	if #optional_real_libs > 0 then
		local parts = {}
		for _, lib_name in ipairs(optional_real_libs) do
			table.insert(parts, FormatLibraryStatus(am, lib_name, nil, false))
		end
		table.insert(sections, { title = #optional_real_libs > 1 and "Optional libraries:" or "Optional library:", text = table.concat(parts, ", ") })
	end

	if #optional_addons > 0 then
		local parts = {}
		for _, lib_name in ipairs(optional_addons) do
			table.insert(parts, FormatLibraryStatus(am, lib_name, nil, false))
		end
		table.insert(sections, { title = #optional_addons > 1 and "Optional add-on dependencies:" or "Optional add-on dependency:", text = table.concat(parts, ", ") })
	end
	return sections
end

local function AddLibrarySections(tooltip, am, data)
	for _, section in ipairs(AoM.GetLibrarySections(am, data.index, data.addOnFileName)) do
		AddSubTitleLine(tooltip, section.title)
		AddCenterLine(tooltip, section.text)
	end
end


function AoM.PopulateAddonInfoTooltip(tooltip, data)
	local am = GetAddOnManager()

	AddTitleLine(tooltip, data.addOnName)
	if data.index then
		local ver = am:GetAddOnVersion(data.index)
		if ver and ver > 0 then
			AddSubTitleLine(tooltip, "Version " .. ver)
		end
	end
	if data.isOutOfDate ~= nil then
		if data.isOutOfDate then
			AddCenterLine(tooltip, "|cFF0000Out of Date|r")
		else
			AddCenterLine(tooltip, "|c00FF00API " .. GetAPIVersion() .. " (Up to Date)|r")
		end
	end
	ZO_Tooltip_AddDivider(tooltip)
	if data.addOnAuthorByLine and data.addOnAuthorByLine ~= "" then
		AddSubTitleLine(tooltip, data.addOnAuthorByLine)
	end
	if data.addOnDescription and data.addOnDescription ~= "" then
		AddCenterLine(tooltip, data.addOnDescription)
	end
	if data.index then
		AddCenterLine(tooltip, am:GetAddOnRootDirectoryPath(data.index))
	end
	AddLibrarySections(tooltip, am, data)
end

function AoM.PopulateAddonInfoTooltipByName(tooltip, addonName)
	local am = GetAddOnManager()
	local i = AoM.FindAddonIndex(am, addonName)
	if not i then return end
	local name, title, author, description, _, _, isOutOfDate = am:GetAddOnInfo(i)
	AoM.PopulateAddonInfoTooltip(tooltip, {
		addOnFileName = name,
		addOnName = title,
		index = i,
		isOutOfDate = isOutOfDate,
		addOnAuthorByLine = author ~= "" and zo_strformat(SI_ADD_ON_AUTHOR_LINE, author) or "",
		addOnDescription = description,
	})
end

local STATUS_COLOR_ERROR = { 1, 0.15, 0.15 }
local STATUS_COLOR_OUT_OF_DATE = { 1, 0.82, 0.1 }
local STATUS_COLOR_DEPENDENCY_ERROR = { 1, 0.55, 0.1 }
local STATUS_COLOR_OPTIONAL_DEPENDENCY = { 0.4, 0.75, 1 }
local STATUS_COLOR_USED_AS_DEPENDENCY = { 0.7, 0.5, 1 }
local STATUS_COLOR_PATCH_ADDON = { 0.3, 0.9, 0.3 }

local TIME_SYNC_ERROR_CODES = { [0x32BBA739] = true, [0xEA5D75AD] = true }
local captured_lua_errors = {}

EVENT_MANAGER:RegisterForEvent("AoM_AddonManagerErrorCapture", EVENT_LUA_ERROR, function(_, errorString, errorCode)
	if type(errorString) ~= "string" then return end
	if TIME_SYNC_ERROR_CODES[errorCode] then return end
	table.insert(captured_lua_errors, errorString)
	if #captured_lua_errors > 100 then table.remove(captured_lua_errors, 1) end
end)

local function GetCapturedErrorsForAddon(am, index)
	local root_path = am:GetAddOnRootDirectoryPath(index)
	if not root_path or root_path == "" then return {} end
	local matches = {}
	for _, err in ipairs(captured_lua_errors) do
		if string.find(err, root_path, 1, true) then
			table.insert(matches, err)
		end
	end
	return matches
end

local addon_dependents = {}
local addon_patch_targets = {}

local dependency_index_built = false

local function RebuildDependencyIndex()
	dependency_index_built = true
	addon_dependents = {}
	addon_patch_targets = {}
	local am = GetAddOnManager()
	for i = 1, am:GetNumAddOns() do
		local name = am:GetAddOnInfo(i)
		local non_library_deps = {}
		for d = 1, am:GetAddOnNumDependencies(i) do
			local dep_name = am:GetAddOnDependencyInfo(i, d)
			if dep_name then
				addon_dependents[dep_name] = addon_dependents[dep_name] or {}
				table.insert(addon_dependents[dep_name], name)
				if not LibAPH.IsLibraryAddonByName(am, dep_name) then
					table.insert(non_library_deps, dep_name)
				end
			end
		end
		if #non_library_deps > 0 then addon_patch_targets[name] = non_library_deps end
	end
end

local function GetDependencyIssues(am, index)
	local issues = {}
	for d = 1, am:GetAddOnNumDependencies(index) do
		local dep_name, dep_exists, dep_active, dep_min_version, dep_version = am:GetAddOnDependencyInfo(index, d)
		if not dep_exists or not dep_active or dep_version < dep_min_version then
			table.insert(issues, FormatLibraryStatus(am, dep_name, dep_min_version, true))
		end
	end
	return issues
end

local function GetInactiveOptionalLibs(am, addonName)
	local inactive = {}
	for _, lib_name in ipairs(AoM.GetOptionalLibsFor(addonName)) do
		if not LibAPH.IsAddonActiveAndRunning(lib_name) then
			table.insert(inactive, FormatLibraryStatus(am, lib_name, nil, true))
		end
	end
	return inactive
end

local function GetUpdateHint()
	if IsConsoleUI() or IsInGamepadPreferredMode() then
		return "Please check for an update."
	end
	return "Run Minion and check for an update."
end

function AoM.GetStatusIconsForAddon(am, index)
	if not dependency_index_built then RebuildDependencyIndex() end
	local update_hint = GetUpdateHint()
	local name, _, _, _, _, addon_state, is_out_of_date = am:GetAddOnInfo(index)
	local icons = {}
	local function Add(color, tooltipText)
		table.insert(icons, { color = color, tooltip = tooltipText })
	end

	if addon_state == ADDON_STATE_ERROR_STATE_UNABLE_TO_LOAD then
		Add(STATUS_COLOR_ERROR, "This add-on failed to load - the game reports an error state for it.")
	else
		local session_errors = GetCapturedErrorsForAddon(am, index)
		if #session_errors > 0 then
			Add(STATUS_COLOR_ERROR, "This add-on threw a Lua error this session (captured even if not shown on screen):\n" .. session_errors[#session_errors])
		end
	end

	local known = AoM.KnownLibraries[name] or AoM.KnownAddonVersions[name]
	local installed = am:GetAddOnVersion(index)
	local newer_on_esoui = known and known.requiredVersion and installed > 0 and installed < known.requiredVersion
	if is_out_of_date or newer_on_esoui then
		local lines = {}
		if is_out_of_date then
			table.insert(lines, "Out of date for the current API version.")
		end
		if newer_on_esoui then
			table.insert(lines, "A newer version was published on ESOUI when this add-on's data was last refreshed.")
			table.insert(lines, string.format("ESOUI: v%s (%d)", known.displayVersion or tostring(known.requiredVersion), known.requiredVersion))
			table.insert(lines, string.format("Installed: %d", installed))
		end
		if known and known.esouiId then
			table.insert(lines, "esoui.com/downloads/info" .. known.esouiId)
		end
		Add(STATUS_COLOR_OUT_OF_DATE, table.concat(lines, "\n") .. "\n\n" .. update_hint)
	end

	local issues = GetDependencyIssues(am, index)
	if #issues > 0 then
		Add(STATUS_COLOR_DEPENDENCY_ERROR, "Missing or disabled required dependency:\n" .. table.concat(issues, "\n") .. "\n\nEnable or download the missing dependency.")
	end

	local inactive_optional = GetInactiveOptionalLibs(am, name)
	if #inactive_optional > 0 then
		Add(STATUS_COLOR_OPTIONAL_DEPENDENCY, "Has an optional dependency for additional features:\n" .. table.concat(inactive_optional, ", "))
	end

	local dependents = addon_dependents[name]
	if dependents and #dependents > 0 then
		local formatted_dependents = {}
		for _, dependent_name in ipairs(dependents) do
			table.insert(formatted_dependents, FormatLibraryStatus(am, dependent_name, nil, true))
		end
		Add(STATUS_COLOR_USED_AS_DEPENDENCY, "Used as a dependency by:\n" .. table.concat(formatted_dependents, ", "))
	end

	local patch_targets = addon_patch_targets[name]
	if patch_targets then
		local formatted_targets = {}
		for _, target_name in ipairs(patch_targets) do
			table.insert(formatted_targets, FormatLibraryStatus(am, target_name, nil, true))
		end
		Add(STATUS_COLOR_PATCH_ADDON, "Patch add-on - depends on another add-on that is not a library:\n" .. table.concat(formatted_targets, ", "))
	end

	return icons
end

function AoM.GetStatusIconsForAddonByName(am, addonName)
	local i = AoM.FindAddonIndex(am, addonName)
	if i then return AoM.GetStatusIconsForAddon(am, i) end
	return {}
end
