--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const indexes = Vide.indexes
const show = Vide.show

const HudTheme = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HudTheme"
)

const LobbyKit = require("./_LobbyKit")

const ROW_HEIGHT = 52
const AVATAR_SIZE = 36
const INVITE_WIDTH = 72
const STATUS_TEXT = {
	Online = "Online",
	InGame = "In a game",
}

const LobbyTypes = require("../LobbyTypes")

type FriendView = LobbyTypes.FriendView
type LobbyScreenProps = LobbyTypes.LobbyScreenProps

local function friendRow(
	friend: () -> FriendView,
	layoutOrder: number,
	props: LobbyScreenProps
): GuiObject
	return create("Frame")({
		Name = "FriendRow",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,

		create("ImageLabel")({
			Name = "Avatar",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
			BackgroundColor3 = HudTheme.BarBackground,
			Image = function()
				return `rbxthumb://type=AvatarHeadShot&id={friend().UserId}&w=150&h=150`
			end,

			create("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			create("UIStroke")({
				Thickness = 2,
				Color = function()
					return if friend().Status == "InGame"
						then LobbyKit.InGameColor
						else LobbyKit.OnlineColor
				end,
			}),
		}),
		LobbyKit.label({
			Name = "FriendName",
			Position = UDim2.fromOffset(AVATAR_SIZE + 8, 6),
			Size = UDim2.new(1, -AVATAR_SIZE - INVITE_WIDTH - 16, 0, 20),
			Text = function()
				return friend().Name
			end,
		}),
		LobbyKit.label({
			Name = "Status",
			Position = UDim2.fromOffset(AVATAR_SIZE + 8, 26),
			Size = UDim2.new(1, -AVATAR_SIZE - INVITE_WIDTH - 16, 0, 18),
			Text = function()
				return STATUS_TEXT[friend().Status]
			end,
			TextColor3 = function()
				return if friend().Status == "InGame"
					then LobbyKit.InGameColor
					else LobbyKit.OnlineColor
			end,
			TextSize = HudTheme.SmallTextSize,
		}),
		LobbyKit.button("Dark", LobbyKit.alwaysEnabled, function()
			props.OnInvite(friend().UserId)
		end, {
			Name = "Invite",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(INVITE_WIDTH, LobbyKit.ButtonHeight),
			Text = "Invite",
			TextSize = HudTheme.SmallTextSize,
		}),
	})
end

--[[
	Online friends with an invite button each, and one to invite anyone.
]]
local function friendsPanel(props: LobbyScreenProps): GuiObject
	local function friends(): { FriendView }
		return props.Friends() or {}
	end

	local function emptyText(): string?
		local list = props.Friends()
		if list == nil then
			return "Loading friends..."
		elseif #list == 0 then
			return "No friends online right now. Invite some to play together."
		end
		return nil
	end

	return LobbyKit.panel({
		Name = "FriendsPanel",
		Size = UDim2.fromScale(1, 1),

		LobbyKit.padding(10),
		LobbyKit.label({
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 22),
			Font = HudTheme.Font,
			Text = function()
				local list = props.Friends()
				return if list then `FRIENDS  ({#list} online)` else "FRIENDS"
			end,
			TextColor3 = HudTheme.GoldColor,
			TextSize = HudTheme.SmallTextSize,
		}),
		LobbyKit.button("Gold", LobbyKit.alwaysEnabled, props.OnInviteFriends, {
			Name = "InviteFriends",
			Position = UDim2.fromOffset(0, 28),
			Text = "Invite friends",
		}),
		create("ScrollingFrame")({
			Name = "List",
			Position = UDim2.fromOffset(0, 28 + LobbyKit.ButtonHeight + 8),
			Size = UDim2.new(1, 0, 1, -(28 + LobbyKit.ButtonHeight + 8)),
			BackgroundTransparency = 1,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = HudTheme.StrokeColor,
			ScrollingDirection = Enum.ScrollingDirection.Y,

			create("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
			create("UIListLayout")({
				Padding = UDim.new(0, 4),
			}),
			show(emptyText, function(text)
				return LobbyKit.label({
					Name = "Empty",
					Size = UDim2.new(1, 0, 0, 60),
					Text = text,
					TextColor3 = HudTheme.MutedTextColor,
					TextSize = HudTheme.SmallTextSize,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
				})
			end),
			indexes(friends, function(friend, index)
				return friendRow(friend, index, props)
			end),
		}),
	})
end

return friendsPanel
