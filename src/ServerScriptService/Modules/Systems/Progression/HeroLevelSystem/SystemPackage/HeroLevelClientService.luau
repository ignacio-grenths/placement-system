--!strict

const UserInputService = game:GetService("UserInputService")

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const HeroLevelNetwork = require("./HeroLevelNetwork")

-- Ctrl plus an ability key spends a point on it, as in League.
const RANK_KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.W] = "W",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
}

const HeroLevelTypes = require("./HeroLevelTypes")

type LevelState = HeroLevelTypes.LevelState

local Module = {}

Module.StateChanged = Signal.new() :: Signal.Signal<>

local state: LevelState? = nil

local function onLevelStateChanged(newState: LevelState)
	state = newState
	Module.StateChanged:Fire()
end

local function onInputBegan(input: InputObject, isProcessed: boolean)
	if isProcessed then
		return
	end
	local slot = RANK_KEYS[input.KeyCode]
	local isControlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if slot and isControlHeld then
		Module:RequestRankUp(slot)
	end
end

--[[
	Returns the local hero's level, experience, and ranks, or nil before the
	server has sent them.
]]
function Module:GetState(): LevelState?
	return state
end

function Module:RequestRankUp(slot: string)
	HeroLevelNetwork.RankUpRequest:FireServer(slot)
end

function Module:SetAutoRanking(isOn: boolean)
	HeroLevelNetwork.AutoRankRequest:FireServer(isOn)
end

function Module:Init()
	HeroLevelNetwork.LevelStateChanged.OnClientEvent:Connect(onLevelStateChanged)
end

function Module:Start()
	UserInputService.InputBegan:Connect(onInputBegan)
end

return Module
