--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const indexes = Vide.indexes
const show = Vide.show

const HudTheme = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HudTheme"
)

const LobbyKit = require("./_LobbyKit")

const CARD_SIZE = Vector2.new(168, 232)
const COMPACT_CARD_SIZE = Vector2.new(132, 200)
const CARD_GAP = 10
const SWATCH_HEIGHT = 0.42
const SCROLL_BAR_WIDTH = 8

const LobbyTypes = require("../LobbyTypes")

type HeroView = LobbyTypes.HeroView
type LobbyScreenProps = LobbyTypes.LobbyScreenProps
type SkinView = LobbyTypes.SkinView

local Module = {}

local function cardSize(isCompact: () -> boolean): UDim2
	local size = if isCompact() then COMPACT_CARD_SIZE else CARD_SIZE
	return UDim2.fromOffset(size.X, size.Y)
end

local function swatch(colors: () -> { Color3 }, initial: () -> string): GuiObject
	return create("Frame")({
		Name = "Swatch",
		Size = UDim2.fromScale(1, SWATCH_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),

		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
		create("UIGradient")({
			Rotation = 90,
			Color = function()
				local list = colors()
				local first = list[1] or HudTheme.PanelColor
				local last = list[2] or first:Lerp(Color3.new(0, 0, 0), 0.5)
				return ColorSequence.new(first, last)
			end,
		}),
		LobbyKit.label({
			Name = "Initial",
			Size = UDim2.fromScale(1, 1),
			Font = HudTheme.TitleFont,
			Text = initial,
			TextSize = 48,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 0.1,
			TextStrokeTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end

local function card(
	name: string,
	layoutOrder: number,
	isCompact: () -> boolean,
	children: { any }
): GuiObject
	return LobbyKit.panel({
		Name = name,
		LayoutOrder = layoutOrder,
		Size = function()
			return cardSize(isCompact)
		end,
		BackgroundColor3 = LobbyKit.CardColor,
		BackgroundTransparency = 0,

		LobbyKit.padding(6),
		create("UIListLayout")({
			Padding = UDim.new(0, 4),
		}),
		children,
	})
end

local function ownedLabel(layoutOrder: number): GuiObject
	return LobbyKit.label({
		Name = "Owned",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, LobbyKit.ButtonHeight),
		Font = HudTheme.Font,
		Text = "OWNED",
		TextColor3 = HudTheme.GoldColor,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

local function heroCard(
	hero: () -> HeroView,
	layoutOrder: number,
	props: LobbyScreenProps,
	isCompact: () -> boolean
): GuiObject
	local function canAfford(): boolean
		return props.Coins() >= hero().CoinPrice
	end

	return card("HeroCard", layoutOrder, isCompact, {
		swatch(function()
			return { hero().Color }
		end, function()
			return string.sub(hero().Name, 1, 1)
		end),
		LobbyKit.label({
			Name = "HeroName",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 20),
			Font = HudTheme.TitleFont,
			Text = function()
				return hero().Name
			end,
		}),
		LobbyKit.label({
			Name = "Role",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 16),
			Text = function()
				return hero().Role
			end,
			TextColor3 = HudTheme.MutedTextColor,
			TextSize = HudTheme.SmallTextSize,
		}),
		show(function()
			return hero().IsOwned
		end, function()
			return ownedLabel(4)
		end, function()
			return create("Frame")({
				Name = "BuyButtons",
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 64),
				BackgroundTransparency = 1,

				create("UIListLayout")({
					Padding = UDim.new(0, 4),
				}),
				LobbyKit.button("Dark", canAfford, function()
					props.OnBuyWithCoins(hero().Id)
				end, {
					Name = "BuyWithCoins",
					LayoutOrder = 4,
					Size = UDim2.new(1, 0, 0, 30),
					TextSize = HudTheme.SmallTextSize,
					Text = function()
						local price = hero().CoinPrice
						if canAfford() then
							return `{LobbyKit.formatNumber(price)} coins`
						end
						return `Need {LobbyKit.formatNumber(price - props.Coins())} more`
					end,
				}),
				LobbyKit.button("Gold", LobbyKit.alwaysEnabled, function()
					props.OnBuyWithRobux(hero().Id)
				end, {
					Name = "BuyWithRobux",
					LayoutOrder = 5,
					Size = UDim2.new(1, 0, 0, 30),
					TextSize = HudTheme.SmallTextSize,
					Text = function()
						return `R$ {LobbyKit.formatNumber(hero().RobuxPrice)}`
					end,
				}),
			})
		end),
	})
end

local function skinCard(
	skin: () -> SkinView,
	layoutOrder: number,
	props: LobbyScreenProps,
	isCompact: () -> boolean
): GuiObject
	return card("SkinCard", layoutOrder, isCompact, {
		swatch(function()
			return skin().Colors
		end, function()
			return string.sub(skin().HeroName, 1, 1)
		end),
		LobbyKit.label({
			Name = "SkinName",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 36),
			Font = HudTheme.TitleFont,
			Text = function()
				return skin().Name
			end,
			TextSize = HudTheme.SmallTextSize,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		LobbyKit.label({
			Name = "HeroName",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 16),
			Text = function()
				return `Skin for {skin().HeroName}`
			end,
			TextColor3 = HudTheme.MutedTextColor,
			TextSize = HudTheme.SmallTextSize,
		}),
		show(function()
			return skin().IsOwned
		end, function()
			return ownedLabel(4)
		end, function()
			return LobbyKit.button("Gold", LobbyKit.alwaysEnabled, function()
				props.OnBuyWithRobux(skin().Id)
			end, {
				Name = "BuyWithRobux",
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 34),
				Text = function()
					return `R$ {LobbyKit.formatNumber(skin().RobuxPrice)}`
				end,
			})
		end),
	})
end

local function grid(
	name: string,
	layoutOrder: number,
	isCompact: () -> boolean,
	cards: any
): GuiObject
	return create("Frame")({
		Name = name,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		create("UIGridLayout")({
			CellSize = function()
				return cardSize(isCompact)
			end,
			CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
		}),
		cards,
	})
end

local function sectionTitle(text: string, layoutOrder: number): GuiObject
	return LobbyKit.label({
		Name = `{text}Title`,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 26),
		Font = HudTheme.TitleFont,
		Text = text,
		TextColor3 = HudTheme.GoldColor,
		TextSize = HudTheme.TitleTextSize,
	})
end

local function emptyNote(text: string, layoutOrder: number): GuiObject
	return LobbyKit.label({
		Name = "Empty",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 24),
		Text = text,
		TextColor3 = HudTheme.MutedTextColor,
	})
end

local function scrollingPage(name: string, children: { any }): GuiObject
	return create("ScrollingFrame")({
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = SCROLL_BAR_WIDTH,
		ScrollBarImageColor3 = HudTheme.StrokeColor,
		ScrollingDirection = Enum.ScrollingDirection.Y,

		create("UIPadding")({
			PaddingRight = UDim.new(0, SCROLL_BAR_WIDTH + 4),
			PaddingTop = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
		}),
		create("UIListLayout")({
			Padding = UDim.new(0, 10),
		}),
		children,
	})
end

--[[
	Every hero, owned or not, with a way to unlock each locked one.
]]
function Module.heroesPage(props: LobbyScreenProps, isCompact: () -> boolean): GuiObject
	local function ownedCount(): number
		local count = 0
		for _, hero in props.Heroes() do
			if hero.IsOwned then
				count += 1
			end
		end
		return count
	end

	return scrollingPage("HeroesPage", {
		LobbyKit.label({
			Name = "Count",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 22),
			Text = function()
				return `You own {ownedCount()} of {#props.Heroes()} heroes`
			end,
			TextColor3 = HudTheme.MutedTextColor,
		}),
		grid(
			"Heroes",
			2,
			isCompact,
			indexes(props.Heroes, function(hero, index)
				return heroCard(hero, index, props, isCompact)
			end)
		),
	})
end

--[[
	Heroes still locked, then skins, each for sale.
]]
function Module.storePage(props: LobbyScreenProps, isCompact: () -> boolean): GuiObject
	local function lockedHeroes(): { HeroView }
		local result = {}
		for _, hero in props.Heroes() do
			if not hero.IsOwned then
				table.insert(result, hero)
			end
		end
		return result
	end

	return scrollingPage("StorePage", {
		sectionTitle("Heroes", 1),
		show(function()
			return #lockedHeroes() == 0
		end, function()
			return emptyNote("You own every hero. New heroes show up here.", 2)
		end),
		grid(
			"Heroes",
			3,
			isCompact,
			indexes(lockedHeroes, function(hero, index)
				return heroCard(hero, index, props, isCompact)
			end)
		),
		sectionTitle("Skins", 4),
		show(function()
			return #props.Skins() == 0
		end, function()
			return emptyNote("No skins for sale right now. Check back soon.", 5)
		end),
		grid(
			"Skins",
			6,
			isCompact,
			indexes(props.Skins, function(skin, index)
				return skinCard(skin, index, props, isCompact)
			end)
		),
	})
end

return Module
