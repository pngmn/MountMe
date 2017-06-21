--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright (c) 2014-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/MountMe
------------------------------------------------------------------------
	TODO:
	- Cancel transformation buffs that block mounting?
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

local ACTION_MOUNT = "/click MountJournalSummonRandomFavoriteButton" -- "/run C_MountJournal.SummonByID(0)"
local ACTION_MOUNT_PATTERN = gsub(ACTION_MOUNT, "[%(%)]", "%%%1")

local SpellID = {
	["Cat Form"] = 768,
	["Darkflight"] = 68992,
	["Garrison Ability"] = 161691,
	["Ghost Wolf"] = 2645,
	["Flight Form"] = 165962,
	["Summon Mechashredder 5000"] = 164050,
	["Travel Form"] = 783,
}

local SpellName = {}
for k, v in pairs(SpellID) do
	SpellName[k] = GetSpellInfo(v)
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
		if mountOK and flightOK and IsPlayerSpell(SpellID["Travel Form"]) then
			return "/cast " .. TRAVEL_FORM
		elseif mountOK and not IsPlayerMoving() and HasRidingSkill() then
			return ACTION_MOUNT
		elseif IsPlayerSpell(SpellID["Travel Form"]) and (IsOutdoors() or IsSubmerged()) then
			return "/cast [nomounted,noform] " .. SpellName["Travel Form"]
		elseif IsPlayerSpell(SpellID["Cat Form"]) then
			return "/cast [nomounted,noform" .. BLOCKING_FORMS .. "] " .. SpellName["Cat Form"]
		end
	end

------------------------------------------------------------------------
elseif PLAYER_CLASS == "SHAMAN" then

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. "]"
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction()
		if not IsPlayerMoving() and HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
			return ACTION_MOUNT
		elseif IsPlayerSpell(SpellID["Ghost Wolf"]) then
			return "/cast [nomounted,noform] " .. SpellName["Ghost Wolf"]
		end
	end

------------------------------------------------------------------------
else
	local ClassActionIDs = {
		196555, -- Demon Hunter: Netherwalk (1.5m)
		125883, -- Monk: Zen Flight
		115008, -- Monk: Chi Torpedo (2x 20s)
		109132, -- Monk: Roll (2x 20s)
		190784, -- Paladin: Divine Speed (45s)
		202273, -- Paladin: Seal of Light
		  2983, -- Rogue: Sprint (1m)
		111400, -- Warlock: Burning Rush
		 68992, -- Worgen: Darkflight (2m)
	}
	local ClassActionLimited = {
		[125883] = function(combat) return combat or IsIndoors() end, -- Zen Flight
	}

	function GetAction()
		local combat = UnitAffectingCombat("player")

		local classAction
		for i = 1, #ClassActionIDs do
			local id = ClassActionIDs[i]
			if IsPlayerSpell(id) and not (ClassActionLimited[id] and ClassActionLimited[id](combat)) then
				classAction = GetSpellInfo(id)
				break
			end
		end

		local moving = IsPlayerMoving()
		if classAction and (moving or combat) then
			return "/cast [nomounted,novehicleui] " .. classAction
		elseif not moving then
			local action
			if HasRidingSkill() and SecureCmdOptionParse(MOUNT_CONDITION) then
				action = ACTION_MOUNT
			end
			if classAction and PLAYER_CLASS == "WARLOCK" then
				-- TODO: why is /cancelform in here???
				action = "/cancelaura " .. classAction .. (action and ("\n/cancelform [form]\n" .. action) or "")
			end
			return action
		end
	end
end

------------------------------------------------------------------------

local GetMountAction
do
	local GetMountInfoByID = C_MountJournal.GetMountInfoByID
	local SEA_LEGS = GetSpellInfo(73701)

	local SEA_TURTLE = 312
	local VASHJIR_SEAHORSE = 373
	local SUBDUED_SEAHORSE = 420
	local CHAUFFEUR = UnitFactionGroup("player") == "Horde" and 679 or 678

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
		if IsPlayerMoving() and GetItemCount(37011) > 0 then
			return "/use " .. GetItemInfo(37011)
		end

		-- Nagrand garrison mounts: Frostwolf War Wolf, Telaari Talbuk
		-- Can be summoned in combat
		if GetZoneAbilitySpellInfo() == SpellID["Garrison Ability"] then
			local _, _, _, _, _, _, id = GetSpellInfo(SpellName["Garrison Ability"])
			if (id == 164222 or id == 165803) and SecureCmdOptionParse(GARRISON_MOUNT_CONDITION) and (UnitAffectingCombat("player") or not ns.CanFly()) then
				return "/cast " .. SpellName["Garrison Ability"]
			end
		end

		if not not SecureCmdOptionParse(MOUNT_CONDITION .. ",nomod:" .. MOD_TRAVEL_FORM) then
			return
		end

		-- Use Chauffeured Chopper if no riding skill
		if not HasRidingSkill() then
			local _, _, _, _, chauffeur = GetMountInfoByID(CHAUFFEUR)
			if chauffeur then
				return "/cast " .. CHAUFFEUR
			else
				return
			end
		end

		-- Use underwater mounts while swimming
		if IsSubmerged() then
			-- Vashj'ir Seahorse (550% swim speed in Vashj'ir)
			local seahorseName, _, _, _, seahorseUsable = GetMountInfoByID(VASHJIR_SEAHORSE)
			if seahorseUsable then return "/cast " .. seahorseName end

			-- Subdued Seahorse (400% swim speed in Vashj'ir, 160% swim speed elsewhere)
			seahorseName, _, _, _, seahorseUsable = GetMountInfoByID(SUBDUED_SEAHORSE)
			if seahorseUsable and UnitBuff("player", SEA_LEGS) then return "/cast " .. seahorseName end

			-- Sea Turtle (160% swim speed)
			local turtleName, _, _, _, turtleUsable = GetMountInfoByID(SEA_TURTLE)
			if turtleUsable and seahorseUsable then
				return "/cast " .. (math.random(1, 2) == 1 and turtleName or seahorseName)
			elseif turtle then
				return "/cast " .. turtleName
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
					hasBugs[numBugs] = name
				end
			end
			if numBugs > 0 then
				return "/cast " .. hasBugs[math.random(numBugs)]
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

button:RegisterEvent("PLAYER_LOGIN")

button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("UPDATE_BINDINGS")

button:RegisterEvent("LEARNED_SPELL_IN_TAB")
button:RegisterEvent("PLAYER_REGEN_DISABLED")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
button:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
button:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- zone changed
button:RegisterEvent("ZONE_CHANGED") -- indoor/outdoor transition

button:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if not MountJournalSummonRandomFavoriteButton then
			CollectionsJournal_LoadUI()
		end
	elseif event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
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
