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

local _, ns = ...
local _, PLAYER_CLASS = UnitClass("player")

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
		elseif mountOK and not IsPlayerMoving() and HasRidingSkill() then
			return "/run C_MountJournal.Summon(0)"
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
		if not IsPlayerMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			return "/run C_MountJournal.Summon(0)"
		elseif IsPlayerSpell(GHOST_WOLF_ID) then
			return "/cast [nomounted,noform] " .. GHOST_WOLF
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
	if GetItemCount(37011) > 0 and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
		-- Magic Broom
		useMount = "/use " .. GetItemInfo(37011)
	elseif HasDraenorZoneAbility() then
		local name, _, _, _, _, _, id = GetSpellInfo(GetSpellInfo(161691))
		if id == 164222 or id == 165803 then
			-- Frostwolf War Wolf || Telaari Talbuk
			-- Can be summoned while moving and in combat
			useMount = "/use [outdoors] " .. name
		end
	end

	self:SetAttribute("macrotext", strtrim(strjoin("\n",
		useMount or GetAction() or "",
		GetCVarBool("autoDismountFlying") and "" or format(SAFE_DISMOUNT, MOD_DISMOUNT_FLYING),
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