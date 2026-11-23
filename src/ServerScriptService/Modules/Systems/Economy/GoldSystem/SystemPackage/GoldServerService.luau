--!strict

const SimClock = require("@game/ServerScriptService/Modules/Utilities/SimClock")

const GoldNetwork = require("./GoldNetwork")

-- Seconds between passive income payments.
const PASSIVE_TICK = 1

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

local Module = {}

-- Gold belongs to a hero, so bots earn and spend it the same way players do.
local balances: { [Unit]: number? } = {}
local startingGold = 0
local passiveGoldPerSecond = 0
local passiveStartTime: number? = nil

local function setBalance(hero: Unit, amount: number)
	balances[hero] = amount
	local player = hero.OwnerPlayer
	if player then
		GoldNetwork.GoldChanged:FireClient(player, math.floor(amount))
	end
end

local function payPassiveIncome()
	local startTime = passiveStartTime
	if not startTime or SimClock.serverTime() < startTime then
		return
	end
	for hero in balances do
		Module:AddGold(hero, passiveGoldPerSecond * PASSIVE_TICK)
	end
end

function Module:SetStartingGold(amount: number)
	startingGold = amount
end

--[[
	Gives a hero its gold, starting at the starting amount. A hero without
	an account earns nothing and can't spend.
]]
function Module:OpenAccount(hero: Unit)
	if not balances[hero] then
		setBalance(hero, startingGold)
	end
end

function Module:CloseAccount(hero: Unit)
	balances[hero] = nil
end

--[[
	Pays every hero goldPerSecond from a server time (SimClock.serverTime())
	on.
]]
function Module:StartPassiveIncome(goldPerSecond: number, startTime: number)
	passiveGoldPerSecond = goldPerSecond
	passiveStartTime = startTime
end

function Module:StopPassiveIncome()
	passiveStartTime = nil
end

function Module:GetGold(hero: Unit): number
	return balances[hero] or 0
end

function Module:AddGold(hero: Unit, amount: number)
	local balance = balances[hero]
	if balance and amount > 0 then
		setBalance(hero, balance + amount)
	end
end

--[[
	Takes amount from the hero's gold and returns true, or returns false and
	takes nothing when it can't afford it.
]]
function Module:TrySpend(hero: Unit, amount: number): boolean
	local balance = balances[hero]
	if not balance or balance < amount then
		return false
	end
	setBalance(hero, balance - amount)
	return true
end

function Module:Start()
	task.spawn(function()
		while true do
			SimClock.wait(PASSIVE_TICK)
			payPassiveIncome()
		end
	end)
end

return Module
