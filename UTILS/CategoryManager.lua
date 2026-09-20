-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
local AoM = AoMCore

local UNCATEGORIZED = "Uncategorized"
local LIBRARIES = "Libraries"
local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")

local function IsLibraryAddon(am, index)
	local name, _, _, _, _, _, _, isLibrary = am:GetAddOnInfo(index)
	return isLibrary or string.sub(name, 1, 3) == "Lib"
end

local DEFAULT_CATEGORY_NAMES = { [LIBRARIES] = true, [UNCATEGORIZED] = true }
for _, category in pairs(AoM.SuggestedCategories or {}) do
	DEFAULT_CATEGORY_NAMES[category] = true
end

local function IsDefaultCategory(name)
	return DEFAULT_CATEGORY_NAMES[name] == true
end
AoM.IsDefaultCategory = IsDefaultCategory

local function EnsureSavedTables()
	if not AoM.saved then return false end
	AoM.saved.categories = AoM.saved.categories or {}
	AoM.saved.addon_category_assignment = AoM.saved.addon_category_assignment or {}
	return true
end

local function EnsureDisplayNameTable()
	if not AoM.saved then return false end
	AoM.saved.default_category_display_names = AoM.saved.default_category_display_names or {}
	return true
end

function AoM.GetCategoryDisplayName(name)
	if IsDefaultCategory(name) and EnsureDisplayNameTable() then
		return AoM.saved.default_category_display_names[name] or name
	end
	return name
end

local function IsCategoryDisplayNameTaken(displayName, excludeInternalName)
	for _, internal in ipairs(AoM.GetAllCategories()) do
		if internal ~= excludeInternalName and AoM.GetCategoryDisplayName(internal) == displayName then
			return true
		end
	end
	return false
end

function AoM.GetAllCategories()
	local list = { LIBRARIES }
	if EnsureSavedTables() then
		for _, name in ipairs(AoM.saved.categories) do
			table.insert(list, name)
		end
	end
	table.insert(list, UNCATEGORIZED)
	return list
end

function AoM.CreateCategory(name)
	EnsureSavedTables()
	if not name or name == "" then return false, "empty" end
	if IsDefaultCategory(name) then return false, "reserved" end
	for _, existing in ipairs(AoM.saved.categories) do
		if existing == name then return false, "duplicate" end
	end
	table.insert(AoM.saved.categories, name)
	return true
end

function AoM.RenameCategory(oldName, newName)
	EnsureSavedTables()
	if not newName or newName == "" then return false, "invalid" end

	if IsDefaultCategory(oldName) then
		if IsCategoryDisplayNameTaken(newName, oldName) then return false, "duplicate" end
		EnsureDisplayNameTable()
		AoM.saved.default_category_display_names[oldName] = newName
		return true
	end

	if IsDefaultCategory(newName) then return false, "invalid" end
	local found
	for i, existing in ipairs(AoM.saved.categories) do
		if existing == oldName then found = i end
		if existing == newName then return false, "duplicate" end
	end
	if not found then return false, "notfound" end
	if IsCategoryDisplayNameTaken(newName, oldName) then return false, "duplicate" end
	AoM.saved.categories[found] = newName
	for addonName, cat in pairs(AoM.saved.addon_category_assignment) do
		if cat == oldName then AoM.saved.addon_category_assignment[addonName] = newName end
	end
	return true
end

function AoM.DeleteCategory(name)
	EnsureSavedTables()
	if IsDefaultCategory(name) then return false, "reserved" end
	local found
	for i, existing in ipairs(AoM.saved.categories) do
		if existing == name then found = i end
	end
	if not found then return false, "notfound" end
	table.remove(AoM.saved.categories, found)
	for addonName, cat in pairs(AoM.saved.addon_category_assignment) do
		if cat == name then AoM.saved.addon_category_assignment[addonName] = nil end
	end
	return true
end

function AoM.AssignAddonToCategory(addonName, categoryName)
	EnsureSavedTables()
	if categoryName == nil then
		AoM.saved.addon_category_assignment[addonName] = nil
		return true
	end
	if categoryName ~= LIBRARIES and categoryName ~= UNCATEGORIZED then
		local exists = false
		for _, existing in ipairs(AoM.saved.categories) do
			if existing == categoryName then exists = true; break end
		end
		if not exists then return false, "notfound" end
	end
	AoM.saved.addon_category_assignment[addonName] = categoryName
	return true
end

function AoM.GetAddonCategory(addonName)
	local assigned = EnsureSavedTables() and AoM.saved.addon_category_assignment[addonName]
	if assigned then return assigned end

	local suggested = AoM.SuggestedCategories and AoM.SuggestedCategories[addonName]
	if suggested then return suggested end

	local am = GetAddOnManager()
	for i = 1, am:GetNumAddOns() do
		local name = am:GetAddOnInfo(i)
		if name == addonName then
			if IsLibraryAddon(am, i) then return LIBRARIES end
			break
		end
	end
	return UNCATEGORIZED
end

function AoM.GetAddonsInCategory(categoryName)
	EnsureSavedTables()
	local am = GetAddOnManager()
	local list = {}
	for i = 1, am:GetNumAddOns() do
		local name = am:GetAddOnInfo(i)
		if AoM.GetAddonCategory(name) == categoryName then
			table.insert(list, name)
		end
	end
	table.sort(list)
	return list
end

function AoM.ResetAddonCategoryAssignments()
	if not EnsureSavedTables() then return end
	AoM.saved.addon_category_assignment = {}
end

function AoM.ResetCategories()
	if not EnsureSavedTables() then return 0 end
	local removed = 0
	for i = #AoM.saved.categories, 1, -1 do
		local name = AoM.saved.categories[i]
		if not IsDefaultCategory(name) then
			AoM.DeleteCategory(name)
			removed = removed + 1
		end
	end
	return removed
end

function AoM.ApplySuggestedCategories(suggestions, overwriteExisting)
	EnsureSavedTables()
	local applied = 0
	for addonName, categoryName in pairs(suggestions) do
		if overwriteExisting or AoM.saved.addon_category_assignment[addonName] == nil then
			if categoryName ~= LIBRARIES and categoryName ~= UNCATEGORIZED then
				local exists = false
				for _, existing in ipairs(AoM.saved.categories) do
					if existing == categoryName then exists = true; break end
				end
				if not exists then table.insert(AoM.saved.categories, categoryName) end
			end
			AoM.saved.addon_category_assignment[addonName] = categoryName
			applied = applied + 1
		end
	end
	return applied
end

local category_window
local RefreshCategoryWindow

local function GetCategoryManagerWindow()
	if category_window then return category_window end
	category_window = LibAPH.CreateScrollListWindow({
		name = "AoM_CategoryManagerWindow",
		widthPct = 0.36, heightPct = 0.6,
		minWidth = 620, maxWidth = 950,
		minHeight = 460, maxHeight = 860,
		footerHeight = 44,
		titleText = "|c9CD04CAPH-On Manager|r Category Manager",
		enableSearch = true,
	})
	category_window:SetSubtitle("Click an add-on to pick its category. Click a category to rename/delete it.")

	category_window.new_btn = LibAPH.CreateKeybindLabelButton(category_window.footer, {
		keybind = "UI_SHORTCUT_TERTIARY",
		name = "New Category",
	})
	category_window.new_btn:SetAnchor(TOPRIGHT, category_window.footer, TOPRIGHT, 0, 0)

	category_window.reset_btn = LibAPH.CreateKeybindLabelButton(category_window.footer, {
		keybind = "UI_SHORTCUT_SECONDARY",
		name = "Reset List",
	})
	category_window.reset_btn:SetAnchor(TOPRIGHT, category_window.new_btn, TOPLEFT, -10, 0)

	category_window.reset_categories_btn = LibAPH.CreateKeybindLabelButton(category_window.footer, {
		keybind = "UI_SHORTCUT_QUATERNARY",
		name = "Reset Categories",
	})
	category_window.reset_categories_btn:SetAnchor(TOPRIGHT, category_window.reset_btn, TOPLEFT, -10, 0)

	return category_window
end

local function HidePopupForDialog()
	local was_visible = category_window ~= nil and not category_window.window:IsHidden()
	if was_visible then category_window.window:SetHidden(true) end
	return was_visible
end

local function RestorePopupAfterDialog(was_visible)
	if was_visible and category_window then category_window.window:SetHidden(false) end
end

local function ShowNameEntryDialog(dialogId, titleText, mainText, onConfirm)
	if not ESO_Dialogs[dialogId] then
		ESO_Dialogs[dialogId] = {
			canQueue = true,
			gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
			title = { text = titleText },
			mainText = function(dialog) return { text = dialog.data.mainText } end,
			editBox = {},
			buttons = {
				{
					requiresTextInput = true,
					text = SI_DIALOG_CONFIRM,
					callback = function(dialog)
						local new_name = ZO_Dialogs_GetEditBoxText(dialog)
						if new_name and new_name ~= "" then dialog.data.onConfirm(new_name) end
					end,
				},
				{ text = SI_DIALOG_CANCEL },
			},
			finishedCallback = function(dialog)
				RestorePopupAfterDialog(dialog.data.was_visible)
			end,
		}
	end

	local was_visible = HidePopupForDialog()
	local data = { mainText = mainText, onConfirm = onConfirm, was_visible = was_visible }
	if IsConsoleUI() or IsInGamepadPreferredMode() then
		if AoM.ShowGamepadTextEntryDialog then
			AoM.ShowGamepadTextEntryDialog(titleText, mainText, "", function(new_name)
				RestorePopupAfterDialog(was_visible)
				onConfirm(new_name)
			end, function() RestorePopupAfterDialog(was_visible) end)
		else
			ZO_Dialogs_ShowGamepadDialog(dialogId, data)
		end
	else
		ZO_Dialogs_ShowDialog(dialogId, data)
	end
end

local function RefreshGamepadAddonList()
	if ADDON_MANAGER_GAMEPAD and ADDON_MANAGER_GAMEPAD.list then
		ADDON_MANAGER_GAMEPAD:RefreshData()
	end
end

local function RefreshAllCategoryUI()
	if category_window then RefreshCategoryWindow() end
	if AoM.PopulateCategoryFilterDropdown then AoM.PopulateCategoryFilterDropdown() end
	if ADD_ON_MANAGER then
		ADD_ON_MANAGER.isDirty = true
		ADD_ON_MANAGER:RefreshData()
	end
	RefreshGamepadAddonList()
end
AoM.RefreshAllCategoryUI = RefreshAllCategoryUI

local function OpenCategoryPickerMenu(control, addonName, currentCategory)
	ClearMenu()
	for _, cat in ipairs(AoM.GetAllCategories()) do
		if cat ~= currentCategory then
			AddMenuItem(AoM.GetCategoryDisplayName(cat), function()
				AoM.AssignAddonToCategory(addonName, cat)
				RefreshAllCategoryUI()
			end)
		end
	end
	ShowMenu(control)
end

local function ConfirmDeleteCategory(categoryName)
	local was_visible = HidePopupForDialog()
	LibAPH.ShowDialogChained("AoM_DELETE_CATEGORY_" .. categoryName, "Delete Category",
		string.format("Delete \"%s\"? Add-ons in it fall back to their default category.", categoryName), {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				AoM.DeleteCategory(categoryName)
				RestorePopupAfterDialog(was_visible)
				RefreshAllCategoryUI()
			end,
		},
		{
			text = SI_DIALOG_CANCEL,
			callback = function()
				RestorePopupAfterDialog(was_visible)
			end,
		},
	})
end

local function ShowRenameCategoryDialog(categoryName)
	local display_name = AoM.GetCategoryDisplayName(categoryName)
	ShowNameEntryDialog("AoM_RENAME_CATEGORY", "Rename Category", "Enter a new name for \"" .. display_name .. "\".", function(new_name)
		if AoM.RenameCategory(categoryName, new_name) then
			RefreshAllCategoryUI()
		end
	end)
end
AoM.ShowRenameCategoryDialog = ShowRenameCategoryDialog
AoM.ConfirmDeleteCategory = ConfirmDeleteCategory

local function ShowNewCategoryDialog()
	ShowNameEntryDialog("AoM_NEW_CATEGORY", "New Category", "Enter a name for the new category.", function(new_name)
		if AoM.CreateCategory(new_name) then RefreshAllCategoryUI() end
	end)
end
AoM.ShowNewCategoryDialog = ShowNewCategoryDialog

local function OpenCategoryHeaderMenu(control, categoryName)
	ClearMenu()
	AddMenuItem("Rename Category", function()
		ShowRenameCategoryDialog(categoryName)
	end)
	if not IsDefaultCategory(categoryName) then
		AddMenuItem("Delete Category", function()
			ConfirmDeleteCategory(categoryName)
		end)
	end
	ShowMenu(control)
end

RefreshCategoryWindow = function()
	local win = GetCategoryManagerWindow()
	local am = GetAddOnManager()

	local by_category = {}
	for i = 1, am:GetNumAddOns() do
		local name, title = am:GetAddOnInfo(i)
		local category = AoM.GetAddonCategory(name)
		by_category[category] = by_category[category] or {}
		table.insert(by_category[category], { name = name, title = (title ~= "" and title or name) })
	end

	local categories = AoM.GetAllCategories()
	table.sort(categories, function(a, b)
		return string.lower(AoM.GetCategoryDisplayName(a)) < string.lower(AoM.GetCategoryDisplayName(b))
	end)

	local rows = {}
	for _, category in ipairs(categories) do
		local members = by_category[category] or {}
		table.sort(members, function(a, b) return a.title < b.title end)

		local is_default_category = IsDefaultCategory(category)
		table.insert(rows, {
			text = string.format("%s (%d)", AoM.GetCategoryDisplayName(category), #members),
			is_header = true,
			onClick = function(control)
				OpenCategoryHeaderMenu(control, category)
			end,
			renameButton = {
				onClick = function()
					ShowRenameCategoryDialog(category)
				end,
			},
			closeButton = not is_default_category and {
				onClick = function()
					ConfirmDeleteCategory(category)
				end,
			} or nil,
		})
		for _, member in ipairs(members) do
			table.insert(rows, {
				text = member.title,
				color = { 0.85, 0.85, 0.85, 1 },
				statusIcons = AoM.GetStatusIconsForAddonByName(am, member.name),
				populateTooltip = function(tooltip)
					AoM.PopulateAddonInfoTooltipByName(tooltip, member.name)
				end,
				onClick = function(control)
					OpenCategoryPickerMenu(control, member.name, category)
				end,
			})
		end
	end

	win:SetTitle("|c9CD04CAPH-On Manager|r Category Manager")
	win:SetRows(rows)
end

local function ConfirmResetAddonCategoryAssignments()
	local was_visible = HidePopupForDialog()
	LibAPH.ShowDialogChained("AoM_RESET_CATEGORY_ASSIGNMENTS", "Reset List",
		"Move every add-on and library back to its default category? Your own categories are kept.", {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				AoM.ResetAddonCategoryAssignments()
				RestorePopupAfterDialog(was_visible)
				RefreshAllCategoryUI()
			end,
		},
		{
			text = SI_DIALOG_CANCEL,
			callback = function()
				RestorePopupAfterDialog(was_visible)
			end,
		},
	})
end

AoM.ConfirmResetAddonCategoryAssignments = ConfirmResetAddonCategoryAssignments

local function ConfirmResetCategories()
	local was_visible = HidePopupForDialog()
	LibAPH.ShowDialogChained("AoM_RESET_CATEGORIES", "Reset Categories",
		"Delete every category you've created? Add-ons/libraries in them fall back to their default category. Libraries, Uncategorized, and APH-On Manager's built-in suggested categories are never touched.", {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				AoM.ResetCategories()
				RestorePopupAfterDialog(was_visible)
				RefreshAllCategoryUI()
			end,
		},
		{
			text = SI_DIALOG_CANCEL,
			callback = function()
				RestorePopupAfterDialog(was_visible)
			end,
		},
	})
end

AoM.ConfirmResetCategories = ConfirmResetCategories

function AoM.OpenCategoryManager()
	local win = GetCategoryManagerWindow()

	win.new_btn.libaph_click_action = ShowNewCategoryDialog
	win.reset_btn.libaph_click_action = ConfirmResetAddonCategoryAssignments
	win.reset_categories_btn.libaph_click_action = ConfirmResetCategories

	RefreshCategoryWindow()
	win:Show()
end

SLASH_COMMANDS["/libcategories"] = function()
	AoM.OpenCategoryManager()
end

SLASH_COMMANDS["/libcatreset"] = function()
	AoM.ResetAddonCategoryAssignments()
	if ADD_ON_MANAGER then
		ADD_ON_MANAGER.isDirty = true
		ADD_ON_MANAGER:RefreshData()
	end
	if category_window and not category_window.window:IsHidden() then
		RefreshCategoryWindow()
	end
	logger:Print("Add-on/library category assignments reset to default.")
end

local FILTER_ALL = "All Add-Ons"
local FILTER_ENABLED_ADDONS = "Enabled Add-Ons"
local FILTER_ENABLED_LIBRARIES = "Enabled Libraries"
local FILTER_SHOW_ENABLED = "Show Enabled"
local current_filter = FILTER_ALL

function AoM.CategoryMatchesFilter(isLibrary, isEnabled, category)
	if current_filter == FILTER_ALL then return true end
	if current_filter == FILTER_ENABLED_ADDONS then return not isLibrary and isEnabled end
	if current_filter == FILTER_ENABLED_LIBRARIES then return isLibrary and isEnabled end
	if current_filter == FILTER_SHOW_ENABLED then return isEnabled end
	return category == current_filter
end

function AoM.GetCategoryFilter()
	return current_filter
end

function AoM.GetCategoryFilterDisplayName(filter)
	if filter == FILTER_ALL or filter == FILTER_ENABLED_ADDONS or filter == FILTER_ENABLED_LIBRARIES or filter == FILTER_SHOW_ENABLED then
		return filter
	end
	return AoM.GetCategoryDisplayName(filter)
end

function AoM.GetCategoryFilterEntries()
	local entries = {
		{ display = FILTER_ALL, internal = FILTER_ALL },
		{ display = FILTER_ENABLED_ADDONS, internal = FILTER_ENABLED_ADDONS },
		{ display = FILTER_ENABLED_LIBRARIES, internal = FILTER_ENABLED_LIBRARIES },
		{ display = FILTER_SHOW_ENABLED, internal = FILTER_SHOW_ENABLED },
	}
	for _, category in ipairs(AoM.GetAllCategories()) do
		table.insert(entries, { display = AoM.GetCategoryDisplayName(category), internal = category })
	end
	return entries
end

function AoM.SetCategoryFilter(filter)
	current_filter = filter or FILTER_ALL
	if AoM.category_filter_combo then
		AoM.category_filter_combo:SetSelectedItem(AoM.GetCategoryFilterDisplayName(current_filter))
	end
	if ADD_ON_MANAGER then
		ADD_ON_MANAGER.isDirty = true
		ADD_ON_MANAGER:RefreshData()
	end
	RefreshGamepadAddonList()
end

function AoM.DisableUnneededLibraries()
	local am = GetAddOnManager()
	local needed = {}
	for i = 1, am:GetNumAddOns() do
		local _, _, _, _, isEnabled = am:GetAddOnInfo(i)
		if isEnabled then
			for d = 1, am:GetAddOnNumDependencies(i) do
				local dep_name = am:GetAddOnDependencyInfo(i, d)
				if dep_name then needed[dep_name] = true end
			end
		end
	end
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, isEnabled, _, _, isLibrary = am:GetAddOnInfo(i)
		if isEnabled and not needed[name] and (isLibrary or string.sub(name, 1, 3) == "Lib") then
			am:SetAddOnEnabled(i, false)
		end
	end
end

function AoM.SetCategoryAddonsEnabled(entries, isEnabled)
	local am = GetAddOnManager()
	for _, entry in ipairs(entries) do
		if entry.index then
			am:SetAddOnEnabled(entry.index, isEnabled)
		end
	end
	if not isEnabled then
		AoM.DisableUnneededLibraries()
	end
end

if not ZO_AddOnManager.AreAddOnsEnabled then
	function ZO_AddOnManager:AreAddOnsEnabled()
		return GetAddOnManager():AreAddOnsEnabled()
	end
end
