--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright 2014-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/phanx-wow/MountMe
----------------------------------------------------------------------]]

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(f, e, ...) return f[e](f, ...) end)
f:RegisterEvent("PLAYER_LOGIN")

function f:PLAYER_LOGIN()
	MountMeSettings = MountMeSettings or {}

	if MountMeSettings.favoritesPerChar then
		if not MountMeFavorites then
			MountMeFavorites = self:GetFavoriteMounts()
		else
			self:SetFavoriteMounts(MountMeFavorites)
		end
		hooksecurefunc(C_MountJournal, "SetIsFavorite", self.SetIsFavorite)
		self.hooked = true
		self.active = true
	end
end

function f:MOUNT_JOURNAL_SEARCH_UPDATED()
	if self.settingFavorites then
		self:SetFavoriteMounts(MountMeFavorites)
	end
end

function f:GetFavoriteMounts()
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

function f:SetFavoriteMounts(favorites)
	self.settingFavorites = true
	self:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
	MountJournal:UnregisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")

	for i = 1, C_MountJournal.GetNumDisplayedMounts() do
		local name, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
		if isFavorite and not favorites[mountID] then
			return C_MountJournal.SetIsFavorite(i, false)
		elseif favorites[mountID] and not isFavorite then
			return C_MountJournal.SetIsFavorite(i, true)
		end
	end

	self.settingFavorites = false
	self:UnregisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
	MountJournal:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
	if MountJournal:IsVisible() then
		MountJournal_FullUpdate(MountJournal)
	end
end

function f.SetIsFavorite(index, isFavorite)
	local self = f
	if self.settingFavorites or not self.active then return end

	-- By the time this post-hook is running, the indices have already changed,
	-- and the index passed to SetIsFavorite doesn't map to the mount that was
	-- added or removed as a favorite. We'll just get the new list and compare.

	local favorites = self:GetFavoriteMounts()
	local action = isFavorite and "Add" or "Remove"
	local a = isFavorite and favorites or MountMeFavorites
	local b = isFavorite and MountMeFavorites or favorites

	for mountID in pairs(a) do
		if not b[mountID] then
			MountMeFavorites[mountID] = isFavorite and true or nil
			local name = C_MountJournal.GetMountInfoByID(mountID)
		end
	end
end

SLASH_MOUNTME1 = "/mountme"
SlashCmdList["MOUNTME"] = function(cmd)
	local self = f
	cmd = (cmd or ""):lower()

	if cmd == "char" then
		local v = not MountMeSettings.favoritesPerChar
		MountMeSettings.favoritesPerChar = v
		if v then
			MountMeFavorites = self:GetFavoriteMounts()
			if not self.hooked then
				hooksecurefunc(C_MountJournal, "SetIsFavorite", self.SetIsFavorite)
				self.hooked = true
			end
			self.active = true
			DEFAULT_CHAT_FRAME:AddMessage(string.format("%sMountMe:|r %s", NORMAL_FONT_COLOR_CODE,
				"Now saving favorite mounts per-character."))
		else
			self.active = false
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
