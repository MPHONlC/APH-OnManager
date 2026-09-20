-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
local AoM = AoMCore
assert(AoM.KnownLibraries, "KnownLibraries.lua must be loaded before this file")

local library_version_window

local function GetLibraryVersionWindow()
	if library_version_window then return library_version_window end
	library_version_window = LibAPH.CreateScrollListWindow({
		name = "AoM_LibraryVersionWindow",
		widthPct = 0.3, heightPct = 0.5,
		minWidth = 420, maxWidth = 760,
		minHeight = 360, maxHeight = 720,
		footerHeight = 20,
		titleText = "|c9CD04CAPH-On Manager|r Library Version Check",
	})
	return library_version_window
end

SLASH_COMMANDS["/libraryversioncheck"] = function()
	local names = {}
	for key in pairs(AoM.KnownLibraries) do
		table.insert(names, key)
	end
	table.sort(names)

	local rows = {}
	for _, key in ipairs(names) do
		local libData = AoM.KnownLibraries[key]
		local ver = LibAPH.CheckLibraryVersion(key)
		if ver > 0 then
			local color, plus, label = LibAPH.GetLibraryDriftColor(ver, libData.requiredVersion)
			table.insert(rows, { text = string.format("%s: %sv%d%s%s|r", libData.fullName, color, ver, plus, label) })
		end
	end

	if #rows == 0 then
		d("|c9CD04C[AoM]|r None of the libraries in this table are currently installed.")
		return
	end

	table.insert(rows, 1, { text = "Installed library versions (compared to this table's own recorded version)", is_header = true })

	local win = GetLibraryVersionWindow()
	win:SetRows(rows)
	win:Show()
end
