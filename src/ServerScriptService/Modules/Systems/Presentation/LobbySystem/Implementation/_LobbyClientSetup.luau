--!strict

const GuiService = game:GetService("GuiService")
const HttpService = game:GetService("HttpService")
const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")
const SocialService = game:GetService("SocialService")

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const mount = Vide.mount
const source = Vide.source

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const MatchNetwork = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchNetwork"
)
const Screen = require("@game/ServerScriptService/Modules/Utilities/Screen")
const StoreCatalog = require("@game/ServerScriptService/Modules/Data/StoreCatalog")
const StoreClientService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/StoreSystem/SystemPackage/StoreClientService"
)

const LobbyScreen = require("../SystemPackage/LobbyScreen")

const ROLES = { "Top", "Jungle", "Mid", "Bot", "Support" }
-- Above the hero select and match HUD, which wait behind the lobby.
const DISPLAY_ORDER = 20
-- Set on the local player by the client Start script once every system has
-- started.
const LOADED_ATTRIBUTE = "IsClientLoaded"
const FRIENDS_REFRESH_SECONDS = 30
-- The top of the lobby's own gradient.
const BACKDROP_COLOR = Color3.fromRGB(6, 14, 16)
const MAX_FRIENDS = 50
const NOTICE_SECONDS = 6
const JOIN_TIMEOUT_SECONDS = 5
-- Roblox's LocationType values for a friend playing an experience.
const IN_GAME_LOCATIONS = { 1, 4 }

const LobbyTypes = require("../SystemPackage/LobbyTypes")

type FriendView = LobbyTypes.FriendView
type HeroView = LobbyTypes.HeroView
type RoleSlot = LobbyTypes.RoleSlot
type SkinView = LobbyTypes.SkinView

local Module = {}

const localPlayer = Players.LocalPlayer

local isOpen = source(false)
local hasJoined = source(false)
local isJoining = false
local coins = source(0)
local heroes = source({} :: { HeroView })
local skins = source({} :: { SkinView })
local friends = source(nil :: { FriendView }?)
local primaryRole = source(nil :: string?)
local secondaryRole = source(nil :: string?)
local findMatchBlocked = source(nil :: string?)
local notice = source(nil :: string?)
local noticeThread: thread? = nil
local screenGui: ScreenGui? = nil

local function showNotice(text: string)
	notice(text)
	if noticeThread then
		task.cancel(noticeThread)
	end
	noticeThread = task.delay(NOTICE_SECONDS, function()
		notice(nil)
	end)
end

local function sortedHeroIds(): { string }
	local heroIds = {}
	for heroId in HeroCatalog.Heroes do
		table.insert(heroIds, heroId)
	end
	table.sort(heroIds, function(a, b)
		local roleA = table.find(ROLES, HeroCatalog.Heroes[a].Role) or 0
		local roleB = table.find(ROLES, HeroCatalog.Heroes[b].Role) or 0
		if roleA ~= roleB then
			return roleA < roleB
		end
		return a < b
	end)
	return heroIds
end

const HERO_IDS = sortedHeroIds()

local function refreshWallet()
	local owned = StoreClientService:GetOwnedItems()
	coins(StoreClientService:GetCoins())

	local heroViews = {}
	for _, heroId in HERO_IDS do
		local hero = HeroCatalog.Heroes[heroId]
		table.insert(heroViews, {
			Id = heroId,
			Name = hero.DisplayName,
			Title = hero.Title,
			Role = hero.Role :: string,
			Color = hero.Color,
			IsOwned = owned[heroId] == true,
			CoinPrice = StoreCatalog.HeroCoinPrice,
			RobuxPrice = StoreCatalog.HeroRobuxPrice,
		})
	end
	heroes(heroViews)

	local skinIds = {}
	for skinId in StoreCatalog.Skins do
		table.insert(skinIds, skinId)
	end
	table.sort(skinIds)
	local skinViews = {}
	for _, skinId in skinIds do
		local skin = StoreCatalog.Skins[skinId]
		local hero = HeroCatalog.Heroes[skin.HeroId]
		table.insert(skinViews, {
			Id = skinId,
			Name = skin.Name,
			HeroName = if hero then hero.DisplayName else skin.HeroId,
			Colors = skin.Colors,
			RobuxPrice = skin.Robux,
			IsOwned = owned[skinId] == true,
		})
	end
	skins(skinViews)
end

local function isInMatch(): boolean
	local userId = localPlayer.UserId
	for _, name in { "Picks", "Scoreboard" } do
		local encoded = MatchNetwork.MatchState:GetAttribute(name)
		if typeof(encoded) == "string" and encoded ~= "" then
			for _, entry in HttpService:JSONDecode(encoded) do
				if entry.UserId == userId then
					return true
				end
			end
		end
	end
	return false
end

local function refreshMatch()
	local isPlaying = isInMatch()
	if isPlaying then
		hasJoined(true)
	end
	local phase = MatchNetwork.MatchState:GetAttribute("Phase")
	if phase == "Ended" then
		findMatchBlocked("This match is over. Rejoin for the next one.")
	elseif isJoining then
		findMatchBlocked("Finding a match...")
	else
		findMatchBlocked(nil)
	end

	local wasOpen = isOpen()
	local isSpectating = MatchNetwork.MatchState:GetAttribute("PlayersSpectate") == true
	isOpen(
		localPlayer:GetAttribute(LOADED_ATTRIBUTE) == true and not hasJoined() and not isSpectating
	)
	local gui = screenGui
	if gui and isOpen() and not wasOpen and Screen.isGamepad() then
		task.defer(GuiService.Select, GuiService, gui)
	end
end

local function refreshFriendsAsync()
	-- GetFriendsOnline fails in Studio tests and when Roblox's friend service
	-- is down; the list then keeps its last value.
	local success, result = pcall(function()
		return localPlayer:GetFriendsOnline(MAX_FRIENDS)
	end)
	if not success then
		if friends() == nil then
			friends({})
		end
		return
	end
	local views: { FriendView } = {}
	for _, friend in result do
		table.insert(views, {
			UserId = friend.VisitorId,
			Name = friend.DisplayName or friend.UserName,
			Status = if table.find(IN_GAME_LOCATIONS, friend.LocationType)
				then "InGame"
				else "Online",
		})
	end
	friends(views)
end

local function promptInvite(userId: number?)
	task.spawn(function()
		local canInvite, result = pcall(function()
			return SocialService:CanSendGameInviteAsync(localPlayer, userId)
		end)
		if not canInvite or not result then
			showNotice("Invites can't be sent from here right now.")
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		if userId then
			options.InviteUser = userId
		end
		local success = pcall(function()
			SocialService:PromptGameInvite(localPlayer, options)
		end)
		if not success then
			showNotice("Invites can't be sent from here right now.")
		end
	end)
end

local function onSetRole(slot: RoleSlot, role: string?)
	local other = if slot == "Primary" then secondaryRole else primaryRole
	local this = if slot == "Primary" then primaryRole else secondaryRole
	-- Choosing the other slot's role swaps the two.
	if role ~= nil and other() == role then
		other(this())
	end
	this(role)
end

local function onFindMatch()
	local roles = {}
	for _, role in { primaryRole() or "", secondaryRole() or "" } do
		if role ~= "" then
			table.insert(roles, role)
		end
	end
	MatchNetwork.JoinMatch:FireServer(roles)
	-- The lobby closes once the server lists the player in the match. If it
	-- never does, Find Match comes back.
	isJoining = true
	refreshMatch()
	task.delay(JOIN_TIMEOUT_SECONDS, function()
		isJoining = false
		refreshMatch()
	end)
end

local function onBuyWithRobux(itemId: string)
	local skin = StoreCatalog.Skins[itemId]
	local productId = if skin then skin.ProductId else StoreCatalog.HeroProductIds[itemId]
	if not productId then
		showNotice("Robux purchases open soon. Unlock heroes with coins for now.")
		return
	end
	MarketplaceService:PromptProductPurchase(localPlayer, productId)
end

local function backdrop(): ScreenGui
	-- Fills the strip under Roblox's top bar too, which the lobby's own
	-- safe-area ScreenGui leaves open.
	return create("ScreenGui")({
		Name = "LobbyBackdrop",
		DisplayOrder = DISPLAY_ORDER - 1,
		ScreenInsets = Enum.ScreenInsets.None,

		create("Frame")({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = BACKDROP_COLOR,
			Visible = isOpen,
		}),
	})
end

local function app(): ScreenGui
	local gui = create("ScreenGui")({
		Name = "Lobby",
		DisplayOrder = DISPLAY_ORDER,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,

		LobbyScreen({
			IsOpen = isOpen,
			PlayerName = localPlayer.DisplayName,
			PlayerUserId = localPlayer.UserId,
			Coins = coins,
			Roles = ROLES,
			PrimaryRole = primaryRole,
			SecondaryRole = secondaryRole,
			Friends = friends,
			Heroes = heroes,
			Skins = skins,
			FindMatchBlocked = findMatchBlocked,
			Notice = notice,
			IsCompact = Screen.isPhone,
			UiScale = Screen.uiScale,
			OnSetRole = onSetRole,
			OnFindMatch = onFindMatch,
			OnInviteFriends = function()
				promptInvite(nil)
			end,
			OnInvite = promptInvite,
			OnBuyWithCoins = function(itemId: string)
				StoreClientService:BuyWithCoins(itemId)
			end,
			OnBuyWithRobux = onBuyWithRobux,
		}),
	})
	screenGui = gui
	return gui
end

function Module:Start()
	StoreClientService.WalletChanged:Connect(refreshWallet)
	for _, name in { "Phase", "Picks", "Scoreboard", "PlayersSpectate" } do
		MatchNetwork.MatchState:GetAttributeChangedSignal(name):Connect(refreshMatch)
	end
	localPlayer:GetAttributeChangedSignal(LOADED_ATTRIBUTE):Connect(refreshMatch)

	task.spawn(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui")
		mount(backdrop, playerGui)
		mount(app, playerGui)
		refreshWallet()
		refreshMatch()
		while true do
			refreshFriendsAsync()
			task.wait(FRIENDS_REFRESH_SECONDS)
		end
	end)
end

return Module
