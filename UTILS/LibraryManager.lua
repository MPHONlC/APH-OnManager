-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
local AoM = AoMCore
assert(AoM.KnownLibraries, "KnownLibraries.lua must be loaded before this file")
assert(AoM.KnownAddonDependencies, "KnownAddonDependencies.lua must be loaded before this file")
local LibAPH = LibAPH
local KnownLibraries = AoM.KnownLibraries
local KnownAddonDependencies = AoM.KnownAddonDependencies

local function ScanOptionalLibraries()
	local am = GetAddOnManager()
	local num = am:GetNumAddOns()

	local addon_index_by_name = {}
	local library_addons = {}
	for i = 1, num do
		local name, _, _, _, enabled, _, _, isLibrary = am:GetAddOnInfo(i)
		addon_index_by_name[name] = i
		if isLibrary then
			library_addons[name] = { index = i, version = am:GetAddOnVersion(i), enabled = enabled }
		end
	end

	local referenced = {}
	local addon_dependency_report = {}

	for i = 1, num do
		local name, _, _, _, enabled, state = am:GetAddOnInfo(i)
		if enabled and state == ADDON_STATE_ENABLED then
			local num_deps = am:GetAddOnNumDependencies(i)
			local this_addon_deps = {}
			for d = 1, num_deps do
				local dep_name, exists, active, _, version = am:GetAddOnDependencyInfo(i, d)
				if exists then
					referenced[dep_name] = true
					table.insert(this_addon_deps, { name = dep_name, active = active, version = version })
				end
			end
			if #this_addon_deps > 0 then
				addon_dependency_report[name] = this_addon_deps
			end
		end
	end

	local enable_candidates = {}
	local active_optional_by_lib = {}
	local missing_optional_by_lib = {}

	local function ProcessOptionalDependency(addon_name, lib_name)
		referenced[lib_name] = true
		local lib_idx = addon_index_by_name[lib_name]
		if lib_idx then
			local _, _, _, _, lib_enabled, lib_state = am:GetAddOnInfo(lib_idx)
			if lib_enabled and lib_state == ADDON_STATE_ENABLED then
				active_optional_by_lib[lib_name] = active_optional_by_lib[lib_name]
					or { name = lib_name, version = am:GetAddOnVersion(lib_idx), addons = {} }
				table.insert(active_optional_by_lib[lib_name].addons, addon_name)
			else
				table.insert(enable_candidates, { library = lib_name, forAddon = addon_name })
			end
		else
			missing_optional_by_lib[lib_name] = missing_optional_by_lib[lib_name] or { name = lib_name, addons = {} }
			table.insert(missing_optional_by_lib[lib_name].addons, addon_name)
		end
	end

	for addon_name, decl in pairs(LibAPH.registered_dependencies) do
		for lib_name in pairs(decl.required) do
			referenced[lib_name] = true
		end
		for lib_name in pairs(decl.optional) do
			ProcessOptionalDependency(addon_name, lib_name)
		end
	end

	for addon_name, optional_libs in pairs(KnownAddonDependencies) do
		if not LibAPH.registered_dependencies[addon_name] then
			local addon_idx = addon_index_by_name[addon_name]
			if addon_idx then
				local _, _, _, _, addon_enabled, addon_state = am:GetAddOnInfo(addon_idx)
				if addon_enabled and addon_state == ADDON_STATE_ENABLED then
					for _, lib_name in ipairs(optional_libs) do
						ProcessOptionalDependency(addon_name, lib_name)
					end
				end
			end
		end
	end

	local function IsAddonFullyEnabled(idx)
		local _, _, _, _, en, st = am:GetAddOnInfo(idx)
		return en and st == ADDON_STATE_ENABLED
	end

	local potential_required_by, potential_optional_by = {}, {}
	for i = 1, num do
		if not IsAddonFullyEnabled(i) then
			local name = am:GetAddOnInfo(i)
			for d = 1, am:GetAddOnNumDependencies(i) do
				local dep_name, exists = am:GetAddOnDependencyInfo(i, d)
				if exists then
					potential_required_by[dep_name] = potential_required_by[dep_name] or {}
					table.insert(potential_required_by[dep_name], name)
				end
			end
		end
	end
	for addon_name, optional_libs in pairs(KnownAddonDependencies) do
		local addon_idx = addon_index_by_name[addon_name]
		if not addon_idx or not IsAddonFullyEnabled(addon_idx) then
			for _, lib_name in ipairs(optional_libs) do
				potential_optional_by[lib_name] = potential_optional_by[lib_name] or {}
				table.insert(potential_optional_by[lib_name], addon_name)
			end
		end
	end

	local unused_libraries = {}
	for lib_name, data in pairs(library_addons) do
		if data.enabled and not referenced[lib_name] then
			table.insert(unused_libraries, {
				name = lib_name, version = data.version, index = data.index,
				potential_required_by = potential_required_by[lib_name],
				potential_optional_by = potential_optional_by[lib_name],
			})
		end
	end

	local broken_addons = {}
	for i = 1, num do
		local name, _, _, _, enabled = am:GetAddOnInfo(i)
		if enabled then
			local missing_deps = {}
			for d = 1, am:GetAddOnNumDependencies(i) do
				local dep_name, exists = am:GetAddOnDependencyInfo(i, d)
				if not exists then
					table.insert(missing_deps, dep_name)
				end
			end
			if #missing_deps > 0 then
				table.insert(broken_addons, { name = name, missing = missing_deps })
			end
		end
	end
	table.sort(broken_addons, function(a, b) return a.name < b.name end)

	local active_optional_libraries = {}
	for _, entry in pairs(active_optional_by_lib) do
		table.insert(active_optional_libraries, entry)
	end
	table.sort(active_optional_libraries, function(a, b) return a.name < b.name end)

	local missing_optional_libraries = {}
	for _, entry in pairs(missing_optional_by_lib) do
		table.insert(missing_optional_libraries, entry)
	end
	table.sort(missing_optional_libraries, function(a, b) return a.name < b.name end)

	return {
		enable_candidates = enable_candidates,
		unused_libraries = unused_libraries,
		active_optional_libraries = active_optional_libraries,
		missing_optional_libraries = missing_optional_libraries,
		broken_addons = broken_addons,
		addon_dependency_report = addon_dependency_report,
		addon_index_by_name = addon_index_by_name,
	}
end

local function ApplyOptionalLibraryChoice(to_enable, to_disable)
	local am = GetAddOnManager()
	local acted = { enabled = {}, disabled = {} }

	for _, e in ipairs(to_enable) do
		am:SetAddOnEnabled(e.index, true)
		table.insert(acted.enabled, e.name)
	end
	for _, u in ipairs(to_disable) do
		am:SetAddOnEnabled(u.index, false)
		table.insert(acted.disabled, { name = u.name, version = u.version })
	end

	AoM.saved.pending_optional_report = acted
	ReloadUI("ingame")
end

local SECTION_HEADER_COLOR = { 0.83, 0.92, 0.42, 1 }
local ITEM_COLOR = { 0.85, 0.85, 0.85, 1 }
local MISSING_COLOR = { 0.53, 0.53, 0.53, 1 }
local UNUSED_COLOR = { 1, 0.3, 0.3, 1 }
local ENABLE_CANDIDATE_COLOR = { 1, 0.65, 0.2, 1 }
local BROKEN_COLOR = { 1, 0.3, 0.3, 1 }

local function BuildUnusedTooltip(u)
	local parts = {}
	if u.potential_required_by then
		table.insert(parts, "Required by (disabled):\n" .. table.concat(u.potential_required_by, "\n"))
	end
	if u.potential_optional_by then
		table.insert(parts, "Optional for (disabled):\n" .. table.concat(u.potential_optional_by, "\n"))
	end
	if #parts == 0 then
		return "Not wanted by any installed add-on."
	end
	return table.concat(parts, "\n\n") .. "\n\n(all disabled - that's why this shows as unused)"
end

local function ColorAddonNameList(report, addons)
	local am = GetAddOnManager()
	local colored = {}
	for _, name in ipairs(addons) do
		local idx = report.addon_index_by_name[name]
		local enabled, state
		if idx then
			local _, _, _, _, e, s = am:GetAddOnInfo(idx)
			enabled, state = e, s
		end
		if enabled and state == ADDON_STATE_ENABLED then
			table.insert(colored, "|c00FF00" .. name .. "|r")
		else
			table.insert(colored, "|cFF0000" .. name .. "|r")
		end
	end
	return table.concat(colored, "\n")
end

local function GroupByLibrary(entries, getLibName, getAddonName)
	local grouped = {}
	for _, e in ipairs(entries) do
		local lib_name = getLibName(e)
		grouped[lib_name] = grouped[lib_name] or { name = lib_name, addons = {} }
		table.insert(grouped[lib_name].addons, getAddonName(e))
	end
	local list = {}
	for _, g in pairs(grouped) do table.insert(list, g) end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

local optional_library_window

local function GetOptionalLibraryWindow()
	if optional_library_window then return optional_library_window end
	optional_library_window = LibAPH.CreateScrollListWindow({
		name = "AoM_OptionalLibraryWindow",
		widthPct = 0.36, heightPct = 0.6,
		minWidth = 580, maxWidth = 950,
		minHeight = 460, maxHeight = 860,
		footerHeight = 44,
		titleText = "|c9CD04CAPH-On Manager|r Library Manager",
	})

	optional_library_window.check_all_btn = LibAPH.CreateKeybindLabelButton(optional_library_window.footer, {
		action = "AOM_SELECT_ALL_LIBRARIES",
		layer = AoM.LIBRARIES_KEYBIND_LAYER,
		name = "Select All",
	})
	optional_library_window.check_all_btn:SetAnchor(TOPLEFT, optional_library_window.footer, TOPLEFT, 0, 0)

	optional_library_window.uncheck_all_btn = LibAPH.CreateKeybindLabelButton(optional_library_window.footer, {
		action = "AOM_DESELECT_ALL_LIBRARIES",
		layer = AoM.LIBRARIES_KEYBIND_LAYER,
		name = "Deselect All",
	})
	optional_library_window.uncheck_all_btn:SetAnchor(TOPLEFT, optional_library_window.check_all_btn, TOPRIGHT, 20, 0)

	optional_library_window.apply_btn = LibAPH.CreateKeybindLabelButton(optional_library_window.footer, {
		action = "AOM_APPLY_LIBRARY_CHANGES",
		layer = AoM.LIBRARIES_KEYBIND_LAYER,
		name = "Apply Changes",
	})
	optional_library_window.apply_btn:SetAnchor(TOPLEFT, optional_library_window.uncheck_all_btn, TOPRIGHT, 20, 0)

	return optional_library_window
end

local function RunOptionalLibraryWizard()
	local report = ScanOptionalLibraries()

	if #report.enable_candidates == 0 and #report.unused_libraries == 0 then
		if optional_library_window then optional_library_window:Hide() end
		if #report.active_optional_libraries > 0 or #report.missing_optional_libraries > 0 or #report.broken_addons > 0 then
			local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")
			logger:Print("Nothing to enable or clean up.")
			if #report.active_optional_libraries > 0 then
				logger:Print("Enabled optional libraries currently in use:")
				for _, lib in ipairs(report.active_optional_libraries) do
					logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version) .. " - used by " .. table.concat(lib.addons, ", "))
				end
			end
			if #report.missing_optional_libraries > 0 then
				logger:Print("Not installed, but could be used by:")
				for _, lib in ipairs(report.missing_optional_libraries) do
					logger:Print("  " .. lib.name .. " - wanted by " .. table.concat(lib.addons, ", "))
				end
			end
			if #report.broken_addons > 0 then
				logger:Print("Enabled but missing a required library - won't load until installed:")
				for _, a in ipairs(report.broken_addons) do
					logger:Print("  " .. a.name .. " - needs " .. table.concat(a.missing, ", "))
				end
			end
		else
			d("|c9CD04C[AoM]|r No optional libraries to offer, and nothing unreferenced to clean up.")
		end
		return
	end

	local enable_list = GroupByLibrary(report.enable_candidates, function(c) return c.library end, function(c) return c.forAddon end)
	local unused_list = {}
	for _, u in ipairs(report.unused_libraries) do table.insert(unused_list, u) end
	table.sort(unused_list, function(a, b) return a.name < b.name end)

	local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")
	if #unused_list > 0 then
		logger:Print("Enabled but nothing currently references these - Decline below will disable them:")
		for _, u in ipairs(unused_list) do
			local detail
			if u.potential_required_by then
				detail = " (required by disabled " .. table.concat(u.potential_required_by, ", ") .. ")"
			elseif u.potential_optional_by then
				detail = " (optional for disabled " .. table.concat(u.potential_optional_by, ", ") .. ")"
			else
				detail = " (nothing installed wants this, enabled or disabled)"
			end
			logger:Print("  " .. u.name .. LibAPH.FormatVersionParen(u.version) .. detail)
		end
	end
	if #report.active_optional_libraries > 0 then
		logger:Print("Enabled optional libraries currently in use (not offered for disable here):")
		for _, lib in ipairs(report.active_optional_libraries) do
			logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version) .. " - used by " .. table.concat(lib.addons, ", "))
		end
	end
	if #report.missing_optional_libraries > 0 then
		logger:Print("Not installed, but could be used by:")
		for _, lib in ipairs(report.missing_optional_libraries) do
			logger:Print("  " .. lib.name .. " - wanted by " .. table.concat(lib.addons, ", "))
		end
	end
	if #report.broken_addons > 0 then
		logger:Print("Enabled but missing a required library - won't load until installed:")
		for _, a in ipairs(report.broken_addons) do
			logger:Print("  " .. a.name .. " - needs " .. table.concat(a.missing, ", "))
		end
	end

	local rows = {}
	local function AddHeader(text)
		table.insert(rows, { text = text, color = SECTION_HEADER_COLOR, is_header = true })
	end
	local function AddItem(text, tooltip, color)
		table.insert(rows, { text = "  " .. text, color = color or ITEM_COLOR, tooltip = tooltip })
	end

	if #enable_list > 0 then
		AddHeader("Installed add-ons could use these optional libraries, currently off (check ones to enable):")
		for _, g in ipairs(enable_list) do
			table.insert(rows, {
				text = "  " .. g.name,
				color = ENABLE_CANDIDATE_COLOR,
				tooltip = "Wanted by:\n" .. ColorAddonNameList(report, g.addons),
				checkable = true, checked = false, kind = "enable",
				index = report.addon_index_by_name[g.name], name = g.name,
			})
		end
	end
	if #unused_list > 0 then
		AddHeader("Enabled but nothing currently references these (check ones to disable):")
		for _, u in ipairs(unused_list) do
			table.insert(rows, {
				text = "  " .. u.name .. LibAPH.FormatVersionParen(u.version),
				color = UNUSED_COLOR,
				tooltip = BuildUnusedTooltip(u),
				checkable = true, checked = false, kind = "disable",
				index = u.index, name = u.name, version = u.version,
			})
		end
	end
	if #report.active_optional_libraries > 0 then
		AddHeader("Enabled optional libraries in use (hover for which add-on):")
		for _, lib in ipairs(report.active_optional_libraries) do
			AddItem(lib.name .. LibAPH.FormatVersionParen(lib.version), "Used by:\n" .. ColorAddonNameList(report, lib.addons))
		end
	end
	if #report.missing_optional_libraries > 0 then
		AddHeader("Not installed, but could be used by (hover for which add-on):")
		for _, lib in ipairs(report.missing_optional_libraries) do
			AddItem(lib.name, "Wanted by:\n" .. ColorAddonNameList(report, lib.addons), MISSING_COLOR)
		end
	end
	if #report.broken_addons > 0 then
		AddHeader("Enabled but missing a required library - won't load until installed (hover for which):")
		for _, a in ipairs(report.broken_addons) do
			AddItem(a.name, "Missing required library:\n" .. table.concat(a.missing, "\n"), BROKEN_COLOR)
		end
	end

	local win = GetOptionalLibraryWindow()
	win:SetRows(rows)
	win:SetSubtitle("Check a library to enable it, or to disable it in the unused section, then Apply Changes.")
	win.check_all_btn.libaph_click_action = function() win:SetAllChecked(true) end
	win.uncheck_all_btn.libaph_click_action = function() win:SetAllChecked(false) end
	win.apply_btn.libaph_click_action = function()
		local to_enable, to_disable = {}, {}
		for _, row in ipairs(rows) do
			if row.checkable and row.index then
				if row.kind == "enable" and row.checked then
					table.insert(to_enable, { index = row.index, name = row.name })
				elseif row.kind == "disable" and row.checked then
					table.insert(to_disable, { index = row.index, name = row.name, version = row.version })
				end
			end
		end
		win:Hide()
		ApplyOptionalLibraryChoice(to_enable, to_disable)
	end
	win:Show()
end

function AoM.ReportPendingOptionalLibraryChanges()
	local pending = AoM.saved and AoM.saved.pending_optional_report
	if not pending then return end
	AoM.saved.pending_optional_report = nil

	local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")

	if #pending.disabled > 0 then
		logger:Print("Disabled optional libraries nothing currently references:")
		for _, lib in ipairs(pending.disabled) do
			logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version))
		end
	end
	if #pending.enabled > 0 then
		logger:Print("Enabled optional libraries:")
		for _, name in ipairs(pending.enabled) do
			logger:Print("  " .. name)
		end
	end

	local report = ScanOptionalLibraries()

	local addon_names = {}
	for addon_name in pairs(report.addon_dependency_report) do table.insert(addon_names, addon_name) end
	table.sort(addon_names)

	if #addon_names > 0 then
		logger:Print("Enabled add-ons' required library versions:")
		for _, addon_name in ipairs(addon_names) do
			local active_deps = {}
			for _, dep in ipairs(report.addon_dependency_report[addon_name]) do
				if dep.active then table.insert(active_deps, dep) end
			end
			if #active_deps > 0 then
				logger:Print("  " .. addon_name .. ":")
				for _, dep in ipairs(active_deps) do
					local libData = KnownLibraries[dep.name]
					local versionText
					if not dep.version or dep.version <= 0 then
						versionText = "|c888888(version unknown)|r"
					elseif libData then
						local color, plus, label = LibAPH.GetLibraryDriftColor(dep.version, libData.requiredVersion)
						versionText = color .. "v" .. dep.version .. plus .. label .. "|r"
					else
						versionText = "|c888888v" .. dep.version .. " (unknown)|r"
					end
					logger:Print("    " .. dep.name .. ": " .. versionText)
				end
			end
		end
	end

	if #report.active_optional_libraries > 0 then
		logger:Print("Enabled optional libraries currently in use:")
		for _, lib in ipairs(report.active_optional_libraries) do
			logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version) .. " - used by " .. table.concat(lib.addons, ", "))
		end
	end

	if #report.unused_libraries > 0 then
		logger:Print("Still enabled but unreferenced by any add-on:")
		for _, u in ipairs(report.unused_libraries) do
			logger:Print("  " .. u.name .. LibAPH.FormatVersionParen(u.version))
		end
	end

	if #report.missing_optional_libraries > 0 then
		logger:Print("Not installed, but could be used by:")
		for _, lib in ipairs(report.missing_optional_libraries) do
			logger:Print("  " .. lib.name .. " - wanted by " .. table.concat(lib.addons, ", "))
		end
	end

	if #report.broken_addons > 0 then
		logger:Print("Enabled but missing a required library - won't load until installed:")
		for _, a in ipairs(report.broken_addons) do
			logger:Print("  " .. a.name .. " - needs " .. table.concat(a.missing, ", "))
		end
	end
end

SLASH_COMMANDS["/libcheck"] = function()
	RunOptionalLibraryWizard()
end
