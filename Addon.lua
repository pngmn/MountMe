--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright (c) 2014-2015 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/MountMe
----------------------------------------------------------------------]]

local MOD_TRAVEL_FORM = "ctrl"
local MOD_DISMOUNT_FLYING = "shift"

------------------------------------------------------------------------

local MOUNT_CONDITION = "[outdoors,nocombat,nomounted,novehicleui]"
local GARRISON_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,nomod:"..MOD_TRAVEL_FORM.."]"
local SAFE_DISMOUNT = "/stopmacro [flying,nomod:"..MOD_DISMOUNT_FLYING.."]"
local DISMOUNT = [[
/leavevehicle [canexitvehicle]
/dismount [mounted]
]]

------------------------------------------------------------------------
-- TODO: cancel transformation buffs that block mounting?

local _, ns = ...
local _, PLAYER_CLASS = UnitClass("player")

local GetItemCount, GetSpellInfo, HasDraenorZoneAbility, IsOutdoors, IsPlayerMoving, IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse
    = GetItemCount, GetSpellInfo, HasDraenorZoneAbility, IsOutdoors, IsPlayerMoving, IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse

------------------------------------------------------------------------

local GARRISON_ABILITY = GetSpellInfo(161691)
local ACTION_MOUNT = "/run C_MountJournal.Summon(0)"
local ACTION_MOUNT_PATTERN = gsub(ACTION_MOUNT, "[%(%)]", "%%%1")

local castWhileMovingBuffs = {
	[GetSpellInfo(172106) or ""] = true, -- Aspect of the Fox
	[GetSpellInfo(108839) or ""] = PLAYER_CLASS == "MAGE"    or nil, -- Ice Floes
	[GetSpellInfo(79206)  or ""] = PLAYER_CLASS == "SHAMAN"  or nil, -- Spiritwalker's Grace
	[GetSpellInfo(137587) or ""] = PLAYER_CLASS == "WARLOCK" or nil, -- Kil'jaeden's Cunning
}

local function IsMoving()
	for buff in next, castWhileMovingBuffs do
		if UnitBuff("player", buff) then
			return false
		end
	end
	return IsPlayerMoving()
end

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

	local CAT_FORM_ID, TRAVEL_FORM_ID = 768, 783
	local CAT_FORM, TRAVEL_FORM = GetSpellInfo(CAT_FORM_ID), GetSpellInfo(TRAVEL_FORM_ID)

	local BLOCKING_FORMS
	local orig_DISMOUNT = DISMOUNT

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. "]"
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction(force)
		-- TODO: handle Glyph of the Stag (separate Flight Form)
		-- TODO: handle Glyph of Travel (TF = ground mount OOC)

		if force or not BLOCKING_FORMS then
			BLOCKING_FORMS = "" -- in case of force
			for i = 1, GetNumShapeshiftForms() do
				local icon = strlower(GetShapeshiftFormInfo(i))
				if not strmatch(icon, "spell_nature_forceofnature") then -- Moonkin Form OK
					if BLOCKING_FORMS == "" then
						BLOCKING_FORMS = ":" .. i
					else
						BLOCKING_FORMS = BLOCKING_FORMS .. "/" .. i
					end
				end
			end
			MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform" .. BLOCKING_FORMS .. ",novehicleui,nomod:" .. MOD_TRAVEL_FORM .. "]"
			DISMOUNT = orig_DISMOUNT .. "\n/cancelform [form" .. BLOCKING_FORMS .. "]"
		end

		local mountOK = SecureCmdOptionParse(MOUNT_CONDITION)
		if mountOK and IsPlayerSpell(TRAVEL_FORM_ID) and ns.CanFly() then
			return "/cast " .. TRAVEL_FORM
		elseif mountOK and not IsMoving() and HasRidingSkill() then
			return ACTION_MOUNT
		elseif IsPlayerSpell(TRAVEL_FORM_ID) and (IsOutdoors() or IsSubmerged()) then
			return "/cast [nomounted,noform] " .. TRAVEL_FORM
		elseif IsPlayerSpell(CAT_FORM_ID) then
			return "/cast [nomounted,noform" .. BLOCKING_FORMS .. "] " .. CAT_FORM
		end
	end

------------------------------------------------------------------------
elseif PLAYER_CLASS == "SHAMAN" then

	local GHOST_WOLF_ID = 2645
	local GHOST_WOLF = GetSpellInfo(GHOST_WOLF_ID)

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. "]"
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction()
		-- TODO: handle Glyph of Ghostly Speed (GW = ground mount OOC)
		if not IsMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			return ACTION_MOUNT
		elseif IsPlayerSpell(GHOST_WOLF_ID) then
			return "/cast [nomounted,noform] " .. GHOST_WOLF
		end
	end

------------------------------------------------------------------------
else
	local movingActionID
	=  PLAYER_CLASS == "DEATHKNIGHT" and 96268  -- Death's Advance
	or PLAYER_CLASS == "HUNTER"      and 5118   -- Aspect of the Cheetah
	or PLAYER_CLASS == "MAGE"        and 108843 -- Blazing Speed
	or PLAYER_CLASS == "MONK"        and 109132 -- Roll -- TODO: make sure it works when morphed into Chi Torpedo
	or PLAYER_CLASS == "PALADIN"     and 85599  -- Speed of Light
	or PLAYER_CLASS == "ROGUE"       and 2983   -- Sprint
	or PLAYER_CLASS == "WARLOCK"     and 111400 -- Burning Rush

	local movingAction = movingActionID and GetSpellInfo(movingActionID)

	function GetAction()
		local moving = IsMoving()
		if movingAction and IsPlayerSpell(movingActionID) and (moving or UnitAffectingCombat("player")) then
			return "/cast [nomounted,novehicleui] " .. movingAction
		elseif not moving then
			local action
			if HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
				action = ACTION_MOUNT
			end
			if PLAYER_CLASS == "WARLOCK" then
				action = "/cancelaura " .. movingAction .. (action and ("\n/cancelform [form]\n" .. action) or "")
			end
			return action
		end
	end

end

------------------------------------------------------------------------

function button:Update()
	if InCombatLockdown() then return end

	local useMount = GetAction()

	local name, _, _, _, _, _, id = GetSpellInfo(GARRISON_ABILITY)
	if (id == 164222 or id == 165803) and HasDraenorZoneAbility() and not IsMoving() and SecureCmdOptionParse(GARRISON_MOUNT_CONDITION) then
		-- Frostwolf War Wolf || Telaari Talbuk
		-- Can be summoned in combat
		useMount = gsub(useMount, ACTION_MOUNT_PATTERN, "/use [outdoors,nomod:" .. MOD_TRAVEL_FORM .."] " .. name, 1)
	elseif GetItemCount(37011) > 0 and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
		-- Magic Broom
		-- Instant but not usable in combat
		useMount = "/use [nomod:" .. MOD_TRAVEL_FORM .."] " .. GetItemInfo(37011) .. "\n" .. useMount
	end

	-- TODO: good way to ignore garrison stables training mounts

	self:SetAttribute("macrotext", strtrim(strjoin("\n",
		useMount or "",
		GetCVarBool("autoDismountFlying") and "" or SAFE_DISMOUNT,
		DISMOUNT
	)))
end

button:SetScript("PreClick", button.Update)

------------------------------------------------------------------------

button:RegisterEvent("LEARNED_SPELL_IN_TAB")
button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("PLAYER_REGEN_DISABLED")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
button:RegisterEvent("UPDATE_BINDINGS")
button:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
button:RegisterEvent("ZONE_CHANGED_NEW_AREA")

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
		self:Update(event == "UPDATE_SHAPESHIFT_FORMS") -- force extra update for druids
	end
end)