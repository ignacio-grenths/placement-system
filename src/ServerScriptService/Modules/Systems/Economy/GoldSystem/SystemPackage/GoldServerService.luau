--!strict

const Players = game:GetService("Players")

const GoldNetwork = require("./GoldNetwork")

-- Seconds between passive income payments.
const PASSIVE_TICK = 1

local Module = {}

local balances: { [Player]: number? } = {}
local startingGold = 0
local passiveGoldPerSecond = 0
local passiveStartTime: number? = nil

local function setBalance(player: Player, amount: number)
	balances[player] = amount
	GoldNetwork.GoldChanged:FireClient(player, math.floor(amount))
end

local function payPassiveIncome()
	local startTime = passiveStartTime
	if not startTime or workspace:GetServerTimeNow() < startTime then
		return
	end
	for player in balances do
		Module:AddGold(player, passiveGoldPerSecond * PASSIVE_TICK)
	end
end

local function onPlayerAdded(player: Player)
	setBalance(player, startingGold)
end

local function onPlayerRemoving(player: Player)
	balances[player] = nil
end

function Module:SetStartingGold(amount: number)
	startingGold = amount
end

--[[
	Pays every player goldPerSecond from a server time (workspace
	:GetServerTimeNow()) on.
]]
function Module:StartPassiveIncome(goldPerSecond: number, startTime: number)
	passiveGoldPerSecond = goldPerSecond
	passiveStartTime = startTime
end

function Module:StopPassiveIncome()
	passiveStartTime = nil
end

function Module:GetGold(player: Player): number
	return balances[player] or 0
end

function Module:AddGold(player: Player, amount: number)
	local balance = balances[player]
	if balance and amount > 0 then
		setBalance(player, balance + amount)
	end
end

--[[
	Takes amount from the player's gold and returns true, or returns false
	and takes nothing when they can't afford it.
]]
function Module:TrySpend(player: Player, amount: number): boolean
	local balance = balances[player]
	if not balance or balance < amount then
		return false
	end
	setBalance(player, balance - amount)
	return true
end

function Module:Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function Module:Start()
	for _, player in Players:GetPlayers() do
		if not balances[player] then
			onPlayerAdded(player)
		end
	end
	task.spawn(function()
		while true do
			task.wait(PASSIVE_TICK)
			payPassiveIncome()
		end
	end)
end

return Module
