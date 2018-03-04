--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright 2014-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/phanx-wow/MountMe
----------------------------------------------------------------------]]

local enabled, hooked, setting

local function GetFavoriteMounts()
	local favorites = {}
	for i = 1, C_MountJournal.GetNumDisplayedMounts() do
		local _, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
		if not isFavorite then
			break
		end
		favorites[mountID] = true
	end
	return favorites
end

local function SetFavoriteMounts(favorites)
	setting = true

	local i = 1
	local n = C_MountJournal.GetNumDisplayedMounts()
	while i <= n do
		local name, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
		if isFavorite and not favorites[mountID] then
			print("Remove favorite:", name)
			C_MountJournal.SetIsFavorite(i, false)
			-- This mount moves down the list,
			-- next mount moves up to this index.
		else
			if favorites[mountID] and not isFavorite then
				print("Add favorite:", name)
				C_MountJournal.SetIsFavorite(i, true)
				-- This mount moves up the list,
				-- previous mount moves down to this index,
				-- next mount is still at next index.
			end
			-- Go to next index.
			i = i + 1
		end
	end

	setting = false
end

local function SetIsFavorite(index, isFavorite)
	if setting or not active then return end

	-- By the time this post-hook is running, the indices have already changed,
	-- and the index passed to SetIsFavorite doesn't map to the mount that was
	-- added or removed as a favorite. We'll just get the new list and compare.

	local favorites = GetFavoriteMounts()
	local action = isFavorite and "Add" or "Remove"
	local a = isFavorite and favorites or MountMeFavorites
	local b = isFavorite and MountMeFavorites or favorites

	for mountID in pairs(a) do
		if not b[mountID] then
			MountMeFavorites[mountID] = isFavorite and true or nil
			local name = C_MountJournal.GetMountInfoByID(mountID)
			print(action, "favorite by user:", name)
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	MountMeSettings = MountMeSettings or {}

	if MountMeSettings.favoritesPerChar then
		if not MountMeFavorites then
			MountMeFavorites = GetFavoriteMounts()
		else
			SetFavoriteMounts(MountMeFavorites)
		end
		hooksecurefunc(C_MountJournal, "SetIsFavorite", SetIsFavorite)
		hooked = true
		active = true
	end
end)

SLASH_MOUNTME1 = "/mountme"
SlashCmdList["MOUNTME"] = function(cmd)
	cmd = (cmd or ""):lower()

	if cmd == "char" then
		local v = not MountMeSettings.favoritesPerChar
		MountMeSettings.favoritesPerChar = v
		if v then
			MountMeFavorites = GetFavoriteMounts()
			if not hooked then
				hooksecurefunc(C_MountJournal, "SetIsFavorite", SetIsFavorite)
				hooked = true
			end
			active = true
			DEFAULT_CHAT_FRAME:AddMessage(string.format("%sMountMe:|r %s", NORMAL_FONT_COLOR_CODE,
				"Now saving favorite mounts per-character."))
		else
			active = false
			DEFAULT_CHAT_FRAME:AddMessage(string.format("%sMountMe:|r %s", NORMAL_FONT_COLOR_CODE,
				"Now saving favorite mounts account-wide."))
		end
	return end

	DEFAULT_CHAT_FRAME:AddMessage(string.format("%sMountMe:|r Version %s loaded. %s", NORMAL_FONT_COLOR_CODE,
		GetAddOnMetadata("MountMe", "Version"),
		"Available commands:"))
	DEFAULT_CHAT_FRAME:AddMessage(string.format("- %s%s|r - %s (%s%s|r)", NORMAL_FONT_COLOR_CODE,
		"char", "Toggle saving favorite mounts per-character",
		MountMeSettings.favoritesPerChar and GREEN_FONT_COLOR_CODE or GRAY_FONT_COLOR_CODE,
		MountMeSettings.favoritesPerChar and "ON" or "OFF"))
end
