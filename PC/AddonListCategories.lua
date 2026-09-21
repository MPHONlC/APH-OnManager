-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
if not ADD_ON_MANAGER then return end
local AoM = AoMCore
local LibAPH = LibAPH

local LIBRARIES = "Libraries"

local function EntryMatchesFilter(entry, category)
	return AoM.CategoryMatchesFilter(entry.isLibrary, entry.addOnEnabled, category)
end

local function RegroupByCategory(self)
	local flat = {}
	for _, is_lib in ipairs({ true, false }) do
		for _, entry in ipairs(self.addonTypes[is_lib] or {}) do
			table.insert(flat, entry)
		end
	end

	local groups, order, display_to_internal = {}, {}, {}
	for _, entry in ipairs(flat) do
		local category = AoM.GetAddonCategory(entry.addOnFileName)
		if EntryMatchesFilter(entry, category) then
			if not groups[category] then
				groups[category] = {}
				table.insert(order, category)
				display_to_internal[AoM.GetCategoryDisplayName(category)] = category
			end
			table.insert(groups[category], entry)
		end
	end
	table.sort(order, function(a, b) return string.lower(a) < string.lower(b) end)

	self.aom_category_groups = groups
	self.aom_category_order = order
	self.aom_category_display_to_internal = display_to_internal
end

ZO_PostHook(ADD_ON_MANAGER, "BuildMasterList", RegroupByCategory)

ZO_PreHook(ADD_ON_MANAGER, "SortScrollList", function(self)
	self:ResetDataTypes()
	local scrollData = ZO_ScrollList_GetDataList(self.list)
	ZO_ClearNumericallyIndexedTable(scrollData)

	for _, category in ipairs(self.aom_category_order or {}) do
		local is_lib_group = (category == LIBRARIES)
		self.addonTypes[is_lib_group] = self.aom_category_groups[category]
		self:AddAddonTypeSection(is_lib_group, AoM.GetCategoryDisplayName(category))
	end
	return true
end)

ZO_PostHook(ADD_ON_MANAGER, "SetupSectionHeaderRow", function(self, control, data)
	local internal_category = (self.aom_category_display_to_internal and self.aom_category_display_to_internal[data.text]) or data.text

	if control.checkboxControl then
		if not control.aom_rename_btn then
			control.aom_rename_btn = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "SavingEditBoxModifyButton")
			control.aom_rename_btn:SetDimensions(18, 18)
			control.aom_rename_btn:SetHandler("OnClicked", function()
				if control.aom_current_category then AoM.ShowRenameCategoryDialog(control.aom_current_category) end
			end)

			control.aom_delete_btn = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "SavingEditBoxCancelButton")
			control.aom_delete_btn:SetDimensions(18, 18)
			control.aom_delete_btn:SetHandler("OnMouseEnter", function(btn)
				InitializeTooltip(InformationTooltip, btn, BOTTOM, 0, -2)
				SetTooltipText(InformationTooltip, "Delete")
			end)
			control.aom_delete_btn:SetHandler("OnMouseExit", function()
				ClearTooltip(InformationTooltip)
			end)
			control.aom_delete_btn:SetHandler("OnClicked", function()
				if control.aom_current_category then AoM.ConfirmDeleteCategory(control.aom_current_category) end
			end)
		end

		control.aom_current_category = internal_category
		control.aom_rename_btn:ClearAnchors()
		control.aom_rename_btn:SetAnchor(LEFT, control.checkboxControl, LEFT, 70, 0)
		control.aom_rename_btn:SetHidden(false)

		control.aom_delete_btn:ClearAnchors()
		control.aom_delete_btn:SetAnchor(LEFT, control.aom_rename_btn, RIGHT, 6, 0)
		control.aom_delete_btn:SetHidden(AoM.IsDefaultCategory(internal_category))
	end

	if data.isLibrary then return end
	local group = self.aom_category_groups and self.aom_category_groups[internal_category]
	if not group or not control.checkboxControl then return end

	local am = GetAddOnManager()
	local all_enabled = true
	for _, entry in ipairs(group) do
		local _, _, _, _, isEnabled = am:GetAddOnInfo(entry.index)
		if not isEnabled then
			all_enabled = false
			break
		end
	end
	ZO_CheckButton_SetCheckState(control.checkboxControl, all_enabled)

	ZO_CheckButton_SetToggleFunction(control.checkboxControl, function(_, isBoxChecked)
		AoM.SetCategoryAddonsEnabled(group, isBoxChecked)
		self.isDirty = true
		self:RefreshKeybinds()
		self:RefreshData()
	end)
end)

local category_filter_combo
local native_new_category_btn
local native_reset_btn
local native_reset_categories_btn
local category_display_to_internal = {}

local function OnCategoryFilterSelected(_, itemText)
	AoM.SetCategoryFilter(category_display_to_internal[itemText] or itemText)
end

local function IsAddonSelectorRunning()
	return _G["AddonSelectorSave"] ~= nil and _G["AddonSelectorDelete"] ~= nil
end
AoM.IsAddonSelectorRunning = IsAddonSelectorRunning

local function GetAddonSelectorRowRightEdge()
	return _G["AddonSelectorAutoReloadUITexture"] or _G["AddonSelectorSaveModeTexture"] or _G["AddonSelectorSave"]
end

local added_controls = {}
local added_controls_refreshed = false

local function RefreshAddedControlsOnFirstShow()
	if added_controls_refreshed or #added_controls == 0 then return end
	added_controls_refreshed = true
	for _, control in ipairs(added_controls) do control:SetHidden(true) end
	zo_callLater(function()
		for _, control in ipairs(added_controls) do control:SetHidden(false) end
	end, 0)
end

function AoM.EnsureCategoryFilterDropdown()
	if category_filter_combo then return category_filter_combo end
	if not ADD_ON_MANAGER or not ADD_ON_MANAGER.control then return nil end
	local title = ADD_ON_MANAGER.control:GetNamedChild("Title")
	if not title then return nil end

	local addon_selector_active = IsAddonSelectorRunning()
	local addon_selector_row_end = addon_selector_active and GetAddonSelectorRowRightEdge()
	if addon_selector_active and not addon_selector_row_end then return nil end

	local container = WINDOW_MANAGER:CreateControlFromVirtual("AoMCategoryFilterDropdown", ADD_ON_MANAGER.control, "ZO_ComboBox")
	container:SetDimensions(140, 26)
	if addon_selector_row_end then
		container:SetAnchor(TOPLEFT, addon_selector_row_end, TOPRIGHT, 20, 0)
	else
		container:SetAnchor(LEFT, title, RIGHT, 180, 0)
	end

	added_controls[#added_controls + 1] = container
	category_filter_combo = ZO_ComboBox_ObjectFromContainer(container)
	category_filter_combo:SetSortsItems(false)
	AoM.category_filter_combo = category_filter_combo
	AoM.category_filter_dropdown_container = container

	native_new_category_btn = WINDOW_MANAGER:CreateControlFromVirtual("AoMNewCategoryButton", ADD_ON_MANAGER.control, "ZO_DefaultButton")
	native_new_category_btn:SetDimensions(140, 30)
	native_new_category_btn:SetFont("ZoFontWinH4")
	native_new_category_btn:SetText("New Category")
	native_new_category_btn:SetHandler("OnClicked", function() AoM.ShowNewCategoryDialog() end)
	if addon_selector_row_end then
		native_new_category_btn:SetAnchor(TOPLEFT, _G["AddonSelectorDelete"], TOPRIGHT, 72, 0)
	else
		native_new_category_btn:SetAnchor(LEFT, container, RIGHT, 20, 0)
	end
	added_controls[#added_controls + 1] = native_new_category_btn

	local ghost_btn = WINDOW_MANAGER:CreateControlFromVirtual("AoMDisableGhostLibrariesButton", ADD_ON_MANAGER.control, "ZO_DefaultButton")
	ghost_btn:SetDimensions(210, 30)
	ghost_btn:SetFont("ZoFontWinH4")
	ghost_btn:SetText("Disable Ghost Libraries")
	ghost_btn:SetHandler("OnClicked", function() AoM.DisableGhostLibraries() end)
	if addon_selector_row_end then
		ghost_btn:SetAnchor(BOTTOMRIGHT, ADD_ON_MANAGER.control, TOPRIGHT, -5, 71)
	else
		ghost_btn:SetAnchor(LEFT, native_new_category_btn, RIGHT, 10, 0)
	end
	added_controls[#added_controls + 1] = ghost_btn

	local secondary_btn = ADD_ON_MANAGER.control:GetNamedChild("SecondaryButton")
	if secondary_btn then
		native_reset_btn = LibAPH.CreateKeybindLabelButton(ADD_ON_MANAGER.control, {
			action = "AOM_RESET_LIST",
			layer = AoM.KEYBIND_LAYER,
			name = "Reset List",
		})
		native_reset_btn:SetAnchor(LEFT, secondary_btn, RIGHT, 30, 0)
		native_reset_btn.libaph_click_action = AoM.ConfirmResetAddonCategoryAssignments

		native_reset_categories_btn = LibAPH.CreateKeybindLabelButton(ADD_ON_MANAGER.control, {
			action = "AOM_RESET_CATEGORIES",
			layer = AoM.KEYBIND_LAYER,
			name = "Reset Categories",
		})
		native_reset_categories_btn:SetAnchor(LEFT, native_reset_btn, RIGHT, 20, 0)
		native_reset_categories_btn.libaph_click_action = AoM.ConfirmResetCategories
		added_controls[#added_controls + 1] = native_reset_btn
		added_controls[#added_controls + 1] = native_reset_categories_btn
	end

	return category_filter_combo
end

local function PopulateCategoryFilterDropdown()
	local combo = category_filter_combo
	if not combo then return end
	combo:ClearItems()
	category_display_to_internal = {}
	for _, entry in ipairs(AoM.GetCategoryFilterEntries()) do
		category_display_to_internal[entry.display] = entry.internal
		combo:AddItem(combo:CreateItemEntry(entry.display, OnCategoryFilterSelected))
	end
	combo:SetSelectedItem(AoM.GetCategoryFilterDisplayName(AoM.GetCategoryFilter()))
end
AoM.PopulateCategoryFilterDropdown = PopulateCategoryFilterDropdown

EVENT_MANAGER:RegisterForEvent("AoM_CategoryFilterBuild", EVENT_PLAYER_ACTIVATED, function()
	EVENT_MANAGER:UnregisterForEvent("AoM_CategoryFilterBuild", EVENT_PLAYER_ACTIVATED)
	if AoM.EnsureCategoryFilterDropdown() then
		PopulateCategoryFilterDropdown()
	end
end)

local placing_advanced_ui_errors = false

local function PlaceAdvancedUIErrorsCheckbox()
	if placing_advanced_ui_errors then return end
	local win = ADD_ON_MANAGER.control
	local checkbox = win:GetNamedChild("AdvancedUIErrors")
	local reload_btn = win:GetNamedChild("PrimaryButton")
	if not checkbox or not reload_btn then return end
	if reload_btn:GetRight() <= reload_btn:GetLeft() then return end

	local label_width = (checkbox.label and checkbox.label:GetTextWidth()) or 150
	local needed_width = 16 + 8 + label_width
	local left = reload_btn:GetLeft()
	local max_left = win:GetRight() - needed_width - 10
	if left > max_left then left = max_left end
	if left < win:GetLeft() + 10 then left = win:GetLeft() + 10 end
	local top = reload_btn:GetBottom() + 8
	if math.abs(checkbox:GetLeft() - left) < 1 and math.abs(checkbox:GetTop() - top) < 1 then return end

	placing_advanced_ui_errors = true
	checkbox:ClearAnchors()
	checkbox:SetAnchor(TOPLEFT, win, TOPLEFT, left - win:GetLeft(), top - win:GetTop())
	placing_advanced_ui_errors = false
end

do
	local checkbox = ADD_ON_MANAGER.control and ADD_ON_MANAGER.control:GetNamedChild("AdvancedUIErrors")
	if checkbox then
		ZO_PostHookHandler(checkbox, "OnRectChanged", PlaceAdvancedUIErrorsCheckbox)
	end
end

if ADDONS_FRAGMENT then
	ADDONS_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWING then
			PopulateCategoryFilterDropdown()
			RefreshAddedControlsOnFirstShow()
			PlaceAdvancedUIErrorsCheckbox()
		elseif newState == SCENE_FRAGMENT_SHOWN then
			PlaceAdvancedUIErrorsCheckbox()
		end
	end)
end
