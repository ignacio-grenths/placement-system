--!strict

const Signal = require("@game/ServerScriptService/Modules/Utilities/Signal")

const GoldNetwork = require("./GoldNetwork")

local Module = {}

Module.GoldChanged = Signal.new() :: Signal.Signal<number>

local gold = 0

local function onGoldChanged(amount: number)
	gold = amount
	Module.GoldChanged:Fire(amount)
end

function Module:GetGold(): number
	return gold
end

function Module:Init()
	GoldNetwork.GoldChanged.OnClientEvent:Connect(onGoldChanged)
end

return Module
