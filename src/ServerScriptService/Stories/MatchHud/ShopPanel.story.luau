--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const HeroCatalog = require("@game/ServerScriptService/Modules/Data/HeroCatalog")
const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")
const ShopPanel = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/ShopPanel"
)

const NO_PAIR = "None"

local function getHeroIds(): { string }
	local heroIds = {}
	for heroId in HeroCatalog.Heroes do
		table.insert(heroIds, heroId)
	end
	table.sort(heroIds)
	return heroIds
end

local function getPairChoices(): { string }
	local pairIds = { NO_PAIR }
	for pairId in ItemCatalog.PairBonuses do
		table.insert(pairIds, pairId)
	end
	table.sort(pairIds)
	return pairIds
end

const CONTROLS = {
	Player = UILabs.Ordered(
		UILabs.ControlGroup({
			Gold = UILabs.Ordered(UILabs.Slider(1000, 0, 5000, 50), 1),
			-- Off shows every Buy button saying to return to base.
			IsAtBase = UILabs.Ordered(true, 2),
			OwnsBoots = UILabs.Ordered(false, 3),
			IsInventoryFull = UILabs.Ordered(false, 4),
		}),
		1
	),
	Build = UILabs.Ordered(
		UILabs.ControlGroup({
			-- Whose suggested items are tagged.
			Hero = UILabs.Ordered(UILabs.Choose(getHeroIds()), 1),
			-- The pair bonus shown as earned.
			ActivePair = UILabs.Ordered(UILabs.Choose(getPairChoices()), 2),
		}),
		2
	),
	Layout = UILabs.Ordered(
		UILabs.ControlGroup({
			-- UI units the list may take before it scrolls; a phone has ~200.
			MaxListHeight = UILabs.Ordered(UILabs.Slider(560, 120, 800, 20), 1),
		}),
		3
	),
}

type StoryProps = {
	controls: {
		Player: {
			Gold: () -> number,
			IsAtBase: () -> boolean,
			OwnsBoots: () -> boolean,
			IsInventoryFull: () -> boolean,
		},
		Build: {
			Hero: () -> string,
			ActivePair: () -> string,
		},
		Layout: {
			MaxListHeight: () -> number,
		},
	},
	target: Frame,
}

local function story(props: StoryProps)
	local controls = props.controls

	local function items(): { ShopPanel.ShopItemView }
		local hero = HeroCatalog.Heroes[controls.Build.Hero()]
		local suggested: { string } = if hero then hero.SuggestedBuild else {}
		local ownsBoots = controls.Player.OwnsBoots()
		local list = {}
		for itemId, entry in ItemCatalog.Items do
			local pairId = entry.Pair
			local pair = if pairId then ItemCatalog.PairBonuses[pairId] else nil
			local blocked: string? = nil
			if entry.UpgradeOf and not ownsBoots then
				blocked = "Needs Boots"
			elseif not entry.UpgradeOf and entry.Kind == "Boots" and ownsBoots then
				blocked = "Owned"
			end
			table.insert(list, {
				Id = itemId,
				Name = entry.Name,
				Description = entry.Description,
				Cost = entry.Cost,
				Blocked = blocked,
				IsUpgrade = entry.UpgradeOf ~= nil,
				PairName = if pair then pair.Name else nil,
				IsSuggested = table.find(suggested, itemId) ~= nil,
			})
		end
		table.sort(list, function(first, second)
			return ItemCatalog.Items[first.Id].Order < ItemCatalog.Items[second.Id].Order
		end)
		return list
	end

	return ShopPanel({
		Items = items,
		ActivePair = function()
			local pair = ItemCatalog.PairBonuses[controls.Build.ActivePair()]
			return if pair then { Name = pair.Name, Description = pair.Description } else nil
		end,
		Gold = controls.Player.Gold,
		CanBuyHere = controls.Player.IsAtBase,
		IsInventoryFull = controls.Player.IsInventoryFull,
		IsOpen = function()
			return true
		end,
		MaxListHeight = controls.Layout.MaxListHeight,
		OnBuy = function(itemId: string)
			print(`Buy {itemId}`)
		end,
		OnClose = function()
			print("Close pressed")
		end,
	})
end

return {
	summary = "Every item for sale with its pair and suggested tags, and the earned pair bonus.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
