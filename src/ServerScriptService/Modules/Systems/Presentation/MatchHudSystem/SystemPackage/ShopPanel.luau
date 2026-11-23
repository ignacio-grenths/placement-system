--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const indexes = Vide.indexes
const read = Vide.read
const show = Vide.show

const HudTheme = require("./HudTheme")

const WIDTH = 560
const PADDING = 16
const GAP = 8
const ROW_HEIGHT = 64
const BUY_BUTTON_SIZE = Vector2.new(120, 48)
const HEADER_HEIGHT = 48
const SCROLL_BAR_THICKNESS = 6
const GOLD_COLOR = Color3.fromRGB(255, 205, 80)
const PAIR_COLOR = Color3.fromRGB(110, 200, 255)
const BUY_COLOR = Color3.fromRGB(60, 140, 90)
const DISABLED_COLOR = Color3.fromRGB(48, 50, 60)
const TAG_WIDTH = 190
const PAIR_LINE_HEIGHT = 40

export type ShopItemView = {
	Id: string,
	Name: string,
	Description: string,
	Cost: number,
	-- Why the item can't be bought whatever the gold, such as "Owned" or
	-- "Needs Boots". Nil when nothing stands in the way.
	Blocked: string?,
	-- True for an upgrade, which replaces its base item instead of taking a
	-- free slot.
	IsUpgrade: boolean,
	-- The name of the pair the item belongs to, if any.
	PairName: string?,
	-- True when the item is in the local hero's suggested build.
	IsSuggested: boolean,
}

export type ActivePairView = {
	Name: string,
	Description: string,
}

export type ShopPanelProps = {
	Items: () -> { ShopItemView },
	-- The pair bonus the hero has earned, or nil.
	ActivePair: () -> ActivePairView?,
	Gold: () -> number,
	-- Whether the hero stands where buying works (its fountain, or dead).
	CanBuyHere: () -> boolean,
	IsInventoryFull: () -> boolean,
	IsOpen: () -> boolean,
	-- Height in UI units the item list may take before it scrolls.
	MaxListHeight: number | () -> number,
	OnBuy: (itemId: string) -> (),
	OnClose: () -> (),
}

--[[
	Returns the text on an item's Buy button: its price when it can be bought,
	otherwise the reason it can't, so a disabled button always says why.
]]
local function getBuyLabel(item: ShopItemView, props: ShopPanelProps): (string, boolean)
	local blocked = item.Blocked
	if blocked then
		return blocked, false
	elseif not props.CanBuyHere() then
		return "At base", false
	elseif props.IsInventoryFull() and not item.IsUpgrade then
		return "Bag full", false
	elseif props.Gold() < item.Cost then
		return `Need {item.Cost - math.floor(props.Gold())}`, false
	end
	return `{item.Cost}`, true
end

local function itemRow(item: () -> ShopItemView, layoutOrder: number, props: ShopPanelProps): Frame
	return create("Frame")({
		Name = "ItemRow",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, -SCROLL_BAR_THICKNESS - GAP, 0, ROW_HEIGHT),
		BackgroundColor3 = HudTheme.BarBackground,
		BackgroundTransparency = 0.3,

		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		create("UIPadding")({
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 8),
		}),
		create("TextLabel")({
			Name = "ItemName",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, -BUY_BUTTON_SIZE.X - TAG_WIDTH - GAP * 2, 0, 22),
			Font = HudTheme.Font,
			Text = function()
				return item().Name
			end,
			TextSize = HudTheme.BodyTextSize,
			TextColor3 = HudTheme.TextColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		create("TextLabel")({
			Name = "Tags",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -BUY_BUTTON_SIZE.X - GAP, 0, 8),
			Size = UDim2.fromOffset(TAG_WIDTH, 22),
			Font = HudTheme.Font,
			RichText = true,
			Text = function()
				local view = item()
				local tags = {}
				if view.IsSuggested then
					table.insert(tags, `<font color="#{GOLD_COLOR:ToHex()}">Suggested</font>`)
				end
				local pairName = view.PairName
				if pairName then
					table.insert(tags, `<font color="#{PAIR_COLOR:ToHex()}">{pairName}</font>`)
				end
				return table.concat(tags, "  ")
			end,
			TextSize = HudTheme.SmallTextSize,
			TextColor3 = HudTheme.MutedTextColor,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		create("TextLabel")({
			Name = "Description",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, -BUY_BUTTON_SIZE.X - GAP, 0, 22),
			Font = HudTheme.BodyFont,
			Text = function()
				return item().Description
			end,
			TextSize = HudTheme.SmallTextSize,
			TextColor3 = HudTheme.MutedTextColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		create("TextButton")({
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(BUY_BUTTON_SIZE.X, BUY_BUTTON_SIZE.Y),
			BackgroundColor3 = function()
				local _, canBuy = getBuyLabel(item(), props)
				return if canBuy then BUY_COLOR else DISABLED_COLOR
			end,
			Font = HudTheme.Font,
			Text = function()
				local label = getBuyLabel(item(), props)
				return label
			end,
			TextSize = HudTheme.SmallTextSize,
			TextColor3 = function()
				local _, canBuy = getBuyLabel(item(), props)
				return if canBuy then GOLD_COLOR else HudTheme.MutedTextColor
			end,
			Activated = function()
				local _, canBuy = getBuyLabel(item(), props)
				if canBuy then
					props.OnBuy(item().Id)
				end
			end,

			create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		}),
	})
end

--[[
	Every item for sale with its price. It opens anywhere so players can plan,
	but Buy only works at the hero's fountain, and each button that can't buy
	says why.
]]
local function shopPanel(props: ShopPanelProps)
	return show(props.IsOpen, function()
		return create("Frame")({
			Name = "ShopPanel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(WIDTH, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = HudTheme.PanelColor,
			BackgroundTransparency = HudTheme.PanelTransparency,
			ZIndex = 6,

			create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
			create("UIPadding")({
				PaddingTop = UDim.new(0, PADDING),
				PaddingBottom = UDim.new(0, PADDING),
				PaddingLeft = UDim.new(0, PADDING),
				PaddingRight = UDim.new(0, PADDING),
			}),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, GAP),
			}),

			create("Frame")({
				Name = "Header",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),

				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(0.3, 1),
					Font = HudTheme.Font,
					Text = "Shop",
					TextSize = HudTheme.TitleTextSize,
					TextColor3 = HudTheme.TextColor,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				create("TextLabel")({
					Name = "Gold",
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.3, 0),
					Size = UDim2.fromScale(0.4, 1),
					Font = HudTheme.Font,
					Text = function()
						return `{math.floor(props.Gold())} gold`
					end,
					TextSize = HudTheme.BodyTextSize,
					TextColor3 = GOLD_COLOR,
				}),
				create("TextButton")({
					Name = "Close",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(96, HEADER_HEIGHT),
					BackgroundColor3 = HudTheme.BarBackground,
					Font = HudTheme.Font,
					Text = "Close",
					TextSize = HudTheme.SmallTextSize,
					TextColor3 = HudTheme.TextColor,
					Activated = props.OnClose,

					create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
				}),
			}),

			create("TextLabel")({
				Name = "Where",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 22),
				Font = HudTheme.BodyFont,
				Text = function()
					return if props.CanBuyHere()
						then "You can buy here."
						else "Return to your fountain to buy."
				end,
				TextSize = HudTheme.SmallTextSize,
				TextColor3 = HudTheme.MutedTextColor,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			-- The pair bonus line keeps its place either way, so players learn
			-- that pairs exist before they earn one.
			create("TextLabel")({
				Name = "PairBonus",
				LayoutOrder = 3,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, PAIR_LINE_HEIGHT),
				Font = HudTheme.BodyFont,
				Text = function()
					local active = props.ActivePair()
					return if active
						then `Pair bonus: {active.Name}. {active.Description}`
						else "Pair bonus: hold both items of a pair to earn its bonus."
				end,
				TextSize = HudTheme.SmallTextSize,
				TextColor3 = function()
					return if props.ActivePair() then PAIR_COLOR else HudTheme.MutedTextColor
				end,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),

			create("ScrollingFrame")({
				Name = "Items",
				LayoutOrder = 4,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = function()
					local listHeight = #props.Items() * (ROW_HEIGHT + GAP)
					return UDim2.new(1, 0, 0, math.min(listHeight, read(props.MaxListHeight)))
				end,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = SCROLL_BAR_THICKNESS,
				ScrollingDirection = Enum.ScrollingDirection.Y,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, GAP),
				}),
				indexes(props.Items, function(item, index)
					return itemRow(item, index, props)
				end),
			}),
		})
	end)
end

return shopPanel
