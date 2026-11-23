--!strict

const UILabs = require("@game/ServerScriptService/Tests/Packages/UILabs")
const Vide = require("@game/ReplicatedStorage/Packages/vide")

const ItemCatalog = require("@game/ServerScriptService/Modules/Data/ItemCatalog")
const ShopPanel = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/ShopPanel"
)

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
	Layout = UILabs.Ordered(
		UILabs.ControlGroup({
			-- UI units the list may take before it scrolls; a phone has ~200.
			MaxListHeight = UILabs.Ordered(UILabs.Slider(560, 120, 800, 20), 1),
		}),
		2
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
		Layout: {
			MaxListHeight: () -> number,
		},
	},
	target: Frame,
}

local function story(props: StoryProps)
	local controls = props.controls

	local function items(): { ShopPanel.ShopItemView }
		local list = {}
		for itemId, entry in ItemCatalog.Items do
			table.insert(list, {
				Id = itemId,
				Name = entry.Name,
				Description = entry.Description,
				Cost = entry.Cost,
				IsOwned = entry.Kind == "Boots" and controls.Player.OwnsBoots(),
			})
		end
		table.sort(list, function(first, second)
			return ItemCatalog.Items[first.Id].Order < ItemCatalog.Items[second.Id].Order
		end)
		return list
	end

	return ShopPanel({
		Items = items,
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
	summary = "Every item for sale, with each Buy button showing the price or the reason it can't buy.",
	vide = Vide,
	controls = CONTROLS,
	story = story,
}
