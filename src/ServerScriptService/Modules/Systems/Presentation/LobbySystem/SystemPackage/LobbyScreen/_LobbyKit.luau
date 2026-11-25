--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create

const HudTheme = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HudTheme"
)

type Properties = { [any]: any }
export type ButtonStyle = "Gold" | "Dark"

local Module = {}

Module.GoldButtonColor = Color3.fromRGB(196, 146, 58)
Module.GoldButtonTextColor = Color3.fromRGB(28, 18, 8)
Module.DarkButtonColor = Color3.fromRGB(22, 38, 42)
Module.DisabledButtonColor = Color3.fromRGB(40, 44, 42)
Module.CardColor = HudTheme.BarBackground
Module.IdleStrokeColor = Color3.fromRGB(80, 72, 52)
Module.OnlineColor = Color3.fromRGB(90, 200, 110)
Module.InGameColor = Color3.fromRGB(240, 190, 70)
Module.ButtonHeight = 44

local function merge(base: Properties, properties: Properties): Properties
	for key, value in properties do
		-- Number keys are children, so they add to the base's children
		-- instead of replacing them.
		if typeof(key) == "number" then
			table.insert(base, value)
		else
			base[key] = value
		end
	end
	return base
end

function Module.label(properties: Properties): GuiObject
	return create("TextLabel")(merge({
		BackgroundTransparency = 1,
		Font = HudTheme.BodyFont,
		TextColor3 = HudTheme.TextColor,
		TextSize = HudTheme.BodyTextSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, properties))
end

--[[
	A button in one of the lobby's two styles. While IsEnabled reads false it
	turns gray, stops reacting to presses, and its text should say why.
]]
function Module.button(
	style: ButtonStyle,
	isEnabled: () -> boolean,
	onActivated: () -> (),
	properties: Properties
): GuiObject
	local enabledColor = if style == "Gold" then Module.GoldButtonColor else Module.DarkButtonColor
	local enabledTextColor = if style == "Gold"
		then Module.GoldButtonTextColor
		else HudTheme.TextColor
	return create("TextButton")(merge({
		Size = UDim2.new(1, 0, 0, Module.ButtonHeight),
		AutoButtonColor = isEnabled,
		BackgroundColor3 = function()
			return if isEnabled() then enabledColor else Module.DisabledButtonColor
		end,
		Font = HudTheme.Font,
		TextSize = HudTheme.BodyTextSize,
		TextColor3 = function()
			return if isEnabled() then enabledTextColor else HudTheme.MutedTextColor
		end,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Activated = function()
			if isEnabled() then
				onActivated()
			end
		end,

		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = HudTheme.StrokeColor,
			Transparency = function()
				return if isEnabled() then 0.2 else 0.8
			end,
		}),
	}, properties))
end

function Module.alwaysEnabled(): boolean
	return true
end

--[[
	A forest-night panel with gold trim, the frame every lobby section sits in.
]]
function Module.panel(properties: Properties): GuiObject
	return create("Frame")(merge({
		BackgroundColor3 = HudTheme.PanelColor,
		BackgroundTransparency = HudTheme.PanelTransparency,

		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = HudTheme.StrokeColor,
			Transparency = 0.3,
		}),
	}, properties))
end

function Module.padding(pixels: number): UIPadding
	return create("UIPadding")({
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
	})
end

--[[
	A player's head shot. The rbxthumb URL loads on its own, so nothing yields.
]]
function Module.avatar(userId: number, properties: Properties): GuiObject
	return create("ImageLabel")(merge({
		BackgroundColor3 = HudTheme.BarBackground,
		Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`,

		create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
		create("UIStroke")({ Color = HudTheme.StrokeColor, Thickness = 2 }),
	}, properties))
end

--[[
	Writes a whole number with thousands separators, such as 12,500.
]]
function Module.formatNumber(value: number): string
	local text = tostring(math.floor(value))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

return Module
