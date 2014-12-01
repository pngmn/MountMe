--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright (c) 2014 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/MountMe
----------------------------------------------------------------------]]

local MOD_TRAVEL_FORM = "ctrl"
local MOD_DISMOUNT_FLYING = "shift"

------------------------------------------------------------------------
-- TODO: cancel transformation buffs that block mounting?

local PLAYER_CLASS = select(2, UnitClass("player"))

local MOUNT_CONDITION = "[outdoors,nocombat,nomounted,novehicleui]"
local SAFE_DISMOUNT = "/stopmacro [flying,nomod:%s]"
local DISMOUNT = [[
/leavevehicle [canexitvehicle]
/dismount [mounted]
]]

local function HasRidingSkill(flyingOnly)
	local hasSkill = IsSpellKnown(90265) or IsSpellKnown(34091) or IsSpellKnown(34090)
	if flyingOnly then
		return hasSkill
	end
	return hasSkill or IsSpellKnown(33391) or IsSpellKnown(33388)
end

local GetAction

------------------------------------------------------------------------

local button = CreateFrame("Button", "MountMeButton", nil, "SecureActionButtonTemplate")
button:SetAttribute("type", "macro")

------------------------------------------------------------------------

if PLAYER_CLASS == "DRUID" then

	local flyingSpell = {
		[0]   = 90267,  -- Flight Master's License / Eastern Kingdoms
		[1]   = 90267,  -- Flight Master's License / Kalimdor
		[646] = 90267,  -- Flight Master's License / Deepholm
		[571] = 54197,  -- Cold Weather Flying / Northrend
		[870] = 115913, -- Wisdom of the Four Winds / Pandaria
		[1116] = -1, -- Draenor
		[1265] = -1, -- Tanaan Jungle Intro
		[1152] = -1, -- FW Horde Garrison Level 1
		[1330] = -1, -- FW Horde Garrison Level 2
		[1153] = -1, -- FW Horde Garrison Level 3
		[1154] = -1, -- FW Horde Garrison Level 4
		[1158] = -1, -- SMV Alliance Garrison Level 1
		[1331] = -1, -- SMV Alliance Garrison Level 2
		[1159] = -1, -- SMV Alliance Garrison Level 3
		[1160] = -1, -- SMV Alliance Garrison Level 4
	}

	local function CanFly() -- because IsFlyableArea is a fucking liar
		if IsFlyableArea() then
			local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
			local reqSpell = flyingSpell[instanceMapID]
			if reqSpell then
				return reqSpell > 0 and IsSpellKnown(reqSpell)
			else
				return HasRidingSkill(true)
			end
		end
	end

	local CAT_FORM_ID, TRAVEL_FORM_ID = 768, 783
	local CAT_FORM, TRAVEL_FORM = GetSpellInfo(CAT_FORM_ID), GetSpellInfo(TRAVEL_FORM_ID)

	MOUNT_CONDITION = format("[outdoors,nocombat,nomounted,noform,novehicleui,nomod:%s]", MOD_TRAVEL_FORM)
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction()
		-- TODO: handle Glyph of the Stag (separate Flight Form)
		-- TODO: handle Glyph of Travel (TF = ground mount OOC)
		local mountOK = SecureCmdOptionParse(MOUNT_CONDITION)
		if mountOK and IsPlayerSpell(TRAVEL_FORM_ID) and CanFly() then
			return format("/cast %s", TRAVEL_FORM)
		elseif mountOK and not IsPlayerMoving() and HasRidingSkill() then
			return "/run C_MountJournal.Summon(0)"
		elseif IsPlayerSpell(TRAVEL_FORM_ID) and (IsOutdoors() or IsSubmerged()) then
			return format("/cast [nomounted,noform] %s", TRAVEL_FORM)
		elseif IsPlayerSpell(CAT_FORM_ID) then
			return format("/cast [nomounted,noform] %s", CAT_FORM)
		end
	end

------------------------------------------------------------------------

elseif PLAYER_CLASS == "SHAMAN" then

	local GHOST_WOLF_ID = 2645
	local GHOST_WOLF = GetSpellInfo(GHOST_WOLF_ID)

	MOUNT_CONDITION = format("[outdoors,nocombat,nomounted,noform,novehicleui,nomod:%s]", MOD_TRAVEL_FORM)
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction()
		-- TODO: handle Glyph of Ghostly Speed (GW = ground mount OOC)
		if not IsPlayerMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			return "/run C_MountJournal.Summon(0)"
		elseif IsPlayerSpell(GHOST_WOLF_ID) then
			return format("/cast [nomounted,noform] %s", GHOST_WOLF)
		end
	end

------------------------------------------------------------------------

elseif PLAYER_CLASS == "WARLOCK" then

	function GetAction()
		if not IsPlayerMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			-- get out of Metamorphosis
			return "/cancelform [form]\n/run C_MountJournal.Summon(0)"
		end
	end

------------------------------------------------------------------------

else

	function GetAction()
		if not IsPlayerMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			return "/run C_MountJournal.Summon(0)"
		end
	end

end

------------------------------------------------------------------------

function button:Update()
	if InCombatLockdown() then return end

	local useMount
	local safetyCheck = not GetCVarBool("autoDismountFlying") and format(SAFE_DISMOUNT, MOD_DISMOUNT_FLYING)

	if GetItemCount(37011) > 0 and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
		-- Magic Broom
		useMount = "/use " .. GetItemInfo(37011)
	else
		useMount = GetAction()
	end
	self:SetAttribute("macrotext", strtrim(strjoin("\n", useMount or "", safetyCheck or "", DISMOUNT)))
end

button:SetScript("PreClick", button.Update)

------------------------------------------------------------------------

button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("PLAYER_REGEN_DISABLED")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("UPDATE_BINDINGS")

button:SetScript("OnEvent", function(self, event)
	if event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
		ClearOverrideBindings(self)
		local a, b = GetBindingKey("DISMOUNT")
		if a then
			SetOverrideBinding(self, false, a, "CLICK MountMeButton:LeftButton")
		end
		if b then
			SetOverrideBinding(self, false, b, "CLICK MountMeButton:LeftButton")
		end
	else
		self:Update()
	end
end)