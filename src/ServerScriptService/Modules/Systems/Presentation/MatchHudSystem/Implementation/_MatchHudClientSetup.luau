--!strict

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const mount = Vide.mount
const source = Vide.source

const AbilityClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityClientService"
)
const GoldClientService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/GoldSystem/SystemPackage/GoldClientService"
)
const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const HeroLevelClientService = require(
	"@game/ServerScriptService/Modules/Systems/Progression/HeroLevelSystem/SystemPackage/HeroLevelClientService"
)
const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")
const ItemShopClientService = require(
	"@game/ServerScriptService/Modules/Systems/Economy/ItemShopSystem/SystemPackage/ItemShopClientService"
)
const JungleCatalog = require("@game/ServerScriptService/Modules/Data/JungleCatalog")
const JungleClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/JungleSystem/SystemPackage/JungleClientService"
)
const MapLayout = require("@game/ServerScriptService/Modules/Data/MapLayout")
const MatchNetwork = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchNetwork"
)
const ProgressionCatalog = require("@game/ServerScriptService/Modules/Data/ProgressionCatalog")
const Screen = require("@game/ServerScriptService/Modules/Utilities/Screen")
const UnitCatalog = require("@game/ServerScriptService/Modules/Data/UnitCatalog")
const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)

const AbilityBar = require("../SystemPackage/AbilityBar")
const Announcement = require("../SystemPackage/Announcement")
const BuffBar = require("../SystemPackage/BuffBar")
const EndScreen = require("../SystemPackage/EndScreen")
const HeroStatus = require("../SystemPackage/HeroStatus")
const HudTheme = require("../SystemPackage/HudTheme")
const ItemBar = require("../SystemPackage/ItemBar")
const Minimap = require("../SystemPackage/Minimap")
const Scoreboard = require("../SystemPackage/Scoreboard")
const ScoreStrip = require("../SystemPackage/ScoreStrip")
const ShopPanel = require("../SystemPackage/ShopPanel")

-- Seconds between refreshes. Cooldowns only show tenths below one second.
const REFRESH_INTERVAL = 0.1
const SLOT_ORDER = { "Q", "W", "E", "R", "D", "F", "B" }
const MAIN_SLOTS = { Q = true, W = true, E = true, R = true }
const KEYBOARD_LABELS = { Q = "Q", W = "W", E = "E", R = "R", D = "D", F = "F", B = "B" }
const GAMEPAD_LABELS = { Q = "LB", W = "RB", E = "LT", R = "RT", D = "DL", F = "DR", B = "DD" }
const EDGE_MARGIN = 20
const TOUCH_EDGE_MARGIN = 12
const DESKTOP_MINIMAP_SIZE = 220
const TOUCH_MINIMAP_SIZE = 150
-- Minimap dot diameters in UI units, by unit kind.
const DOT_SIZES = {
	Hero = 10,
	Structure = 8,
	Minion = 4,
	Monster = 6,
}
const LOCAL_HERO_DOT_SIZE = 13
const LOCAL_HERO_DOT_COLOR = Color3.fromRGB(120, 255, 150)
const NEUTRAL_DOT_COLOR = Color3.fromRGB(230, 190, 80)
const STATUS_GAP = 8
-- UI units the shop's header and padding take, so its list scrolls instead
-- of running off a short screen.
const SHOP_CHROME_HEIGHT = 200
-- Seconds an announcement stays up: long enough to read mid-fight. While
-- others wait their turn, each gets only the shorter time.
const ANNOUNCEMENT_SECONDS = 6
const QUEUED_ANNOUNCEMENT_SECONDS = 2.5
const TOP_GAP = 8
-- Buffs whose own camp a hero takes, announced to that hero alone. Boss
-- buffs come with the boss's own announcement.
const PERSONAL_BUFFS = { Focus = true, Burn = true }

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)
const MatchTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/MatchSystem/SystemPackage/MatchTypes"
)

type AbilityView = AbilityBar.AbilityView
type AnnouncementView = Announcement.AnnouncementView
type BuffView = BuffBar.BuffView
type ChannelView = AbilityBar.ChannelView
type MinimapDot = Minimap.MinimapDot
type ScoreEntry = MatchTypes.ScoreEntry
type ScoreRow = Scoreboard.ScoreRow
type Slot = AbilityTypes.Slot

type HeroState = {
	Name: string,
	Health: number,
	MaxHealth: number,
	Shield: number,
	Resource: number,
	MaxResource: number,
	ResourceKind: string,
	IsDead: boolean,
	Level: number,
	XpShare: number,
}

type ItemSlotView = ItemBar.ItemSlotView
type ShopItemView = ShopPanel.ShopItemView
type ActivePairView = ShopPanel.ActivePairView

-- Vide checks for impure effects and yields in Studio, at a small cost.
Vide.strict = RunService:IsStudio()

local Module = {}

local abilities = source({} :: { AbilityView })
local channel = source(nil :: ChannelView?)
local heroState = source({
	Name = "",
	Health = 0,
	MaxHealth = 1,
	Shield = 0,
	Resource = 0,
	MaxResource = 0,
	ResourceKind = "None",
	IsDead = false,
	Level = 1,
	XpShare = 0,
} :: HeroState)
local gold = source(0)
local itemSlots = source({} :: { ItemSlotView })
local shopItems = source({} :: { ShopItemView })
local activePair = source(nil :: ActivePairView?)
local isInventoryFull = source(false)
local canBuyHere = source(false)
local isAutoRanking = source(false)
local isShopOpen = source(false)
local elapsed = source(0)
local blueKills = source(0)
local redKills = source(0)
local scoreRows = source({} :: { ScoreRow })
local isScoreboardHeld = source(false)
local isScoreboardToggled = source(false)
local result = source(nil :: string?)
local resultDetail = source("")
local isEndScreenDismissed = source(false)
local minimapDots = source({} :: { MinimapDot })
local buffViews = source({} :: { BuffView })
local announcement = source(nil :: AnnouncementView?)
local announcementShownAt = 0
local announcementEndsAt = 0
local queuedAnnouncements: { AnnouncementView } = {}
local heldBuffIds: { [string]: boolean } = {}
local refreshTimer = 0

local function toMapPoint(position: Vector3): Vector2
	local size = MapLayout.HalfSize * 2
	return Vector2.new(
		(position.X + MapLayout.HalfSize) / size,
		(position.Z + MapLayout.HalfSize) / size
	)
end

local function toMapPath(points: { Vector3 }): { Vector2 }
	local mapped = {}
	for _, point in points do
		table.insert(mapped, toMapPoint(point))
	end
	return mapped
end

local function getMinimapLanes(): { { Vector2 } }
	local lanes = {}
	-- Red's routes are Blue's run backward, so Blue's cover every lane.
	local drawnTeam: MapLayout.MapTeam = "Blue"
	for _, route in MapLayout.Routes[drawnTeam] do
		table.insert(lanes, toMapPath(route))
	end
	return lanes
end

local function getMinimapWalls(): { { Vector2 } }
	local walls = {}
	for _, wall in MapLayout.Walls do
		table.insert(walls, { toMapPoint(wall.From), toMapPoint(wall.To) })
	end
	return walls
end

local function buildAbilityViews(): { AbilityView }
	local loadout = AbilityClientService:GetLoadout()
	local levelState = HeroLevelClientService:GetState()
	local hero = UnitClientService:GetLocalHero()
	local labels = if Screen.isGamepad() then GAMEPAD_LABELS else KEYBOARD_LABELS
	local now = workspace:GetServerTimeNow()

	local views = {}
	for _, slot in SLOT_ORDER do
		local info = loadout[slot :: Slot]
		local cooldown = AbilityClientService:GetCooldown(slot :: Slot)
		local cost = if info then info.Cost else 0
		-- A hero on cooldowns only has no resource, and pays nothing.
		local canAfford = not hero or hero.MaxResource == 0 or hero.Resource >= cost
		table.insert(views, {
			Slot = slot,
			KeyLabel = labels[slot],
			Name = if info then info.Name else "",
			IsMain = MAIN_SLOTS[slot] == true,
			Cost = if hero and hero.MaxResource > 0 then cost else 0,
			CanAfford = canAfford,
			CooldownRemaining = if cooldown then math.max(cooldown.EndsAt - now, 0) else 0,
			CooldownDuration = if cooldown then cooldown.Duration else 0,
			IsEmpty = info == nil,
			Rank = if levelState then levelState.Ranks[slot] or 0 else 0,
			MaxRank = if not MAIN_SLOTS[slot]
				then 0
				elseif slot == "R" then ProgressionCatalog.MaxUltimateRank
				else ProgressionCatalog.MaxBasicRank,
			CanRankUp = if levelState then levelState.CanRankUp[slot] == true else false,
		})
	end
	return views
end

local function buildChannelView(): ChannelView?
	local current = AbilityClientService:GetChannel()
	if not current then
		return nil
	end
	local remaining = math.max(current.EndsAt - workspace:GetServerTimeNow(), 0)
	local progress = if current.Duration > 0 then 1 - remaining / current.Duration else 1
	return {
		Name = current.Name,
		Progress = progress,
	}
end

local function buildHeroState(): HeroState
	local hero = UnitClientService:GetLocalHero()
	if not hero then
		return heroState()
	end
	local entry = HeroCatalog.Heroes[hero.TypeId]
	local levelState = HeroLevelClientService:GetState()
	return {
		Name = if entry then entry.DisplayName else hero.TypeId,
		Health = hero.Health,
		MaxHealth = hero.MaxHealth,
		Shield = hero.Shield,
		Resource = hero.Resource,
		MaxResource = hero.MaxResource,
		ResourceKind = if entry then entry.Resource else "None",
		IsDead = hero.IsDead,
		Level = if levelState then levelState.Level else 1,
		XpShare = if levelState and levelState.XpForNext > 0
			then levelState.XpIntoLevel / levelState.XpForNext
			else 1,
	}
end

local function buildMinimapDots(): { MinimapDot }
	local localHero = UnitClientService:GetLocalHero()
	local renderTime = UnitClientService:GetRenderTime()
	local dots = {}
	for _, unit in UnitClientService:GetUnits() do
		if not unit or unit.IsDead or unit.IsHidden or unit.Kind == "Summon" then
			continue
		end
		local isLocalHero = localHero ~= nil and unit.Id == localHero.Id
		local position = UnitClientService:GetRenderPose(unit, renderTime)
		local teamColor = HudTheme.TeamColors[unit.Team] or NEUTRAL_DOT_COLOR
		table.insert(dots, {
			Position = toMapPoint(position),
			Color = if isLocalHero then LOCAL_HERO_DOT_COLOR else teamColor,
			Size = if isLocalHero
				then LOCAL_HERO_DOT_SIZE
				else DOT_SIZES[unit.Kind] or DOT_SIZES.Minion,
		})
	end
	return dots
end

local function refreshMatchState()
	local state = MatchNetwork.MatchState
	local startTime = state:GetAttribute("StartTime")
	elapsed(
		if typeof(startTime) == "number" and startTime > 0
			then workspace:GetServerTimeNow() - startTime
			else 0
	)

	local entries: { ScoreEntry } = {}
	local encoded = state:GetAttribute("Scoreboard")
	if typeof(encoded) == "string" and encoded ~= "" then
		entries = HttpService:JSONDecode(encoded)
	end
	local userId = Players.LocalPlayer.UserId
	local rows: { ScoreRow } = {}
	local kills: { [string]: number } = { Blue = 0, Red = 0 }
	local localTeam: string? = nil
	for _, entry in entries do
		local hero = HeroCatalog.Heroes[entry.HeroId]
		kills[entry.Team] = (kills[entry.Team] or 0) + entry.Kills
		if entry.UserId == userId then
			localTeam = entry.Team
		end
		table.insert(rows, {
			Team = entry.Team :: string,
			PlayerName = entry.Name,
			HeroName = if hero then hero.DisplayName else entry.HeroId,
			Kills = entry.Kills,
			Deaths = entry.Deaths,
			IsLocalPlayer = entry.UserId == userId,
		})
	end
	scoreRows(rows)
	blueKills(kills.Blue)
	redKills(kills.Red)

	local winner = state:GetAttribute("Winner")
	if state:GetAttribute("Phase") == "Ended" and typeof(winner) == "string" and winner ~= "" then
		local loser = if winner == "Blue" then "Red" else "Blue"
		result(if winner == localTeam then "Victory" else "Defeat")
		resultDetail(`The {loser} core has fallen`)
	else
		result(nil)
	end
end

local function isLocalHeroAtFountain(): boolean
	local hero = UnitClientService:GetLocalHero()
	if not hero then
		return false
	end
	-- A dead hero can shop from anywhere, as the server allows.
	if hero.IsDead then
		return true
	end
	local base = MapLayout.Bases[hero.Team :: MapLayout.MapTeam]
	local position = UnitClientService:GetRenderPose(hero, UnitClientService:GetRenderTime())
	return base ~= nil and (position - base.Fountain).Magnitude <= base.FountainRadius
end

local function refreshItems()
	local inventory = ItemShopClientService:GetInventory()
	local slots: { ItemSlotView } = {}
	local ownsBoots = false
	for slot = 1, ItemCatalog.InventorySize do
		local entry = ItemCatalog.Items[inventory[slot] or ""]
		if entry and entry.Kind == "Boots" then
			ownsBoots = true
		end
		table.insert(slots, {
			Name = if entry then entry.Name else "",
			IsEmpty = entry == nil,
			IsConsumable = entry ~= nil and entry.Kind == "Consumable",
			KeyLabel = tostring(slot),
		})
	end
	itemSlots(slots)
	isInventoryFull(table.find(inventory, "") == nil and #inventory >= ItemCatalog.InventorySize)

	local hero = UnitClientService:GetLocalHero()
	local heroEntry = if hero then HeroCatalog.Heroes[hero.TypeId] else nil
	local suggested: { string } = if heroEntry then heroEntry.SuggestedBuild else {}
	local shop: { ShopItemView } = {}
	for itemId, entry in ItemCatalog.Items do
		local upgradeOf = entry.UpgradeOf
		local holdsThis = table.find(inventory, itemId) ~= nil
		-- A hero holds one pair of boots: plain boots are owned once any are
		-- held, and an upgrade is owned once it is held.
		local isOwnedBoots = entry.Kind == "Boots" and (holdsThis or (not upgradeOf and ownsBoots))
		local blocked: string? = nil
		if isOwnedBoots then
			blocked = "Owned"
		elseif upgradeOf and not table.find(inventory, upgradeOf) then
			local base = ItemCatalog.Items[upgradeOf]
			blocked = `Needs {if base then base.Name else upgradeOf}`
		end
		local pairId = entry.Pair
		local pair = if pairId then ItemCatalog.PairBonuses[pairId] else nil
		table.insert(shop, {
			Id = itemId,
			Name = entry.Name,
			Description = entry.Description,
			Cost = entry.Cost,
			Blocked = blocked,
			IsUpgrade = upgradeOf ~= nil,
			PairName = if pair then pair.Name else nil,
			IsSuggested = table.find(suggested, itemId) ~= nil,
		})
	end
	table.sort(shop, function(first, second)
		return ItemCatalog.Items[first.Id].Order < ItemCatalog.Items[second.Id].Order
	end)
	shopItems(shop)

	local activePairId = ItemShopClientService:GetActivePair()
	local activeEntry = if activePairId then ItemCatalog.PairBonuses[activePairId] else nil
	activePair(
		if activeEntry
			then { Name = activeEntry.Name, Description = activeEntry.Description }
			else nil
	)

	gold(GoldClientService:GetGold())
	canBuyHere(isLocalHeroAtFountain())
	local levelState = HeroLevelClientService:GetState()
	isAutoRanking(levelState ~= nil and levelState.IsAutoRanking)
end

local function buildBuffViews(): { BuffView }
	local now = workspace:GetServerTimeNow()
	local views: { BuffView } = {}
	for _, buff in JungleClientService:GetBuffs() do
		local info = JungleCatalog.BuffInfo[buff.Id]
		local isLasting = buff.ExpiresAt == 0
		if not info or (not isLasting and buff.ExpiresAt <= now) then
			continue
		end
		table.insert(views, {
			Name = info.Name,
			Color = info.Color,
			SecondsLeft = if isLasting then nil else math.ceil(buff.ExpiresAt - now),
			Stacks = buff.Stacks,
		})
	end
	return views
end

local function showAnnouncement(view: AnnouncementView)
	local now = os.clock()
	announcement(view)
	announcementShownAt = now
	local seconds = if #queuedAnnouncements > 0
		then QUEUED_ANNOUNCEMENT_SECONDS
		else ANNOUNCEMENT_SECONDS
	announcementEndsAt = now + seconds
end

local function announce(text: string, color: Color3)
	local view = {
		Text = text,
		Color = color,
	}
	if not announcement() then
		showAnnouncement(view)
		return
	end
	table.insert(queuedAnnouncements, view)
	announcementEndsAt =
		math.min(announcementEndsAt, announcementShownAt + QUEUED_ANNOUNCEMENT_SECONDS)
end

local function stepAnnouncements()
	if not announcement() or os.clock() < announcementEndsAt then
		return
	end
	local nextView = table.remove(queuedAnnouncements, 1)
	if nextView then
		showAnnouncement(nextView)
	else
		announcement(nil)
	end
end

local function onBossSlain(kind: string, team: string)
	local hero = UnitClientService:GetLocalHero()
	local entry = UnitCatalog.Units[kind]
	local bossName = if entry then entry.DisplayName else kind
	local taker = if hero and hero.Team == team then "Your team" else "The enemy team"
	announce(`{taker} took the {bossName}!`, HudTheme.TeamColors[team] or HudTheme.StrokeColor)
end

local function onBuffsChanged(buffs: { JungleClientService.BuffState })
	local held = {}
	for _, buff in buffs do
		held[buff.Id] = true
		local info = JungleCatalog.BuffInfo[buff.Id]
		if info and PERSONAL_BUFFS[buff.Id] and not heldBuffIds[buff.Id] then
			announce(`You got {info.Name}: {string.lower(info.Description)}`, info.Color)
		end
	end
	heldBuffIds = held
	buffViews(buildBuffViews())
end

local function refresh()
	abilities(buildAbilityViews())
	channel(buildChannelView())
	heroState(buildHeroState())
	minimapDots(buildMinimapDots())
	buffViews(buildBuffViews())
	stepAnnouncements()
	refreshItems()
	refreshMatchState()
end

local function onCast(slot: string, aim: Vector2?)
	if aim then
		-- The screen's up is the world's -Z, since the camera looks that way.
		AbilityClientService:RequestCast(slot :: Slot, {
			Kind = "Toward",
			Direction = Vector3.new(aim.X, 0, aim.Y).Unit,
			Reach = aim.Magnitude,
		})
	else
		AbilityClientService:RequestCast(slot :: Slot, { Kind = "Auto" })
	end
end

local function onInputBegan(input: InputObject, isProcessed: boolean)
	if isProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Tab then
		isScoreboardHeld(true)
	elseif input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.ButtonY then
		isShopOpen(not isShopOpen())
	elseif input.KeyCode == Enum.KeyCode.ButtonSelect then
		isScoreboardToggled(not isScoreboardToggled())
	end
end

local function onInputEnded(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Tab then
		isScoreboardHeld(false)
	end
end

local function hud(): ScreenGui
	local function isTouch(): boolean
		return Screen.isTouchLayout()
	end

	return create("ScreenGui")({
		Name = "MatchHud",
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,

		create("UIScale")({ Scale = Screen.uiScale }),

		create("Frame")({
			Name = "TopDock",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, TOUCH_EDGE_MARGIN),

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, TOP_GAP),
			}),
			ScoreStrip({
				Elapsed = elapsed,
				BlueKills = blueKills,
				RedKills = redKills,
				OnScoresPressed = function()
					isScoreboardToggled(not isScoreboardToggled())
				end,
			}),
			Announcement({
				Message = announcement,
			}),
		}),

		-- Bottom left on a desktop; top left on touch, where the thumbs are not.
		create("Frame")({
			Name = "StatusDock",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			AnchorPoint = function()
				return if isTouch() then Vector2.zero else Vector2.new(0, 1)
			end,
			Position = function()
				return if isTouch()
					then UDim2.fromOffset(TOUCH_EDGE_MARGIN, TOUCH_EDGE_MARGIN)
					else UDim2.new(0, EDGE_MARGIN, 1, -EDGE_MARGIN)
			end,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, STATUS_GAP),
			}),
			BuffBar({
				Buffs = buffViews,
			}),
			ItemBar({
				Items = itemSlots,
				Gold = gold,
				IsAutoRanking = isAutoRanking,
				OnUse = function(slot: number)
					ItemShopClientService:RequestUse(slot)
				end,
				OnShopPressed = function()
					isShopOpen(not isShopOpen())
				end,
				OnAutoRankPressed = function()
					HeroLevelClientService:SetAutoRanking(not isAutoRanking())
				end,
			}),
			HeroStatus({
				HeroName = function()
					return heroState().Name
				end,
				Health = function()
					return heroState().Health
				end,
				MaxHealth = function()
					return heroState().MaxHealth
				end,
				Shield = function()
					return heroState().Shield
				end,
				Resource = function()
					return heroState().Resource
				end,
				MaxResource = function()
					return heroState().MaxResource
				end,
				ResourceKind = function()
					return heroState().ResourceKind
				end,
				IsDead = function()
					return heroState().IsDead
				end,
				Level = function()
					return heroState().Level
				end,
				XpShare = function()
					return heroState().XpShare
				end,
			}),
		}),

		AbilityBar({
			Abilities = abilities,
			Channel = channel,
			IsTouch = isTouch,
			OnCast = onCast,
			OnRankUp = function(slot: string)
				HeroLevelClientService:RequestRankUp(slot)
			end,
		}),

		ShopPanel({
			Items = shopItems,
			ActivePair = activePair,
			Gold = gold,
			CanBuyHere = canBuyHere,
			IsInventoryFull = isInventoryFull,
			IsOpen = isShopOpen,
			MaxListHeight = function()
				return math.max(Screen.usableSize().Y - SHOP_CHROME_HEIGHT, 120)
			end,
			OnBuy = function(itemId: string)
				ItemShopClientService:RequestBuy(itemId)
			end,
			OnClose = function()
				isShopOpen(false)
			end,
		}),

		Scoreboard({
			Rows = scoreRows,
			IsOpen = function()
				return isScoreboardHeld() or isScoreboardToggled()
			end,
		}),

		EndScreen({
			Result = function()
				return if isEndScreenDismissed() then nil else result()
			end,
			Detail = resultDetail,
			OnContinue = function()
				isEndScreenDismissed(true)
			end,
		}),
	})
end

-- The minimap redraws ten times a second, so it gets its own ScreenGui and
-- its changes never make the rest of the HUD redraw.
local function minimapGui(): ScreenGui
	local function isTouch(): boolean
		return Screen.isTouchLayout()
	end
	local lanes = getMinimapLanes()
	local river = toMapPath(MapLayout.River)
	local walls = getMinimapWalls()

	return create("ScreenGui")({
		Name = "MatchMinimap",
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,

		create("UIScale")({ Scale = Screen.uiScale }),
		create("Frame")({
			Name = "MinimapDock",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			AnchorPoint = function()
				return if isTouch() then Vector2.new(1, 0) else Vector2.new(1, 1)
			end,
			Position = function()
				return if isTouch()
					then UDim2.new(1, -TOUCH_EDGE_MARGIN, 0, TOUCH_EDGE_MARGIN)
					else UDim2.new(1, -EDGE_MARGIN, 1, -EDGE_MARGIN)
			end,

			Minimap({
				Lanes = lanes,
				River = river,
				Walls = walls,
				Dots = minimapDots,
				Size = function()
					return if isTouch() then TOUCH_MINIMAP_SIZE else DESKTOP_MINIMAP_SIZE
				end,
			}),
		}),
	})
end

function Module:Start()
	JungleClientService.BuffsChanged:Connect(onBuffsChanged)
	JungleClientService.BossSlain:Connect(onBossSlain)
	AbilityClientService.LoadoutChanged:Connect(refresh)
	AbilityClientService.CooldownStarted:Connect(refresh)
	AbilityClientService.ChannelChanged:Connect(refresh)
	HeroLevelClientService.StateChanged:Connect(refresh)
	ItemShopClientService.InventoryChanged:Connect(refresh)
	GoldClientService.GoldChanged:Connect(refresh)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	RunService.Heartbeat:Connect(function(deltaTime)
		refreshTimer += deltaTime
		if refreshTimer >= REFRESH_INTERVAL then
			refreshTimer = 0
			refresh()
		end
	end)

	task.spawn(function()
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		refresh()
		mount(hud, playerGui)
		mount(minimapGui, playerGui)
	end)
end

return Module
