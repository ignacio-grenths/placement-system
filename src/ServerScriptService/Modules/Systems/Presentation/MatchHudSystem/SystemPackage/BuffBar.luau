--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const indexes = Vide.indexes

const HudTheme = require("./HudTheme")

const TILE_WIDTH = 96
const TILE_HEIGHT = 46
const TILE_PADDING = 4
const STROKE_THICKNESS = 2
const DETAIL_TEXT_SIZE = 14
const GAP = 6

export type BuffView = {
	Name: string,
	Color: Color3,
	-- Whole seconds left, or nil for a buff that lasts the match.
	SecondsLeft: number?,
	Stacks: number,
}

export type BuffBarProps = {
	Buffs: () -> { BuffView },
}

local function getDetail(buff: BuffView): string
	local secondsLeft = buff.SecondsLeft
	if secondsLeft then
		return `{secondsLeft}s left`
	end
	return if buff.Stacks > 1 then `x{buff.Stacks}` else "All match"
end

--[[
	The local hero's jungle buffs: a tile for each, edged in its color, with
	its name and how long it has left.
]]
local function buffBar(props: BuffBarProps): Frame
	return create("Frame")({
		Name = "BuffBar",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		-- Holding no buffs is the usual case, and the row takes no room then.
		Visible = function()
			return #props.Buffs() > 0
		end,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, GAP),
		}),
		indexes(props.Buffs, function(buff, index)
			return create("Frame")({
				Name = "Buff",
				LayoutOrder = index,
				Size = UDim2.fromOffset(TILE_WIDTH, TILE_HEIGHT),
				BackgroundColor3 = HudTheme.PanelColor,
				BackgroundTransparency = HudTheme.PanelTransparency,

				create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
				create("UIStroke")({
					Color = function()
						return buff().Color
					end,
					Thickness = STROKE_THICKNESS,
				}),
				create("UIPadding")({
					PaddingTop = UDim.new(0, TILE_PADDING),
					PaddingBottom = UDim.new(0, TILE_PADDING),
				}),
				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				create("TextLabel")({
					Name = "BuffName",
					LayoutOrder = 1,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, HudTheme.SmallTextSize + 2),
					Font = HudTheme.Font,
					Text = function()
						return buff().Name
					end,
					TextSize = HudTheme.SmallTextSize,
					TextColor3 = function()
						return buff().Color
					end,
				}),
				create("TextLabel")({
					Name = "Detail",
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, DETAIL_TEXT_SIZE + 2),
					Font = HudTheme.BodyFont,
					Text = function()
						return getDetail(buff())
					end,
					TextSize = DETAIL_TEXT_SIZE,
					TextColor3 = HudTheme.TextColor,
				}),
			})
		end),
	})
end

return buffBar
