--!strict

const Players = game:GetService("Players")
const RunService = game:GetService("RunService")

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const mount = Vide.mount
const source = Vide.source

const AbilityClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityClientService"
)
const Screen = require("@game/ServerScriptService/Modules/Utilities/Screen")
const UnitClientService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitClientService"
)

const AbilityBar = require("../SystemPackage/AbilityBar")

-- Seconds between refreshes. Cooldowns only show tenths below one second.
const REFRESH_INTERVAL = 0.1
const SLOT_ORDER = { "Q", "W", "E", "R", "D", "F", "B" }
const MAIN_SLOTS = { Q = true, W = true, E = true, R = true }
const KEYBOARD_LABELS = { Q = "Q", W = "W", E = "E", R = "R", D = "D", F = "F", B = "B" }
const GAMEPAD_LABELS = { Q = "LB", W = "RB", E = "LT", R = "RT", D = "DL", F = "DR", B = "DD" }

const AbilityTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/AbilitySystem/SystemPackage/AbilityTypes"
)

type AbilityView = AbilityBar.AbilityView
type ChannelView = AbilityBar.ChannelView
type Slot = AbilityTypes.Slot

-- Vide checks for impure effects and yields in Studio, at a small cost.
Vide.strict = RunService:IsStudio()

local Module = {}

local abilities = source({} :: { AbilityView })
local channel = source(nil :: ChannelView?)
local refreshTimer = 0

local function buildAbilityViews(): { AbilityView }
	local loadout = AbilityClientService:GetLoadout()
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

local function refresh()
	abilities(buildAbilityViews())
	channel(buildChannelView())
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

local function hud(): ScreenGui
	return create("ScreenGui")({
		Name = "MatchHud",
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,

		create("UIScale")({ Scale = Screen.uiScale }),
		AbilityBar({
			Abilities = abilities,
			Channel = channel,
			IsTouch = Screen.isTouchLayout,
			OnCast = onCast,
		}),
	})
end

function Module:Start()
	AbilityClientService.LoadoutChanged:Connect(refresh)
	AbilityClientService.CooldownStarted:Connect(refresh)
	AbilityClientService.ChannelChanged:Connect(refresh)
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
	end)
end

return Module
