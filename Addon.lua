--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright (c) 2014-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/MountMe
------------------------------------------------------------------------
	TODO:
	- Cancel transformation buffs that block mounting?
	- Handle shaman Glyph of Ghostly Speed (GW = ground mount OOC)
	- Verify that monk Roll works works when morphed into Chi Torpedo talent
	- Ignore garrison stables training mounts
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

local _, ns = ...
local _, PLAYER_CLASS = UnitClass("player")

local GetItemCount, GetSpellInfo, HasDraenorZoneAbility, IsOutdoors, IsPlayerMoving, IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse
    = GetItemCount, GetSpellInfo, HasDraenorZoneAbility, IsOutdoors, IsPlayerMoving, IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse

------------------------------------------------------------------------

local GARRISON_ABILITY = GetSpellInfo(161691)
local ACTION_MOUNT = "/run C_MountJournal.SummonByID(0)"
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
	local hasSkill = IsSpellKnown(90265) and 310 or IsSpellKnown(34091) and 280 or IsSpellKnown(34090) and 150
	if flyingOnly then
		return hasSkill
	end
	return hasSkill or IsSpellKnown(33391) and 100 or IsSpellKnown(33388) and 60
end

local function HasGlyph(id)
	for i = 1, NUM_GLYPH_SLOTS do
		local unlocked, glyphType, tooltipIndex, glyphSpellID, icon, glyphID = GetGlyphSocketInfo(i)
		if id == glyphID then
			return true
		end
	end
end

local GetAction

------------------------------------------------------------------------

local button = CreateFrame("Button", "MountMeButton", nil, "SecureActionButtonTemplate")
button:SetAttribute("type", "macro")

------------------------------------------------------------------------
if PLAYER_CLASS == "DRUID" then

	local CAT_FORM_ID, TRAVEL_FORM_ID, FLIGHT_FORM_ID = 768, 783, 165962
	local CAT_FORM, TRAVEL_FORM, FLIGHT_FORM = GetSpellInfo(CAT_FORM_ID), GetSpellInfo(TRAVEL_FORM_ID), GetSpellInfo(FLIGHT_FORM_ID)
	local STAG_GLYPH, TRAVEL_GLYPH = 164, 1127

	local BLOCKING_FORMS
	local orig_DISMOUNT = DISMOUNT

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. "]"
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction(force)
		-- TODO: handle Glyph of Travel (TF = ground mount OOC)
		-- ^ Should already work -- if the player is moving, they'll use
		--   the travel form, otherwise they'll use a regular mount.
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

		local mountOK, flightOK = SecureCmdOptionParse(MOUNT_CONDITION), ns.CanFly()
		if mountOK and flightOK and IsPlayerSpell(FLIGHT_FORM_ID) then
			return "/cast " .. FLIGHT_FORM
		elseif mountOK and flightOK and IsPlayerSpell(TRAVEL_FORM_ID) then
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
	or PLAYER_CLASS == "MONK"        and 109132 -- Roll
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

local GetMountAction
do
	local GetMountInfoByID = C_MountJournal.GetMountInfoByID
	local SUMMON = "/run C_MountJournal.SummonByID(%d)"
	local SEA_LEGS = GetSpellInfo(73701)

	local SEA_TURTLE = 312
	local VASHJIR_SEAHORSE = 373
	local SUBDUED_SEAHORSE = 420
	local CHAFFEUR = UnitFactionGroup("player") == "Horde" and 679 or 678

	local AQBUGS = {
		117, -- Blue Qiraji Battle Tank
		120, -- Green Qiraji Battle Tank
		118, -- Red Qiraji Battle Tank
		119, -- Yellow Qiraji Battle Tank
	}

	local hasBugs = {}

	function GetMountAction()
		-- Magic Broom
		-- Instant but not usable in combat
		if IsMoving() then
			return GetItemCount(37011) > 0 and "/use " .. GetItemInfo(37011)
		end

		-- Nagrand garrison mounts: Frostwolf War Wolf, Telaari Talbuk
		-- Can be summoned in combat
		local name, _, _, _, _, _, id = GetSpellInfo(GARRISON_ABILITY)
		if (id == 164222 or id == 165803) and HasDraenorZoneAbility() and SecureCmdOptionParse(GARRISON_MOUNT_CONDITION) and (UnitAffectingCombat("player") or not ns.CanFly()) then
			return "/use " .. name
		end

		if not not SecureCmdOptionParse(MOUNT_CONDITION..",nomod:"..MOD_TRAVEL_FORM) then
			return
		end

		-- Use Chaffeured Chopper if no riding skill
		if not HasRidingSkill() then
			local _, _, _, _, chaffeur = GetMountInfoByID(CHAFFEUR)
			if chaffeur then
				return format(SUMMON, CHAFFEUR)
			else
				return
			end
		end

		-- Use underwater mounts while swimming
		if IsSubmerged() then
			-- Vashj'ir Seahorse (550% swim speed in Vashj'ir)
			local _, _, _, _, seahorse = GetMountInfoByID(VASHJIR_SEAHORSE)
			if seahorse then return format(SUMMON, VASHJIR_SEAHORSE) end

			-- Subdued Seahorse (400% swim speed in Vashj'ir, 160% swim speed elsewhere)
			_, _, _, _, seahorse = GetMountInfoByID(SUBDUED_SEAHORSE)
			if seahorse and UnitBuff("player", SEA_LEGS) then return format(SUMMON, SUBDUED_SEAHORSE) end

			-- Sea Turtle (160% swim speed)
			local _, _, _, _, turtle = GetMountInfoByID(SEA_TURTLE)
			if turtle and seahorse then
				return format(SUMMON, math.random(1, 2) == 1 and SEA_TURTLE or SUBDUED_SEAHORSE)
			elseif turtle then
				return format(SUMMON, SEA_TURTLE)
			end
		end

		-- Use Qiraji Battle Tanks while in the Temple of Ahn'qiraj
		-- If any are marked as favorites, ignore ones that aren't
		local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
		if instanceMapID == 531 then
			local numBugs, onlyFavorites = 0
			for i = 1, #AQBUGS do
				local bug = AQBUGS[i]
				local name, _, _, _, usable, _, favorite = GetMountInfoByID(bug)
				if usable and not (onlyFavorites and not favorite) then
					if favorite and not onlyFavorites then
						numBugs = 0
						onlyFavorites = true
					end
					numBugs = numBugs + 1
					hasBugs[numBugs] = bug
				end
			end
			if numBugs > 0 then
				return format(SUMMON, hasBugs[math.random(numBugs)])
			end
		end
	end
end

------------------------------------------------------------------------

function button:Update()
	if InCombatLockdown() then return end

	self:SetAttribute("macrotext", strtrim(strjoin("\n",
		GetMountAction() or GetAction() or "",
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
