--!strict

const GuiService = game:GetService("GuiService")
const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const mount = Vide.mount
const source = Vide.source

const AbilityCatalog = require("@game/ServerScriptService/Modules/Data/AbilityCatalog")
const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const MatchNetwork = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchNetwork"
)
const Screen = require("@game/ServerScriptService/Modules/Utilities/Screen")
const StoreClientService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/StoreSystem/SystemPackage/StoreClientService"
)

const HeroSelectScreen = require("../SystemPackage/HeroSelectScreen")

const ROLES = { "Top", "Jungle", "Mid", "Bot", "Support" }
const SLOTS = { "Q", "W", "E", "R" }
const TEAM_SIZE = 5
-- Above the match HUD, which the screen covers until the match starts.
const DISPLAY_ORDER = 10
-- Seconds a tapped hero shows as chosen before the server's answer, in case
-- the server refuses it without changing the picks.
const REQUEST_TIMEOUT = 1
-- Set on the local player by the client Start script once every system has
-- started.
const LOADED_ATTRIBUTE = "IsClientLoaded"
const WATCHED_ATTRIBUTES = { "Phase", "Picks", "HeroPool", "SelectEndTime" }

const MatchTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchTypes"
)

type HeroCardView = HeroSelectScreen.HeroCardView
type Pick = MatchTypes.Pick
type PoolHero = MatchTypes.PoolHero
type TeammateView = HeroSelectScreen.TeammateView

local Module = {}

local isOpen = source(false)
local heroes = source({} :: { HeroCardView })
local team = source("Blue")
local teammates = source({} :: { TeammateView })
local selectedHeroId = source(nil :: string?)
local isLockedIn = source(false)
local secondsLeft = source(nil :: number?)
local requestedHeroId: string? = nil
local screenGui: ScreenGui? = nil

local function decodeAttribute(name: string): any
	local encoded = MatchNetwork.MatchState:GetAttribute(name)
	if typeof(encoded) == "string" and encoded ~= "" then
		return HttpService:JSONDecode(encoded)
	end
	return {}
end

local function buildCard(
	poolHero: PoolHero,
	isRoleTaken: { [string]: boolean? },
	ownedItems: { [string]: boolean? }
): HeroCardView?
	local hero = HeroCatalog.Heroes[poolHero.HeroId]
	if not hero then
		return nil
	end
	local abilities = {}
	for _, slot in SLOTS do
		local ability = AbilityCatalog.Abilities[hero.Abilities[slot]]
		table.insert(abilities, `{slot} {if ability then ability.Name else "?"}`)
	end
	-- Cast because a table field keeps the literal union, which a string
	-- field won't accept.
	return {
		Id = poolHero.HeroId,
		Name = hero.DisplayName,
		Title = hero.Title,
		Role = poolHero.Role :: string,
		ResourceName = if hero.Resource == "None"
			then "Cooldowns only"
			else hero.Resource :: string,
		Abilities = abilities,
		Color = hero.Color,
		Blocked = if isRoleTaken[poolHero.Role]
			then "Taken"
			elseif not ownedItems[poolHero.HeroId] then "Locked"
			else nil,
	}
end

local function refresh()
	local picks: { Pick } = decodeAttribute("Picks")
	local pool: { PoolHero } = decodeAttribute("HeroPool")
	local userId = Players.LocalPlayer.UserId

	local localPick: Pick? = nil
	for _, pick in picks do
		if pick.UserId == userId then
			localPick = pick
		end
	end

	local isRoleTaken: { [string]: boolean? } = {}
	local rows: { TeammateView } = {}
	if localPick then
		for _, pick in picks do
			if pick.Team == localPick.Team then
				local hero = HeroCatalog.Heroes[pick.HeroId]
				if hero and pick.IsLockedIn and pick.UserId ~= userId then
					isRoleTaken[hero.Role] = true
				end
				table.insert(rows, {
					Name = pick.Name,
					HeroName = if hero then hero.DisplayName else "",
					IsLockedIn = pick.IsLockedIn,
					IsLocalPlayer = pick.UserId == userId,
				})
			end
		end
	end

	local ownedItems = StoreClientService:GetOwnedItems()
	local cards: { HeroCardView } = {}
	for _, poolHero in pool do
		local card = buildCard(poolHero, isRoleTaken, ownedItems)
		if card then
			table.insert(cards, card)
		end
	end

	local pickedHeroId = if localPick and localPick.HeroId ~= "" then localPick.HeroId else nil
	local wasOpen = isOpen()
	isOpen(MatchNetwork.MatchState:GetAttribute("Phase") == "Selecting" and localPick ~= nil)
	heroes(cards)
	team(if localPick then localPick.Team else "Blue")
	teammates(rows)
	selectedHeroId(requestedHeroId or pickedHeroId)
	isLockedIn(if localPick then localPick.IsLockedIn else false)

	local gui = screenGui
	if gui and isOpen() and not wasOpen and Screen.isGamepad() then
		-- Gamepad players start on the first hero instead of nothing.
		task.defer(GuiService.Select, GuiService, gui)
	end
end

local function onPicksChanged()
	-- The server has answered, whatever it decided.
	requestedHeroId = nil
	refresh()
end

local function onPick(heroId: string)
	requestedHeroId = heroId
	selectedHeroId(heroId)
	MatchNetwork.PickHero:FireServer(heroId)
	task.delay(REQUEST_TIMEOUT, function()
		if requestedHeroId == heroId then
			requestedHeroId = nil
			refresh()
		end
	end)
end

local function onLockIn()
	MatchNetwork.LockIn:FireServer()
end

local function onHeartbeat()
	if not isOpen() then
		return
	end
	local endTime = MatchNetwork.MatchState:GetAttribute("SelectEndTime")
	if typeof(endTime) == "number" and endTime > 0 then
		secondsLeft(math.max(0, math.ceil(endTime - workspace:GetServerTimeNow())))
	else
		secondsLeft(nil)
	end
end

local function reportLoadedIfReady()
	if Players.LocalPlayer:GetAttribute(LOADED_ATTRIBUTE) then
		MatchNetwork.Loaded:FireServer()
		return true
	end
	return false
end

local function app(): ScreenGui
	local gui = create("ScreenGui")({
		Name = "HeroSelect",
		DisplayOrder = DISPLAY_ORDER,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,

		HeroSelectScreen({
			IsOpen = isOpen,
			Roles = ROLES,
			Heroes = heroes,
			Team = team,
			Teammates = teammates,
			TeamSize = TEAM_SIZE,
			SelectedHeroId = selectedHeroId,
			IsLockedIn = isLockedIn,
			SecondsLeft = secondsLeft,
			IsCompact = Screen.isPhone,
			MaxSize = Screen.usableSize,
			UiScale = Screen.uiScale,
			OnPick = onPick,
			OnLockIn = onLockIn,
		}),
	})
	screenGui = gui
	return gui
end

function Module:Start()
	for _, name in WATCHED_ATTRIBUTES do
		local handler = if name == "Picks" then onPicksChanged else refresh
		MatchNetwork.MatchState:GetAttributeChangedSignal(name):Connect(handler)
	end
	RunService.Heartbeat:Connect(onHeartbeat)
	StoreClientService.WalletChanged:Connect(refresh)

	if not reportLoadedIfReady() then
		local connection: RBXScriptConnection
		connection = Players.LocalPlayer
			:GetAttributeChangedSignal(LOADED_ATTRIBUTE)
			:Connect(function()
				if reportLoadedIfReady() then
					connection:Disconnect()
				end
			end)
	end

	task.spawn(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		mount(app, playerGui)
		refresh()
	end)
end

return Module
