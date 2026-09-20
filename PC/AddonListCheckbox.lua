-- APH-OnManager - Copyright 2026 @APHONlC.
-- Licensed under the GNU General Public License v3.0 (GPLv3).
-- See LICENSE.md and NOTICE.md.

assert(AoMCore, "APH-OnManager.lua must be loaded before this file")
if not ADD_ON_MANAGER then return end

local function IsRecoverableByEnabling(am, addon_index)
	local num_deps = am:GetAddOnNumDependencies(addon_index)
	if num_deps == 0 then return false end

	local has_disabled_only_problem = false
	for d = 1, num_deps do
		local _, exists, active, minVersion, version = am:GetAddOnDependencyInfo(addon_index, d)
		if not exists then
			return false
		end
		if minVersion and minVersion > 0 and version < minVersion then
			return false
		end
		if not active then
			has_disabled_only_problem = true
		end
	end
	return has_disabled_only_problem
end

local orig_GetRowSetupFunction = ZO_AddOnManager.GetRowSetupFunction
function ZO_AddOnManager:GetRowSetupFunction()
	local orig_setup = orig_GetRowSetupFunction(self)
	return function(control, data)
		orig_setup(control, data)
		if data.hasDependencyError and data.index then
			local am = GetAddOnManager()
			if IsRecoverableByEnabling(am, data.index) then
				local enabledControl = control:GetNamedChild("Enabled")
				if enabledControl then
					enabledControl:SetHidden(false)
					ZO_CheckButton_SetEnableState(enabledControl, am:AreAddOnsEnabled())
				end
			end
		end
	end
end
