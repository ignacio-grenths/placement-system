--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create

const HudTheme = require("./HudTheme")

const WIDTH = 300
const HEALTH_BAR_HEIGHT = 24
const RESOURCE_BAR_HEIGHT = 16
const XP_BAR_HEIGHT = 6
const XP_COLOR = Color3.fromRGB(180, 120, 255)
const GAP = 6

export type HeroStatusProps = {
	HeroName: () -> string,
	Health: () -> number,
	MaxHealth: () -> number,
	Shield: () -> number,
	Resource: () -> number,
	MaxResource: () -> number,
	-- "Mana", "Energy", "Stamina", or "None" for heroes on cooldowns only.
	ResourceKind: () -> string,
	IsDead: () -> boolean,
	Level: () -> number,
	-- Share of the way to the next level, 0 to 1. 1 at the top level.
	XpShare: () -> number,
}

local function barText(text: () -> string, textSize: number): TextLabel
	return create("TextLabel")({
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = HudTheme.Font,
		Text = text,
		TextSize = textSize,
		TextColor3 = HudTheme.TextColor,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
	})
end

--[[
	The local hero's name, health with any shield, and resource, so the
	player can tell at a glance whether to fight or back off.
]]
local function heroStatus(props: HeroStatusProps): Frame
	-- A shield extends the bar past full health, so the whole bar is health
	-- plus shield whenever that is more than max health.
	local function getBarTotal(): number
		return math.max(props.MaxHealth(), props.Health() + props.Shield(), 1)
	end

	return create("Frame")({
		Name = "HeroStatus",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = HudTheme.PanelColor,
		BackgroundTransparency = HudTheme.PanelTransparency,

		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
		create("UIStroke")({
			Color = HudTheme.StrokeColor,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		create("UIPadding")({
			PaddingTop = UDim.new(0, HudTheme.PanelPadding),
			PaddingBottom = UDim.new(0, HudTheme.PanelPadding),
			PaddingLeft = UDim.new(0, HudTheme.PanelPadding),
			PaddingRight = UDim.new(0, HudTheme.PanelPadding),
		}),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, GAP),
		}),

		create("TextLabel")({
			Name = "HeroName",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, HudTheme.BodyTextSize + 4),
			Font = HudTheme.Font,
			Text = function()
				local name = `{props.HeroName()}   Lv {props.Level()}`
				return if props.IsDead() then `{name} (reviving)` else name
			end,
			TextSize = HudTheme.BodyTextSize,
			TextColor3 = function()
				return if props.IsDead() then HudTheme.MutedTextColor else HudTheme.TextColor
			end,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		create("Frame")({
			Name = "HealthBar",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, HEALTH_BAR_HEIGHT),
			BackgroundColor3 = HudTheme.BarBackground,

			create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			create("Frame")({
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(math.clamp(props.Health() / getBarTotal(), 0, 1), 1)
				end,
				BackgroundColor3 = HudTheme.HealthColor,

				create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			}),
			create("Frame")({
				Name = "Shield",
				Visible = function()
					return props.Shield() > 0
				end,
				Position = function()
					return UDim2.fromScale(math.clamp(props.Health() / getBarTotal(), 0, 1), 0)
				end,
				Size = function()
					return UDim2.fromScale(math.clamp(props.Shield() / getBarTotal(), 0, 1), 1)
				end,
				BackgroundColor3 = HudTheme.ShieldColor,
				ZIndex = 2,

				create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			}),
			barText(function()
				local shield = props.Shield()
				local text = `{math.ceil(props.Health())} / {math.ceil(props.MaxHealth())}`
				return if shield > 0 then `{text} (+{math.ceil(shield)})` else text
			end, HudTheme.SmallTextSize),
		}),

		create("Frame")({
			Name = "ResourceBar",
			LayoutOrder = 3,
			-- A hero on cooldowns only has nothing to show here.
			Visible = function()
				return props.ResourceKind() ~= "None" and props.MaxResource() > 0
			end,
			Size = UDim2.new(1, 0, 0, RESOURCE_BAR_HEIGHT),
			BackgroundColor3 = HudTheme.BarBackground,

			create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			create("Frame")({
				Name = "Fill",
				Size = function()
					local maximum = math.max(props.MaxResource(), 1)
					return UDim2.fromScale(math.clamp(props.Resource() / maximum, 0, 1), 1)
				end,
				BackgroundColor3 = function()
					return HudTheme.ResourceColors[props.ResourceKind()]
						or HudTheme.FallbackResourceColor
				end,

				create("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			}),
			barText(function()
				return `{math.floor(props.Resource())} / {math.floor(props.MaxResource())}`
			end, 14),
		}),

		create("Frame")({
			Name = "XpBar",
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, XP_BAR_HEIGHT),
			BackgroundColor3 = HudTheme.BarBackground,

			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			create("Frame")({
				Name = "Fill",
				Size = function()
					return UDim2.fromScale(math.clamp(props.XpShare(), 0, 1), 1)
				end,
				BackgroundColor3 = XP_COLOR,

				create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
	})
end

return heroStatus
