-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")

local am = GetAddOnManager()
local orig_SetAddOnEnabled = am.SetAddOnEnabled
local processing = {}
local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")

local function BuildAddonIndexByName()
	local map = {}
	for i = 1, am:GetNumAddOns() do
		map[am:GetAddOnInfo(i)] = i
	end
	return map
end

local function EnableRequiredDependencies(index)
	local num_deps = am:GetAddOnNumDependencies(index)
	if num_deps == 0 then return end

	local index_by_name
	for d = 1, num_deps do
		local dep_name, exists, active = am:GetAddOnDependencyInfo(index, d)
		if exists and not active then
			index_by_name = index_by_name or BuildAddonIndexByName()
			local dep_idx = index_by_name[dep_name]
			if dep_idx then
				logger:Print("Auto-enabled required library: " .. dep_name)
				orig_SetAddOnEnabled(am, dep_idx, true)
			end
		end
	end
end

function am:SetAddOnEnabled(index, enabled)
	if enabled and not processing[index] then
		processing[index] = true
		EnableRequiredDependencies(index)
		processing[index] = nil
	end
	return orig_SetAddOnEnabled(self, index, enabled)
end
