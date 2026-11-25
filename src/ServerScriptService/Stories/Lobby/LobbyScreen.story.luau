--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const LobbyScreen = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/LobbySystem/SystemPackage/LobbyScreen"
)
const StoreCatalog = require("@game/ServerScriptService/Modules/Data/StoreCatalog")

const source = Vide.source

const ROLES = { "Top", "Jungle", "Mid", "Bot", "Support" }
const LONG_NAME = "SuperLongDisplayName_2026"
const FRIEND_NAMES = { "Kaito", "Mina", "Leo", "Sora", "Ivy", "Theo", "Nova", "Rex" }
-- Roblox's own account, so head shots load in the preview.
const SAMPLE_USER_ID = 1

const LobbyTypes = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/LobbySystem/SystemPackage/LobbyTypes"
)

type FriendView = LobbyTypes.FriendView
type HeroView = LobbyTypes.HeroView
type RoleSlot = LobbyTypes.RoleSlot
type SkinView = LobbyTypes.SkinView

local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

const HERO_IDS = sortedKeys(HeroCatalog.Heroes)
const SKIN_IDS = sortedKeys(StoreCatalog.Skins)

const CONTROLS = {
	Player = UILabs.Ordered(
		UILabs.ControlGroup({
			Coins = UILabs.Ordered(UILabs.Slider(3000, 0, 20000, 100), 1),
			-- Heroes owned, counted from the first in name order.
			OwnedHeroes = UILabs.Ordered(UILabs.Slider(5, 0, #HERO_IDS, 1), 2),
			OwnsSkins = UILabs.Ordered(false, 3),
			LongNames = UILabs.Ordered(false, 4),
		}),
		1
	),
	Friends = UILabs.Ordered(
		UILabs.ControlGroup({
			Online = UILabs.Ordered(UILabs.Slider(4, 0, 30, 1), 1),
			IsLoading = UILabs.Ordered(false, 2),
		}),
		2
	),
	State = UILabs.Ordered(
		UILabs.ControlGroup({
			IsMatchOver = UILabs.Ordered(false, 1),
			ShowsNotice = UILabs.Ordered(false, 2),
		}),
		3
	),
	Layout = UILabs.Ordered(
		UILabs.ControlGroup({
			IsCompact = UILabs.Ordered(false, 1),
		}),
		4
	),
}

type StoryProps = {
	controls: {
		Player: {
			Coins: () -> number,
			OwnedHeroes: () -> number,
			OwnsSkins: () -> boolean,
			LongNames: () -> boolean,
		},
		Friends: {
			Online: () -> number,
			IsLoading: () -> boolean,
		},
		State: {
			IsMatchOver: () -> boolean,
			ShowsNotice: () -> boolean,
		},
		Layout: {
			IsCompact: () -> boolean,
		},
	},
	target: Frame,
}

local function story(props: StoryProps)
	local controls = props.controls
	local primaryRole = source(nil :: string?)
	local secondaryRole = source(nil :: string?)
	-- Items bought in the story, on top of what the controls own.
	local bought = source({} :: { [string]: boolean? })

	local function buy(itemId: string)
		local nextBought = table.clone(bought())
		nextBought[itemId] = true
		bought(nextBought)
	end

	local function heroes(): { HeroView }
		local views = {}
		for index, heroId in HERO_IDS do
			local hero = HeroCatalog.Heroes[heroId]
			table.insert(views, {
				Id = heroId,
				Name = if controls.Player.LongNames() then LONG_NAME else hero.DisplayName,
				Title = hero.Title,
				Role = hero.Role :: string,
				Color = hero.Color,
				IsOwned = index <= controls.Player.OwnedHeroes() or bought()[heroId] == true,
				CoinPrice = StoreCatalog.HeroCoinPrice,
				RobuxPrice = StoreCatalog.HeroRobuxPrice,
			})
		end
		return views
	end

	local function skins(): { SkinView }
		local views = {}
		for _, skinId in SKIN_IDS do
			local skin = StoreCatalog.Skins[skinId]
			table.insert(views, {
				Id = skinId,
				Name = if controls.Player.LongNames() then `{LONG_NAME} {skin.Name}` else skin.Name,
				HeroName = HeroCatalog.Heroes[skin.HeroId].DisplayName,
				Colors = skin.Colors,
				RobuxPrice = skin.Robux,
				IsOwned = controls.Player.OwnsSkins() or bought()[skinId] == true,
			})
		end
		return views
	end

	local function friends(): { FriendView }?
		if controls.Friends.IsLoading() then
			return nil
		end
		local views: { FriendView } = {}
		for index = 1, controls.Friends.Online() do
			local name = FRIEND_NAMES[(index - 1) % #FRIEND_NAMES + 1]
			table.insert(views, {
				UserId = SAMPLE_USER_ID,
				Name = if controls.Player.LongNames() then `{LONG_NAME}{index}` else name,
				Status = if index % 3 == 0 then "InGame" else "Online",
			})
		end
		return views
	end

	return LobbyScreen({
		IsOpen = function()
			return true
		end,
		PlayerName = function()
			return if controls.Player.LongNames() then LONG_NAME else "Player1"
		end,
		PlayerUserId = SAMPLE_USER_ID,
		Coins = controls.Player.Coins,
		Roles = ROLES,
		PrimaryRole = primaryRole,
		SecondaryRole = secondaryRole,
		Friends = friends,
		Heroes = heroes,
		Skins = skins,
		FindMatchBlocked = function()
			return if controls.State.IsMatchOver()
				then "This match is over. Rejoin for the next one."
				else nil
		end,
		Notice = function()
			return if controls.State.ShowsNotice()
				then "Robux purchases open soon. Unlock heroes with coins for now."
				else nil
		end,
		IsCompact = controls.Layout.IsCompact,
		UiScale = function()
			return 1
		end,
		OnSetRole = function(slot: RoleSlot, role: string?)
			local this = if slot == "Primary" then primaryRole else secondaryRole
			local other = if slot == "Primary" then secondaryRole else primaryRole
			if role ~= nil and other() == role then
				other(this())
			end
			this(role)
		end,
		OnFindMatch = function()
			print("Find Match")
		end,
		OnInviteFriends = function()
			print("Invite friends")
		end,
		OnInvite = function(userId: number)
			print("Invite", userId)
		end,
		OnBuyWithCoins = buy,
		OnBuyWithRobux = buy,
	})
end

return {
	summary = "The lobby: party and positions, heroes, store, and friends.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
