-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
local AoM = AoMCore
local LibAPH = LibAPH

local ADDON_DATA = 1
local HEADER_DATA = 2
local LIBRARIES = "Libraries"
local GAMEPAD_STATUS_ICON_SIZE = 24
local TEXT_ENTRY_DIALOG = "AoM_GAMEPAD_TEXT_ENTRY"
local PICKER_DIALOG = "AoM_GAMEPAD_PICKER"
local OPTIONS_DIALOG = "ADDON_MANAGER_OPTIONS_GAMEPAD"

local am = GetAddOnManager()

local SORT_KEYS = {
	addOnFileName = {},
	strippedAddOnName = { tiebreaker = "addOnFileName" },
}

local function SortAddons(entry1, entry2)
	return ZO_TableOrderingFunction(entry1, entry2, "strippedAddOnName", SORT_KEYS, ZO_SORT_ORDER_UP)
end

local function IsAddonEnabled(index)
	local _, _, _, _, enabled = am:GetAddOnInfo(index)
	return enabled
end

local function ColorToHex(color)
	return string.format("%02X%02X%02X", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

local function ShowGamepadDialog(dialogId, data)
	ZO_Dialogs_ShowGamepadDialog(dialogId, data)
end

local function ReleaseDialog(dialogId)
	ZO_Dialogs_ReleaseDialogOnButtonPress(dialogId)
end

local function SetupSubmitEntry(control, data, selected, reselectingDuringRebuild, enabled, active)
	local isValid = enabled
	if data.validInput then
		isValid = data.validInput()
		data.disabled = not isValid
		data:SetEnabled(isValid)
	end
	ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, isValid, active)
end

local text_entry_state = { text = "" }

local function RegisterTextEntryDialog()
	if ESO_Dialogs[TEXT_ENTRY_DIALOG] then return end
	ZO_Dialogs_RegisterCustomDialog(TEXT_ENTRY_DIALOG, {
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
		canQueue = true,
		blockDialogReleaseOnPress = true,
		setup = function(dialog)
			text_entry_state.text = dialog.data.initialText or ""
			dialog:setupFunc()
		end,
		title = { text = function(dialog) return dialog.data.title end },
		mainText = { text = function(dialog) return dialog.data.prompt or "" end },
		parametricList = {
			{
				template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
				templateData = {
					nameField = true,
					textChangedCallback = function(control)
						text_entry_state.text = control:GetText()
					end,
					setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
						control.highlight:SetHidden(not selected)
						control.editBoxControl.textChangedCallback = data.textChangedCallback
						control.editBoxControl:SetMaxInputChars(60)
						control.editBoxControl:SetDefaultText(data.dialog.data.prompt or "")
						control.editBoxControl:SetText(text_entry_state.text)
						data.control = control
					end,
					callback = function(dialog)
						local data = dialog.entryList:GetTargetData()
						if data and data.control then data.control.editBoxControl:TakeFocus() end
					end,
					narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
				},
			},
			{
				template = "ZO_GamepadTextFieldSubmitItem",
				templateData = {
					text = GetString(SI_DIALOG_CONFIRM),
					setup = SetupSubmitEntry,
					validInput = function() return text_entry_state.text ~= "" end,
					callback = function(dialog)
						local text = text_entry_state.text
						local onConfirm = dialog.data.onConfirm
						ReleaseDialog(TEXT_ENTRY_DIALOG)
						if text ~= "" and onConfirm then onConfirm(text) end
					end,
				},
			},
		},
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = SI_GAMEPAD_SELECT_OPTION,
				callback = function(dialog)
					local data = dialog.entryList:GetTargetData()
					if data and data.callback then data.callback(dialog) end
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = SI_DIALOG_CANCEL,
				callback = function(dialog)
					local onCancel = dialog.data.onCancel
					ReleaseDialog(TEXT_ENTRY_DIALOG)
					if onCancel then onCancel() end
				end,
			},
		},
		noChoiceCallback = function(dialog)
			if dialog.data and dialog.data.onCancel then dialog.data.onCancel() end
		end,
	})
end

function AoM.ShowGamepadTextEntryDialog(title, prompt, initialText, onConfirm, onCancel)
	RegisterTextEntryDialog()
	ShowGamepadDialog(TEXT_ENTRY_DIALOG, { title = title, prompt = prompt, initialText = initialText, onConfirm = onConfirm, onCancel = onCancel })
end

local function RegisterPickerDialog()
	if ESO_Dialogs[PICKER_DIALOG] then return end
	ZO_Dialogs_RegisterCustomDialog(PICKER_DIALOG, {
		gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
		canQueue = true,
		blockDialogReleaseOnPress = true,
		setup = function(dialog)
			local entries = dialog.info.parametricList
			ZO_ClearNumericallyIndexedTable(entries)
			for _, choice in ipairs(dialog.data.choices) do
				table.insert(entries, {
					template = "ZO_GamepadFullWidthLeftLabelEntryTemplate",
					templateData = {
						text = choice.text,
						setup = ZO_SharedGamepadEntry_OnSetup,
						callback = function()
							ReleaseDialog(PICKER_DIALOG)
							choice.callback()
						end,
					},
				})
			end
			dialog:setupFunc()
		end,
		title = { text = function(dialog) return dialog.data.title end },
		parametricList = {},
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = SI_GAMEPAD_SELECT_OPTION,
				callback = function(dialog)
					local data = dialog.entryList:GetTargetData()
					if data and data.callback then data.callback(dialog) end
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = SI_DIALOG_CANCEL,
				callback = function() ReleaseDialog(PICKER_DIALOG) end,
			},
		},
	})
end

local function ShowGamepadPickerDialog(title, choices)
	RegisterPickerDialog()
	ShowGamepadDialog(PICKER_DIALOG, { title = title, choices = choices })
end

local function BuildCategoryGroups(manager)
	local groups, order = {}, {}
	for _, list in ipairs({ manager.addonList, manager.libraryList }) do
		for _, data in ipairs(list) do
			local category = AoM.GetAddonCategory(data.addOnFileName)
			if AoM.CategoryMatchesFilter(data.isLibrary, IsAddonEnabled(data.addOnIndex), category) then
				if not groups[category] then
					groups[category] = {}
					table.insert(order, category)
				end
				table.insert(groups[category], data)
			end
		end
	end
	table.sort(order, function(a, b)
		return string.lower(AoM.GetCategoryDisplayName(a)) < string.lower(AoM.GetCategoryDisplayName(b))
	end)
	return groups, order
end

ZO_PreHook(ZO_AddOnManager_Gamepad, "FilterScrollList", function(self)
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)
	local groups, order = BuildCategoryGroups(self)

	for _, category in ipairs(order) do
		local members = groups[category]
		table.sort(members, SortAddons)
		local header_name = AoM.GetCategoryDisplayName(category)
		table.insert(scrollData, ZO_ScrollList_CreateDataEntry(HEADER_DATA, ZO_EntryData:New({ name = header_name })))
		for i, data in ipairs(members) do
			local entryData = ZO_EntryData:New(data)
			entryData.headerText = (i == 1) and header_name or nil
			entryData.aom_category = category
			table.insert(scrollData, ZO_ScrollList_CreateDataEntry(ADDON_DATA, entryData))
		end
	end

	self.emptyLabel:SetHidden(#order > 0)
	return true
end)

local function UpdateGamepadStatusIcons(control, data)
	if not control.dependencyIcon then return end
	if not control.aom_status_icons then
		control.aom_status_icons = LibAPH.CreateStatusIconStrip(control, false, 7, GAMEPAD_STATUS_ICON_SIZE)
		for _, icon in ipairs(control.aom_status_icons) do
			icon:SetMouseEnabled(false)
		end
	end
	local icons = data.addOnIndex and AoM.GetStatusIconsForAddon(am, data.addOnIndex) or {}
	LibAPH.UpdateStatusIconStrip(control.aom_status_icons, control.dependencyIcon, icons, true, -6, LEFT)
end

ZO_PostHook(ZO_AddOnManager_Gamepad, "SetupRow", function(self, control, data)
	UpdateGamepadStatusIcons(control, data)
end)

local function AddStatusSection(tooltip, data)
	if not data.addOnIndex then return end
	local icons = AoM.GetStatusIconsForAddon(am, data.addOnIndex)
	local lines = {}
	for _, icon in ipairs(icons) do
		table.insert(lines, "|c" .. ColorToHex(icon.color) .. icon.tooltip .. "|r")
	end
	if #lines > 0 then
		local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
		section:AddLine("Status", tooltip:GetStyle("bodyHeader"))
		for _, line in ipairs(lines) do
			section:AddLine(line, tooltip:GetStyle("bodyDescription"))
		end
		tooltip:AddSection(section)
	end
end

local function AddLibrarySection(tooltip, data)
	for _, entry in ipairs(AoM.GetLibrarySections(am, data.addOnIndex, data.addOnFileName)) do
		local section = tooltip:AcquireSection(tooltip:GetStyle("bodySection"))
		section:AddLine(entry.title, tooltip:GetStyle("bodyHeader"))
		section:AddLine(entry.text, tooltip:GetStyle("bodyDescription"))
		tooltip:AddSection(section)
	end
end

local function HookGamepadTooltip()
	local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
	if not tooltip or tooltip.aom_tooltip_hooked then return end
	tooltip.aom_tooltip_hooked = true
	ZO_PostHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if not data or not data.addOnFileName then return end
		AddLibrarySection(tt, data)
		AddStatusSection(tt, data)
	end)
end

local function SuppressVotanUsedBySection()
	local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP)
	if not tooltip or tooltip.aom_votan_suppressed then return end
	if not LibAPH.IsAddonActiveAndRunning("LibVotansAddonList") then return end
	tooltip.aom_votan_suppressed = true
	ZO_PostHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if data and data.aom_stashed_used_by ~= nil then
			data.usedBy = data.aom_stashed_used_by
			data.aom_stashed_used_by = nil
		end
	end)
	ZO_PreHook(tooltip, "LayoutAddOnTooltip", function(tt, data)
		if data and data.usedBy ~= nil then
			data.aom_stashed_used_by = data.usedBy
			data.usedBy = nil
		end
	end)
end

local function GetAddonIndexMap()
	local map = {}
	for i = 1, am:GetNumAddOns() do
		map[am:GetAddOnInfo(i)] = i
	end
	return map
end

local function GetCategoryEntries(category)
	local index_by_name = GetAddonIndexMap()
	local entries = {}
	for _, name in ipairs(AoM.GetAddonsInCategory(category)) do
		if index_by_name[name] then table.insert(entries, { index = index_by_name[name] }) end
	end
	return entries
end

local function IsCategoryFullyEnabled(category)
	for _, entry in ipairs(GetCategoryEntries(category)) do
		if not IsAddonEnabled(entry.index) then return false end
	end
	return true
end

local search = { needle = nil, pos = 0 }

local function Notify(sound, text)
	if ZO_Alert then ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound, text) end
end

local function FindSearchMatches(manager)
	local matches = {}
	if not search.needle or search.needle == "" then return matches end
	local scrollData = ZO_ScrollList_GetDataList(manager.list)
	for i, entry in ipairs(scrollData) do
		local data = entry.data
		if data and data.addOnFileName and string.find(string.lower(data.strippedAddOnName or data.addOnName or ""), search.needle, 1, true) then
			table.insert(matches, i)
		end
	end
	return matches
end

local function SelectSearchMatch(manager, step)
	local matches = FindSearchMatches(manager)
	if #matches == 0 then
		Notify(SOUNDS.NEGATIVE_CLICK, "No add-on or library name contains \"" .. (search.needle or "") .. "\".")
		search.needle = nil
		search.pos = 0
		manager:UpdateKeybinds()
		return
	end
	search.pos = ((search.pos - 1 + step) % #matches) + 1
	local scrollData = ZO_ScrollList_GetDataList(manager.list)
	local data = scrollData[matches[search.pos]].data
	if not manager:IsActivated() then manager:Activate(true) end
	local ANIMATE_INSTANTLY = true
	ZO_ScrollList_SelectDataAndScrollIntoView(manager.list, data, nil, ANIMATE_INSTANTLY)
	manager:UpdateKeybinds()
	Notify(SOUNDS.DEFAULT_CLICK, string.format("Match %d of %d: %s", search.pos, #matches, data.strippedAddOnName or data.addOnName or data.addOnFileName))
end

local function WhenDialogsHidden(fn)
	if not ZO_Dialogs_IsShowingDialog() then
		fn()
		return
	end
	local function handler()
		CALLBACK_MANAGER:UnregisterCallback("AllDialogsHidden", handler)
		fn()
	end
	CALLBACK_MANAGER:RegisterCallback("AllDialogsHidden", handler)
end

local function StartSearch(manager, text)
	search.needle = string.lower(text or "")
	search.pos = 0
	if search.needle == "" then return end
	WhenDialogsHidden(function() SelectSearchMatch(manager, 1) end)
end

local function HasSearchMatches(manager)
	return search.needle ~= nil and #FindSearchMatches(manager) > 0
end

local function AddSearchKeybinds(manager)
	local strip = manager.keybindStripDescriptor
	if not strip or strip.aom_search_keybinds then return end
	strip.aom_search_keybinds = true
	table.insert(strip, {
		name = "Previous match",
		keybind = "UI_SHORTCUT_LEFT_SHOULDER",
		visible = function() return HasSearchMatches(manager) end,
		callback = function() SelectSearchMatch(manager, -1) end,
	})
	table.insert(strip, {
		name = "Next match",
		keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
		visible = function() return HasSearchMatches(manager) end,
		callback = function() SelectSearchMatch(manager, 1) end,
	})
end

local function MakeEntry(text, callback, opts)
	local entry = {
		template = "ZO_GamepadFullWidthLeftLabelEntryTemplate",
		templateData = {
			text = text,
			setup = ZO_SharedGamepadEntry_OnSetup,
			callback = function(dialog)
				ReleaseDialog(OPTIONS_DIALOG)
				callback(dialog)
			end,
		},
	}
	if opts then
		if opts.header then
			entry.headerTemplate = "ZO_GamepadMenuEntryFullWidthHeaderTemplate"
			entry.header = opts.header
		end
		if opts.tooltipText then entry.templateData.tooltipText = opts.tooltipText end
		if opts.tooltipText then entry.templateData.narrationTooltip = GAMEPAD_LEFT_DIALOG_TOOLTIP end
	end
	return entry
end

local function AfterCategoryChange(manager)
	manager:MarkDirty()
	AoM.RefreshAllCategoryUI()
	manager:UpdateTooltip()
	manager:UpdateKeybinds()
end

local function BuildOptionEntries(manager, addOnData)
	local entries = {}
	local first_header = "APH-On Manager"

	table.insert(entries, MakeEntry("Search add-ons...", function()
		AoM.ShowGamepadTextEntryDialog("Search Add-Ons", "Add-on name", search.needle or "", function(text)
			StartSearch(manager, text)
		end)
	end, { header = first_header, tooltipText = function() return "Jumps to the first add-on whose name contains the text. Afterwards the left and right shoulder buttons move to the previous and next match." end }))

	table.insert(entries, MakeEntry("Filter: " .. AoM.GetCategoryFilterDisplayName(AoM.GetCategoryFilter()), function()
		local choices = {}
		for _, entry in ipairs(AoM.GetCategoryFilterEntries()) do
			table.insert(choices, { text = entry.display, callback = function() AoM.SetCategoryFilter(entry.internal) end })
		end
		ShowGamepadPickerDialog("Filter", choices)
	end))

	if addOnData and addOnData.addOnFileName then
		local addon_name = addOnData.strippedAddOnName or addOnData.addOnFileName
		local current_category = AoM.GetAddonCategory(addOnData.addOnFileName)
		local current_display = AoM.GetCategoryDisplayName(current_category)

		table.insert(entries, MakeEntry("Move to category...", function()
			local choices = {}
			for _, category in ipairs(AoM.GetAllCategories()) do
				if category ~= current_category then
					table.insert(choices, { text = AoM.GetCategoryDisplayName(category), callback = function()
						AoM.AssignAddonToCategory(addOnData.addOnFileName, category)
						AfterCategoryChange(manager)
					end })
				end
			end
			ShowGamepadPickerDialog("Move " .. addon_name .. " to", choices)
		end, { header = addon_name .. " (" .. current_display .. ")" }))

		if current_category ~= LIBRARIES then
			local all_enabled = IsCategoryFullyEnabled(current_category)
			table.insert(entries, MakeEntry((all_enabled and "Disable every add-on in " or "Enable every add-on in ") .. current_display, function()
				AoM.SetCategoryAddonsEnabled(GetCategoryEntries(current_category), not all_enabled)
				AfterCategoryChange(manager)
			end))
		end

		table.insert(entries, MakeEntry("Rename category " .. current_display .. "...", function()
			AoM.ShowRenameCategoryDialog(current_category)
		end))

		if not AoM.IsDefaultCategory(current_category) then
			table.insert(entries, MakeEntry("Delete category " .. current_display, function()
				AoM.ConfirmDeleteCategory(current_category)
			end))
		end
	end

	table.insert(entries, MakeEntry("New category...", function() AoM.ShowNewCategoryDialog() end))
	table.insert(entries, MakeEntry("Auto Disable Unused: " .. (AoM.IsAutoDisableUnusedEnabled() and "On" or "Off"), function()
		AoM.SetAutoDisableUnusedEnabled(not AoM.IsAutoDisableUnusedEnabled())
	end))
	table.insert(entries, MakeEntry("Disable Unused", function() AoM.DisableUnused() end,
		{ tooltipText = function() return "Disable every library nothing enabled uses, and every add-on still switched on while a library it needs is off. Chat lists what changed." end }))
	table.insert(entries, MakeEntry("Reset list", function() AoM.ConfirmResetAddonCategoryAssignments() end,
		{ tooltipText = function() return "Move every add-on and library back to its default category. Your own categories are kept." end }))
	table.insert(entries, MakeEntry("Reset categories", function() AoM.ConfirmResetCategories() end,
		{ tooltipText = function() return "Delete every category you created. Add-ons in them fall back to their default category." end }))
	return entries
end

local function HookOptionsDialog(manager)
	local info = ESO_Dialogs[OPTIONS_DIALOG]
	if not info or info.aom_hooked then return end
	info.aom_hooked = true
	ZO_PostHook(info, "setup", function(dialogControl, addOnData)
		local list = dialogControl.info.parametricList
		for _, entry in ipairs(BuildOptionEntries(manager, addOnData)) do
			table.insert(list, entry)
		end
		ZO_GenericParametricListGamepadDialogTemplate_RebuildEntryList(dialogControl)
	end)
end

local function WrapToggleForCascade(manager)
	for _, descriptor in ipairs(manager.keybindStripDescriptor or {}) do
		if descriptor.keybind == "UI_SHORTCUT_PRIMARY" and descriptor.callback and not descriptor.aom_cascade_wrapped then
			descriptor.aom_cascade_wrapped = true
			local original = descriptor.callback
			descriptor.callback = function(...)
				local data = manager:GetSelectedData()
				local index = data and data.addOnIndex
				local addon_manager = GetAddOnManager()
				local was_enabled = index and select(5, addon_manager:GetAddOnInfo(index))
				original(...)
				if index and was_enabled and not select(5, addon_manager:GetAddOnInfo(index)) and #AoM.CascadeDisableUnused(index) > 0 then
					manager:MarkDirty()
					manager:RefreshData()
				end
			end
		end
	end
end

ZO_PostHook(ZO_AddOnManager_Gamepad, "OnDeferredInitialize", function(manager)
	HookGamepadTooltip()
	HookOptionsDialog(manager)
	AddSearchKeybinds(manager)
	WrapToggleForCascade(manager)
end)

ZO_PostHook(ZO_AddOnManager_Gamepad, "OnShowing", function()
	SuppressVotanUsedBySection()
end)

ZO_PostHook(ZO_AddOnManager_Gamepad, "OnHiding", function()
	search.needle = nil
	search.pos = 0
end)
