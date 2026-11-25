--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const derive = Vide.derive
const indexes = Vide.indexes
const show = Vide.show
const source = Vide.source
const switch = Vide.switch

const HudTheme = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HudTheme"
)

const CollectionPages = require("@self/_CollectionPages")
const FriendsPanel = require("@self/_FriendsPanel")
const LobbyKit = require("@self/_LobbyKit")
const PlayPage = require("@self/_PlayPage")

const GAME_TITLE = "CRASHPOINT VALLEY"
const TOP_COLOR = Color3.fromRGB(6, 14, 16)
const BOTTOM_COLOR = Color3.fromRGB(18, 34, 28)
const TOP_BAR_HEIGHT = 56
const COMPACT_TOP_BAR_HEIGHT = 48
const PADDING = 16
const COMPACT_PADDING = 8
const FRIENDS_WIDTH = 260
const TAB_WIDTH = 104
const COMPACT_TAB_WIDTH = 84
const COIN_SIZE = 18

const LobbyTypes = require("./LobbyTypes")

type LobbyScreenProps = LobbyTypes.LobbyScreenProps
type Page = LobbyTypes.Page

const PAGES: { Page } = { "Play", "Heroes", "Store" }
const COMPACT_PAGES: { Page } = { "Play", "Heroes", "Store", "Friends" }

local function tab(
	page: () -> string,
	layoutOrder: number,
	shownPage: () -> string,
	isCompact: () -> boolean,
	onSelect: (page: Page) -> ()
): GuiObject
	local function isActive(): boolean
		return shownPage() == page()
	end

	return create("TextButton")({
		Name = "Tab",
		LayoutOrder = layoutOrder,
		Size = function()
			return UDim2.new(0, if isCompact() then COMPACT_TAB_WIDTH else TAB_WIDTH, 1, 0)
		end,
		BackgroundTransparency = 1,
		Font = HudTheme.Font,
		Text = function()
			return string.upper(page())
		end,
		TextSize = HudTheme.BodyTextSize,
		TextColor3 = function()
			return if isActive() then HudTheme.GoldColor else HudTheme.MutedTextColor
		end,
		Activated = function()
			onSelect(page() :: Page)
		end,

		create("Frame")({
			Name = "Underline",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(0.8, 0, 0, 3),
			BackgroundColor3 = HudTheme.GoldColor,
			Visible = isActive,
		}),
	})
end

local function coinChip(props: LobbyScreenProps): GuiObject
	return LobbyKit.panel({
		Name = "Coins",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = HudTheme.BarBackground,

		create("UIPadding")({
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 12),
		}),
		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
		create("Frame")({
			Name = "Coin",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE),
			BackgroundColor3 = HudTheme.GoldColor,

			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			create("UIStroke")({ Color = Color3.fromRGB(150, 100, 30), Thickness = 2 }),
		}),
		LobbyKit.label({
			Name = "Amount",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			Font = HudTheme.Font,
			Text = function()
				return LobbyKit.formatNumber(props.Coins())
			end,
			TextColor3 = HudTheme.GoldColor,
		}),
	})
end

local function topBar(
	props: LobbyScreenProps,
	shownPage: () -> string,
	isCompact: () -> boolean,
	onSelect: (page: Page) -> ()
): GuiObject
	return create("Frame")({
		Name = "TopBar",
		Size = function()
			return UDim2.new(
				1,
				0,
				0,
				if isCompact() then COMPACT_TOP_BAR_HEIGHT else TOP_BAR_HEIGHT
			)
		end,
		BackgroundColor3 = HudTheme.PanelColor,
		BackgroundTransparency = HudTheme.PanelTransparency,

		create("Frame")({
			Name = "Trim",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = HudTheme.StrokeColor,
		}),
		create("Frame")({
			Name = "Left",
			Size = UDim2.fromScale(0.75, 1),
			BackgroundTransparency = 1,

			create("UIPadding")({ PaddingLeft = UDim.new(0, PADDING) }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 12),
			}),
			show(function()
				return not isCompact()
			end, function()
				return LobbyKit.label({
					Name = "Title",
					LayoutOrder = 0,
					Size = UDim2.fromOffset(230, 30),
					Font = Enum.Font.Fondamento,
					Text = GAME_TITLE,
					TextColor3 = HudTheme.GoldColor,
					TextSize = 26,
				})
			end),
			indexes(function()
				return if isCompact() then COMPACT_PAGES else PAGES
			end, function(page, index)
				return tab(page, index, shownPage, isCompact, onSelect)
			end),
		}),
		create("Frame")({
			Name = "Right",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.25, 1),
			BackgroundTransparency = 1,

			create("UIPadding")({ PaddingRight = UDim.new(0, PADDING) }),
			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
			}),
			coinChip(props),
			LobbyKit.avatar(props.PlayerUserId, {
				Name = "Avatar",
				LayoutOrder = 2,
				Size = UDim2.fromOffset(36, 36),
			}),
		}),
	})
end

local function notice(props: LobbyScreenProps): any
	return show(props.Notice, function(text)
		return LobbyKit.panel({
			Name = "Notice",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -PADDING),
			Size = UDim2.fromOffset(0, 44),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			ZIndex = 10,

			create("UIPadding")({
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
			LobbyKit.label({
				Name = "Text",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = text,
				ZIndex = 10,
			}),
		})
	end)
end

--[[
	The lobby players see once loaded: the party and Find Match, every hero,
	the store, and online friends.
]]
local function lobbyScreen(props: LobbyScreenProps)
	local page = source(props.StartPage or "Play" :: Page)

	-- The Friends page exists only on the compact layout, where the friends
	-- panel has no room beside the page.
	local shownPage = derive(function(): Page
		if page() == "Friends" and not props.IsCompact() then
			return "Play"
		end
		return page()
	end)

	local function padding(): number
		return if props.IsCompact() then COMPACT_PADDING else PADDING
	end

	local function topBarHeight(): number
		return if props.IsCompact() then COMPACT_TOP_BAR_HEIGHT else TOP_BAR_HEIGHT
	end

	return show(props.IsOpen, function()
		return create("Frame")({
			Name = "Lobby",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			-- Keeps clicks from reaching the world under the lobby.
			Active = true,
			ZIndex = 20,

			create("UIGradient")({
				Color = ColorSequence.new(TOP_COLOR, BOTTOM_COLOR),
				Rotation = 90,
			}),
			create("Frame")({
				Name = "Scaled",
				Size = function()
					local scale = props.UiScale()
					return UDim2.fromScale(1 / scale, 1 / scale)
				end,
				BackgroundTransparency = 1,

				create("UIScale")({ Scale = props.UiScale }),
				topBar(props, shownPage, props.IsCompact, page),
				create("Frame")({
					Name = "Body",
					Position = function()
						return UDim2.fromOffset(padding(), topBarHeight() + padding())
					end,
					Size = function()
						return UDim2.new(1, -padding() * 2, 1, -topBarHeight() - padding() * 2)
					end,
					BackgroundTransparency = 1,

					create("Frame")({
						Name = "Main",
						Size = function()
							local friendsRoom = if props.IsCompact()
								then 0
								else FRIENDS_WIDTH + PADDING
							return UDim2.new(1, -friendsRoom, 1, 0)
						end,
						BackgroundTransparency = 1,

						switch(shownPage)({
							Play = function()
								return PlayPage(props, props.IsCompact)
							end,
							Heroes = function()
								return CollectionPages.heroesPage(props, props.IsCompact)
							end,
							Store = function()
								return CollectionPages.storePage(props, props.IsCompact)
							end,
							Friends = function()
								return FriendsPanel(props)
							end,
						}),
					}),
					show(function()
						return not props.IsCompact()
					end, function()
						return create("Frame")({
							Name = "Side",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(0, FRIENDS_WIDTH, 1, 0),
							BackgroundTransparency = 1,

							FriendsPanel(props),
						})
					end),
				}),
				notice(props),
			}),
		})
	end)
end

return lobbyScreen
