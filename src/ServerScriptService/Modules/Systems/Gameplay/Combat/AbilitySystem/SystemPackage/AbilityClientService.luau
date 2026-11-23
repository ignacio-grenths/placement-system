--!strict

const UserInputService = game:GetService("UserInputService")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const AbilityNetwork = require("./AbilityNetwork")

const AbilityTypes = require("./AbilityTypes")

type AbilityInfo = AbilityTypes.AbilityInfo
type Aim = AbilityTypes.Aim
type Slot = AbilityTypes.Slot

-- How a cast wants to be aimed. Cursor aims at the mouse. Auto picks the
-- nearest fitting target, for gamepads and taps. Toward aims along a
-- direction for Reach (0 to 1) of the ability's range, for a dragged button.
export type AimRequest =
	{ Kind: "Cursor" }
	| { Kind: "Auto" }
	| {
		Kind: "Toward",
		Direction: Vector3,
		Reach: number,
	}

export type Cooldown = {
	-- Seconds.
	Duration: number,
	-- Server time.
	EndsAt: number,
}

export type Channel = {
	Name: string,
	Duration: number,
	-- Server time.
	EndsAt: number,
}

const KEYBOARD_SLOTS: { [Enum.KeyCode]: Slot } = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.D] = "D",
	[Enum.KeyCode.F] = "F",
	[Enum.KeyCode.B] = "B",
}

const GAMEPAD_SLOTS: { [Enum.KeyCode]: Slot } = {
	[Enum.KeyCode.ButtonL1] = "Q",
	[Enum.KeyCode.ButtonR1] = "W",
	[Enum.KeyCode.ButtonL2] = "E",
	[Enum.KeyCode.ButtonR2] = "R",
	[Enum.KeyCode.DPadLeft] = "D",
	[Enum.KeyCode.DPadRight] = "F",
	[Enum.KeyCode.DPadDown] = "B",
}

local Module = {}

Module.LoadoutChanged = Signal.new() :: Signal.Signal<>
Module.CooldownStarted = Signal.new() :: Signal.Signal<Slot>
Module.ChannelChanged = Signal.new() :: Signal.Signal<>

local loadout: { [Slot]: AbilityInfo? } = {}
local cooldowns: { [Slot]: Cooldown? } = {}
local channel: Channel? = nil
local aimResolver: ((AbilityInfo, AimRequest) -> Aim?)? = nil

local function onLoadoutChanged(infos: { [Slot]: AbilityInfo? })
	loadout = infos
	table.clear(cooldowns)
	Module.LoadoutChanged:Fire()
end

local function onCooldownStarted(slot: Slot, duration: number, endsAt: number)
	cooldowns[slot] = {
		Duration = duration,
		EndsAt = endsAt,
	}
	Module.CooldownStarted:Fire(slot)
end

local function onChannelChanged(name: string, endsAt: number)
	if name == "" then
		channel = nil
	else
		channel = {
			Name = name,
			Duration = math.max(endsAt - workspace:GetServerTimeNow(), 0),
			EndsAt = endsAt,
		}
	end
	Module.ChannelChanged:Fire()
end

local function onInputBegan(input: InputObject, isProcessed: boolean)
	if isProcessed then
		return
	end

	-- Annotated because luau-lsp widens string literals read from a table.
	local keyboardSlot: Slot? = KEYBOARD_SLOTS[input.KeyCode]
	if keyboardSlot and input.UserInputType == Enum.UserInputType.Keyboard then
		Module:RequestCast(keyboardSlot, { Kind = "Cursor" })
		return
	end
	local gamepadSlot: Slot? = GAMEPAD_SLOTS[input.KeyCode]
	if gamepadSlot then
		Module:RequestCast(gamepadSlot, { Kind = "Auto" })
	end
end

--[[
	Sets how a cast is aimed: the resolver turns an ability and a request
	into an aim point (and a target for Unit abilities), or nil to drop the
	cast when nothing fits.
]]
function Module:SetAimResolver(resolver: (AbilityInfo, AimRequest) -> Aim?)
	aimResolver = resolver
end

function Module:GetLoadout(): { [Slot]: AbilityInfo? }
	return loadout
end

function Module:GetCooldown(slot: Slot): Cooldown?
	return cooldowns[slot]
end

function Module:GetChannel(): Channel?
	return channel
end

--[[
	Asks the server to cast the ability in a slot. The server checks the
	cast again and is the only one that can refuse it.
]]
function Module:RequestCast(slot: Slot, request: AimRequest)
	local info = loadout[slot]
	if not info then
		return
	end
	-- The server would refuse it, so a held key doesn't send a stream of them.
	local cooldown = cooldowns[slot]
	if cooldown and workspace:GetServerTimeNow() < cooldown.EndsAt then
		return
	end

	local aim = if aimResolver then aimResolver(info, request) else nil
	if aim then
		AbilityNetwork.CastRequest:FireServer(slot, aim.Point.X, aim.Point.Z, aim.TargetId)
	end
end

function Module:Init()
	AbilityNetwork.LoadoutChanged.OnClientEvent:Connect(onLoadoutChanged)
	AbilityNetwork.CooldownStarted.OnClientEvent:Connect(onCooldownStarted)
	AbilityNetwork.ChannelChanged.OnClientEvent:Connect(onChannelChanged)
end

function Module:Start()
	UserInputService.InputBegan:Connect(onInputBegan)
end

return Module
