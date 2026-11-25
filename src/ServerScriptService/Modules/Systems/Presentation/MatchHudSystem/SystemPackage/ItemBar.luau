--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const indexes = Vide.indexes

const HudTheme = require("./HudTheme")

const SLOT_SIZE = 46
const GAP = 6
const BUTTON_HEIGHT = 46
const GOLD_COLOR = HudTheme.GoldColor
const EMPTY_SLOT_COLOR = Color3.fromRGB(8, 14, 16)
const FILLED_SLOT_COLOR = Color3.fromRGB(30, 46, 50)
const CONSUMABLE_STROKE_COLOR = Color3.fromRGB(120, 220, 150)

export type ItemSlotView = {
	-- Short enough to fit a slot, such as "Boots".
	Name: string,
	IsEmpty: boolean,
	-- Consumables are pressed to use; other items only show what is held.
	IsConsumable: boolean,
	-- The key that uses it, such as "1".
	KeyLabel: string,
}

export type ItemBarProps = {
	Items: () -> { ItemSlotView },
	Gold: () -> number,
	IsAutoRanking: () -> boolean,
	OnUse: (slot: number) -> (),
	OnShopPressed: () -> (),
	OnAutoRankPressed: () -> (),
}

local function textButton(
	name: string,
	text: () -> string,
	layoutOrder: number,
	onActivated: () -> ()
): TextButton
	return create("TextButton")({
		Name = name,
		LayoutOrder = layoutOrder,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, BUTTON_HEIGHT),
		BackgroundColor3 = HudTheme.PanelColor,
		BackgroundTransparency = HudTheme.PanelTransparency,
		Font = HudTheme.Font,
		Text = text,
		TextSize = HudTheme.SmallTextSize,
		TextColor3 = HudTheme.TextColor,
		Activated = onActivated,

		create("UIStroke")({
			Color = HudTheme.StrokeColor,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
		create("UIPadding")({
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})
end

local function itemSlot(
	item: () -> ItemSlotView,
	slot: number,
	onUse: (slot: number) -> ()
): TextButton
	return create("TextButton")({
		Name = `Slot{slot}`,
		LayoutOrder = slot,
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = function()
			return if item().IsEmpty then EMPTY_SLOT_COLOR else FILLED_SLOT_COLOR
		end,
		Text = "",
		Activated = function()
			onUse(slot)
		end,

		create("UICorner")({ CornerRadius = UDim.new(0, 8) }),
		create("UIStroke")({
			Color = function()
				return if item().IsConsumable then CONSUMABLE_STROKE_COLOR else HudTheme.StrokeColor
			end,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("TextLabel")({
			Name = "ItemName",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -6, 1, -6),
			Position = UDim2.fromOffset(3, 3),
			Font = HudTheme.Font,
			Text = function()
				return item().Name
			end,
			TextScaled = true,
			TextWrapped = true,
			TextColor3 = HudTheme.TextColor,

			create("UITextSizeConstraint")({ MaxTextSize = 12 }),
		}),
		create("TextLabel")({
			Name = "KeyLabel",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -1),
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = HudTheme.Font,
			Text = function()
				return item().KeyLabel
			end,
			TextSize = 11,
			TextColor3 = HudTheme.MutedTextColor,
		}),
	})
end

--[[
	The hero's gold, six item slots (consumables are pressed to use), the
	button that opens the shop, and the switch for automatic ability ranks.
]]
local function itemBar(props: ItemBarProps): Frame
	return create("Frame")({
		Name = "ItemBar",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, GAP),
		}),

		create("Frame")({
			Name = "Slots",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, GAP),
			}),
			indexes(props.Items, function(item, slot)
				return itemSlot(item, slot, props.OnUse)
			end),
		}),

		create("Frame")({
			Name = "Actions",
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, GAP),
			}),
			create("TextLabel")({
				Name = "Gold",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, BUTTON_HEIGHT),
				Font = HudTheme.Font,
				Text = function()
					return `{math.floor(props.Gold())} gold`
				end,
				TextSize = HudTheme.BodyTextSize,
				TextColor3 = GOLD_COLOR,
			}),
			textButton("Shop", function()
				return "Shop"
			end, 2, props.OnShopPressed),
			textButton("AutoRank", function()
				return if props.IsAutoRanking() then "Auto ranks: on" else "Auto ranks: off"
			end, 3, props.OnAutoRankPressed),
		}),
	})
end

return itemBar
