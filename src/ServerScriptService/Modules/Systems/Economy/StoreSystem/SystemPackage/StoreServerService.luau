--!strict

const HttpService = game:GetService("HttpService")
const Players = game:GetService("Players")

const StoreNetwork = require("./StoreNetwork")

const REQUESTS_PER_SECOND = 4

type Wallet = {
	Coins: number,
	Owned: { [string]: boolean? },
}

local Module = {}

local starterCoins = 0
local freeItems: { string } = {}
local coinPrices: { [string]: number? } = {}
-- Kept for the session only: saved player data doesn't exist yet.
local wallets: { [Player]: Wallet } = {}
local lastRequestTimes: { [Player]: number } = {}

local function publish(player: Player, wallet: Wallet)
	local owned = {}
	for itemId in wallet.Owned do
		table.insert(owned, itemId)
	end
	table.sort(owned)
	player:SetAttribute(StoreNetwork.CoinsAttribute, wallet.Coins)
	player:SetAttribute(StoreNetwork.OwnedItemsAttribute, HttpService:JSONEncode(owned))
end

local function onPlayerAdded(player: Player)
	if wallets[player] then
		return
	end
	local wallet: Wallet = { Coins = starterCoins, Owned = {} }
	for _, itemId in freeItems do
		wallet.Owned[itemId] = true
	end
	wallets[player] = wallet
	publish(player, wallet)
end

local function onPlayerRemoving(player: Player)
	wallets[player] = nil
	lastRequestTimes[player] = nil
end

local function onBuyWithCoins(player: Player, itemId: unknown)
	local now = os.clock()
	local last = lastRequestTimes[player]
	if last and now - last < 1 / REQUESTS_PER_SECOND then
		return
	end
	lastRequestTimes[player] = now

	if typeof(itemId) ~= "string" then
		return
	end
	local wallet = wallets[player]
	local price = coinPrices[itemId]
	if not wallet or not price or wallet.Owned[itemId] or wallet.Coins < price then
		return
	end
	wallet.Coins -= price
	wallet.Owned[itemId] = true
	publish(player, wallet)
end

--[[
	Sets what every new wallet starts with and what coins can buy. Wallets
	already open get the free items too.
]]
function Module:Configure(config: {
	StarterCoins: number,
	FreeItems: { string },
	CoinPrices: { [string]: number },
})
	starterCoins = config.StarterCoins
	freeItems = table.clone(config.FreeItems)
	coinPrices = table.clone(config.CoinPrices)
	for player, wallet in wallets do
		for _, itemId in freeItems do
			wallet.Owned[itemId] = true
		end
		publish(player, wallet)
	end
end

function Module:Owns(player: Player, itemId: string): boolean
	local wallet = wallets[player]
	return wallet ~= nil and wallet.Owned[itemId] == true
end

function Module:Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	StoreNetwork.BuyWithCoins.OnServerEvent:Connect(onBuyWithCoins)
end

function Module:Start()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Module
