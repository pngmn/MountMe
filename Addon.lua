--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright 2014-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/phanx-wow/MountMe
------------------------------------------------------------------------
	TODO:
	- Cancel transformation buffs that block mounting?
	- Ignore garrison stables training mounts
----------------------------------------------------------------------]]

local MOD_TRAVEL_FORM = "ctrl"
local MOD_DISMOUNT_FLYING = "alt"
local MOD_REPAIR_MOUNT = "shift"

------------------------------------------------------------------------

local _, ns = ...
local _, PLAYER_CLASS = UnitClass("player")

local LibFlyable = LibStub("LibFlyable")

local GetItemCount, GetSpellInfo, GetZoneAbilitySpellInfo, IsOutdoors, IsPlayerMoving
    = GetItemCount, GetSpellInfo, GetZoneAbilitySpellInfo, IsOutdoors, IsPlayerMoving

local IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse
    = IsPlayerSpell, IsSpellKnown, IsSubmerged, SecureCmdOptionParse

local MOUNT_CONDITION = "[nocombat,outdoors,nomounted,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"
local GARRISON_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"
local REPAIR_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. ",mod:" .. MOD_REPAIR_MOUNT .. "]"

local SAFE_DISMOUNT = "/stopmacro [flying,nomod:" .. MOD_DISMOUNT_FLYING .. "]"
local DISMOUNT = [[
/leavevehicle [canexitvehicle]
/dismount [mounted]
]]

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
for name, id in pairs(SpellID) do
	SpellName[name] = GetSpellInfo(id)
end

local ItemID = {
	["Magic Broom"] = 37011,
}

local ItemName = {}
for name, id in pairs(ItemID) do
	ItemName[name] = GetItemInfo(id)
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local function GetOverrideMount()
	local combat = UnitAffectingCombat("player")

	-- Magic Broom
	-- Instant but not usable in combat
	if not combat and GetItemCount(ItemID["Magic Broom"]) > 0 then
		return "/use " .. ItemName["Magic Broom"]
	end

	-- Nagrand garrison mounts: Frostwolf War Wolf, Telaari Talbuk
	-- Can be summoned in combat
	if GetZoneAbilitySpellInfo() == SpellID["Garrison Ability"] then
		local _, _, _, _, _, _, id = GetSpellInfo(SpellName["Garrison Ability"])
		if (id == 164222 or id == 165803)
		and SecureCmdOptionParse(GARRISON_MOUNT_CONDITION)
		and (UnitAffectingCombat("player") or not LibFlyable:IsFlyableArea()) then
			return "/cast " ..   SpellName["Garrison Ability"]
		end
	end
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local GetMount

do
	local GROUND, FLYING, SWIMMING = 1, 2, 3

	local GetMountInfoByID = C_MountJournal.GetMountInfoByID
	local GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID

	local mountTypeInfo = {
		[230] = {100,99,0}, -- ground -- 99 flying to use in flying areas if the player doesn't have any flying mounts as favorites
		[231] = {20,0,60},  -- aquatic
		[232] = {0,0,450},  -- Abyssal Seahorse -- only in Vashj'ir
		[241] = {101,0,0},  -- Qiraji Battle Tanks -- only in Temple of Ahn'Qiraj
		[247] = {99,310,0}, -- Red Flying Cloud
		[248] = {99,310,0}, -- flying -- 99 ground to deprioritize in non-flying zones if any non-flying mounts are favorites
		[254] = {0,0,60},   -- Subdued Seahorse -- +300% swim speed in Vashj'ir, +60% swim speed elsewhere
		[269] = {100,0,0},  -- Water Striders
		[284] = {60,0,0},   -- Chauffeured Chopper
	}

	local flexMounts = { -- flying mounts that look OK on the ground
		[530] = true, -- Armored Skyscreamer
		[864] = true, -- Ban-Lu, Grandmaster's Companion
		[376] = true, -- Celestial Steed
		[600] = true, -- Dread Raven
		[888] = true, -- Fraseer's Raging Tempest
		[532] = true, -- Ghastly Charger
		[594] = true, -- Grinning Reaver
		[219] = true, -- Headless Horseman's Mount
		[547] = true, -- Hearthsteed
		[885] = true, -- Highlord's Golden Charger
		[894] = true, -- Highlord's Valorous Charger
		[892] = true, -- Highlord's Vengeful Charger
		[983] = true, -- Highlord's Vigilant Charger
		[763] = true, -- Illidari Felstalker
		[468] = true, -- Imperial Quilen
		[363] = true, -- Invincible
		[552] = true, -- Ironbound Wraithcharger
		[457] = true, -- Jade Panther
		[451] = true, -- Jeweled Onyx Panther
		[932] = true, -- Lightforged Warframe
		[949] = true, -- Luminous Starseeker
		[845] = true, -- Mechanized Lumber Extractor
		[741] = true, -- Mystic Runesaber
		[931] = true, -- Netherlord's Accursed Wrathsteed
		[930] = true, -- Netherlord's Brimstone Wrathsteed
		[898] = true, -- Netherlord's Chaotic Wrathsteed
		[455] = true, -- Obsidian Panther
		[458] = true, -- Ruby Panther
		[456] = true, -- Sapphire Panther
		[522] = true, -- Sky Golem
		[868] = true, -- SLayer's Felbroken Shrieker
		[779] = true, -- Spirit of Eche'ro
		[459] = true, -- Sunstone Panther
		[523] = true, -- Swift Windsteed
		[439] = true, -- Tyrael's Charger
		[593] = true, -- Warforged Nightmare
		[421] = true, -- Winged Guardian
	}

	local zoneMounts = { -- special mounts that don't need to be favorites
		[678] = true, -- Chauffeured Mechano-Hog
		[679] = true, -- Chauffeured Mekgineer's Chopper
		[312] = true, -- Sea Turtle
		[420] = true, -- Subdued Seahorse
		[373] = true, -- Vashj'ir Seahorse
		[117] = true, -- Blue Qiraji Battle Tank
		[120] = true, -- Green Qiraji Battle Tank
		[118] = true, -- Red Qiraji Battle Tank
		[119] = true, -- Yellow Qiraji Battle Tank
		[1166] = true, -- Great Sea Ray
		[1258] = true, -- Fabious
		[312] = true, -- Sea Turtle
		[420] = true, -- Subdued Seahorse
		[1169] = true, -- Surf Jelly
		[125] = true, -- Riding Turtle
		[373] = true, -- Vashj'ir Seahorse
		[838] = true, -- Fathom Dweller
		[982] = true, -- Pond Nettle
		[1208] = true, -- Saltwater Seahorse
		[1262] = true, -- Inkscale Deepseeker

	local repairMounts = {
		[280] = true, -- Traveler's Tundra Mammoth
		[284] = true, -- Traveler's Tundra Mammoth
		[460] = true, -- Grand Expedition Yak
		[1039] = true, -- Mighty Caravan Brutosaur
	}

	local vashjirMaps = {
		[204] = true, -- Abyssal Depths
		[201] = true, -- Kelp'thar Forest
		[205] = true, -- Shimmering Expanse
		[203] = true, -- Vashj'ir
	}

	local mountIDs = C_MountJournal.GetMountIDs()
	local randoms = {}

	local function FillMountList(targetType)
		-- print("Looking for:", targetType == SWIMMING and "SWIMMING" or targetType == FLYING and "FLYING" or "GROUND")
		wipe(randoms)

		local bestSpeed = 0
		local mapID = C_Map.GetBestMapForUnit("player")
		for i = 1, #mountIDs do
			local mountID = mountIDs[i]
			local name, spellID, _, _, isUsable, _, isFavorite = GetMountInfoByID(mountID)
			if isUsable and (isFavorite or zoneMounts[mountID]) then
				local _, _, sourceText, isSelfMount, mountType = GetMountInfoExtraByID(mountID)
				local speed = mountTypeInfo[mountType][targetType]
				if speed == 99 and flexMounts[mountID] then
					speed = 100
				elseif mountType == 254 and vashjirMaps[mapID] then -- Subdued Seahorse is faster in Vashj'ir
					speed = 300
				elseif mountType == 232 and not vashjirMaps[mapID] then -- Abyssal Seahorse only works in Vashj'ir
					speed = -1
				end
				-- print("Checking:", name, mountType, "@", speed, "vs", bestSpeed)
				if speed > 0 and speed >= bestSpeed then
					if speed > bestSpeed then
						bestSpeed = speed
						wipe(randoms)
					end
					tinsert(randoms, spellID)
				end
			end
		end
		-- print("Found", #randoms, "possibilities")
		return randoms
	end

	local function IsUnderwater()
		local B, b, _, _, a = "BREATH", GetMirrorTimerInfo(2)
		return (IsSwimming() and ((b==B) or (b==B and a <= -1)))
	end

	function GetMount()
		local targetType = IsUnderwater() and SWIMMING or LibFlyable:IsFlyableArea() and FLYING or GROUND
		FillMountList(targetType)

		if #randoms == 0 and targetType == SWIMMING then
			-- Fall back to non-swimming mounts
			targetType = LibFlyable:IsFlyableArea() and FLYING or GROUND
			FillMountList(targetType)
		end

		if #randoms > 0 then
			local spellID = randoms[random(#randoms)]
			return "/use " .. GetSpellInfo(spellID)
		end
	end

	function GetRepairMount()
		local highestID = 0
		local preferredSpellID
		for k in pairs(repairMounts) do
			local _, spellID, _, _, isUsable = GetMountInfoByID(k)
			if isUsable then
				if k > highestID then
					highestID = k
					preferredSpellID = spellID
				end
			end
		end
		
		if preferredSpellID then
			return "/use " .. GetSpellInfo(preferredSpellID)
		end
	end
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local GetAction

local function HasRidingSkill(flyingOnly)
	local hasSkill = IsSpellKnown(90265) and 310 or IsSpellKnown(34091) and 280 or IsSpellKnown(34090) and 150
	if flyingOnly then
		return hasSkill
	end
	return hasSkill or IsSpellKnown(33391) and 100 or IsSpellKnown(33388) and 60
end

local function HasGlyph(id)
	for i = 1, NUM_GLYPH_SLOTS do
		local _, _, _, _, _, glyphID = GetGlyphSocketInfo(i)
		if id == glyphID then
			return true
		end
	end
end

------------------------------------------------------------------------

if PLAYER_CLASS == "DRUID" then
	--[[
	Travel Form
	- outdoors,nocombat,flyable +310%
	- outdoors,nocombat +100% (level 38, new in 7.1)
	- outdoors +40%
	--]]

	local BLOCKING_FORMS
	local orig_DISMOUNT = DISMOUNT

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"

	function GetAction(force)
		if force or not BLOCKING_FORMS then
			BLOCKING_FORMS = "" -- in case of force
			for i = 1, GetNumShapeshiftForms() do
				local icon = strlower(GetShapeshiftFormInfo(i))
				if not strmatch(icon, "spell_nature_forceofnature") then -- Moonkin Form OK
					if BLOCKING_FORMS == "" then
						BLOCKING_FORMS = ":" ..   i
					else
						BLOCKING_FORMS = BLOCKING_FORMS ..   "/" ..   i
					end
				end
			end
			MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform" .. BLOCKING_FORMS .. ",novehicleui,nomod:" .. MOD_TRAVEL_FORM .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"
		end

		local mountOK, flightOK = SecureCmdOptionParse(MOUNT_CONDITION), LibFlyable:IsFlyableArea()
		if mountOK and flightOK and IsPlayerSpell(SpellID["Travel Form"]) then
			return "/cast " ..   SpellName["Travel Form"]
		end

		local mount = mountOK and not IsPlayerMoving() and GetMount()
		if mount then
			return mount
		elseif IsPlayerSpell(SpellID["Travel Form"]) and (IsOutdoors() or IsSubmerged()) then
			return "/cast [nomounted,noform] " ..   SpellName["Travel Form"]
		elseif IsPlayerSpell(SpellID["Cat Form"]) then
			return "/cast [nomounted,noform" ..   BLOCKING_FORMS ..   "] " ..   SpellName["Cat Form"]
		end
	end

------------------------------------------------------------------------
elseif PLAYER_CLASS == "SHAMAN" then

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" .. MOD_TRAVEL_FORM .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"

	function GetAction()
		local mount = SecureCmdOptionParse(MOUNT_CONDITION) and not IsPlayerMoving() and GetMount()
		if mount then
			return mount
		elseif IsPlayerSpell(SpellID["Ghost Wolf"]) then
			return "/cast [nomounted,noform] " ..   SpellName["Ghost Wolf"]
		end
	end

------------------------------------------------------------------------
else
	local ClassActionIDs = {
		196555, -- Demon Hunter: Netherwalk (1.5m)
		195072, -- Demon Hunter: Fel Rush (2x 10s)
		125883, -- Monk: Zen Flight
		115008, -- Monk: Chi Torpedo (2x 20s)
		109132, -- Monk: Roll (2x 20s)
		190784, -- Paladin: Divine Speed (45s)
		202273, -- Paladin: Seal of Light
		  2983, -- Rogue: Sprint (1m)
		111400, -- Warlock: Burning Rush
		 68992, -- Worgen: Darkflight (2m)
	}
	local ClassActionBlocked = {
		[125883] = function(combat) return combat or IsIndoors() end, -- Zen Flight
	}

	function GetAction()
		local combat = UnitAffectingCombat("player")

		local classAction
		for i = 1, #ClassActionIDs do
			local id = ClassActionIDs[i]
			if IsPlayerSpell(id) and not (ClassActionBlocked[id] and ClassActionBlocked[id](combat)) then
				classAction = GetSpellInfo(id)
				break
			end
		end

		local moving = IsPlayerMoving()
		if classAction and (moving or combat) then
			return "/cast [nomounted,novehicleui] " ..   classAction
		elseif not moving then
			local action
			if SecureCmdOptionParse(REPAIR_MOUNT_CONDITION) then
				action = GetRepairMount()
			end
			if SecureCmdOptionParse(GARRISON_MOUNT_CONDITION) then
				action = GetMount()
			end
			if classAction and PLAYER_CLASS == "WARLOCK" then
				-- TODO: why is /cancelform in here???
				action = "/cancelaura " ..   classAction ..   (action and ("\n/cancelform [form]\n" ..   action) or "")
			end
			return action
		end
	end
end

------------------------------------------------------------------------

local button = CreateFrame("Button", "MountMeButton", nil, "SecureActionButtonTemplate")
button:SetAttribute("type", "macro")

function button:Update()
	if InCombatLockdown() then return end

	self:SetAttribute("macrotext", strtrim(strjoin("\n",
		GetOverrideMount() or GetAction() or "",
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
