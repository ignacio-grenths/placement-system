--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const show = Vide.show
const source = Vide.source

const HudTheme = require(
	"@game/ServerScriptService/Modules/Systems/Presentation/MatchHudSystem/SystemPackage/HudTheme"
)

const LobbyKit = require("./_LobbyKit")

const PARTY_SIZE = 5
const LOCAL_SLOT = 3
const SLOT_GAP = 10
const FIND_MATCH_SIZE = Vector2.new(280, 56)
const COMPACT_FIND_MATCH_SIZE = Vector2.new(240, 46)
const DIM_TRANSPARENCY = 0.35
const SLOT_LABELS = {
	Primary = "1st",
	Secondary = "2nd",
}

const LobbyTypes = require("../LobbyTypes")

type LobbyScreenProps = LobbyTypes.LobbyScreenProps
type RoleSlot = LobbyTypes.RoleSlot

local function roleText(role: string?): string
	return role or "Fill"
end

local function slotRole(slot: RoleSlot, props: LobbyScreenProps): () -> string?
	return if slot == "Primary" then props.PrimaryRole else props.SecondaryRole
end

local function positionButton(
	slot: RoleSlot,
	layoutOrder: number,
	props: LobbyScreenProps,
	onOpen: (slot: RoleSlot) -> ()
): GuiObject
	local role = slotRole(slot, props)
	return LobbyKit.button("Dark", LobbyKit.alwaysEnabled, function()
		onOpen(slot)
	end, {
		Name = `{slot}Position`,
		LayoutOrder = layoutOrder,
		Text = function()
			return `{SLOT_LABELS[slot]}: {roleText(role())}`
		end,
	})
end

local function localSlot(
	props: LobbyScreenProps,
	isCompact: () -> boolean,
	onOpenRoles: (slot: RoleSlot) -> ()
): GuiObject
	local function isNotCompact(): boolean
		return not isCompact()
	end

	return create("Frame")({
		Name = "LocalSlot",
		LayoutOrder = LOCAL_SLOT,
		Size = UDim2.new(1 / PARTY_SIZE, -SLOT_GAP * (PARTY_SIZE - 1) / PARTY_SIZE, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),

		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),

		create("UIGradient")({
			Color = ColorSequence.new(Color3.fromRGB(40, 66, 58), HudTheme.PanelColor),
			Rotation = 90,
		}),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = HudTheme.BrightStrokeColor,
			Thickness = 2,
		}),
		LobbyKit.padding(6),
		create("UIListLayout")({
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
		}),
		LobbyKit.avatar(props.PlayerUserId, {
			Name = "Avatar",
			LayoutOrder = 1,
			Size = function()
				local side = if isCompact() then 40 else 96
				return UDim2.fromOffset(side, side)
			end,
		}),
		LobbyKit.label({
			Name = "PlayerName",
			LayoutOrder = 2,
			-- A phone has room only for the avatar and the two positions.
			Visible = isNotCompact,
			Size = UDim2.new(1, 0, 0, 22),
			Font = HudTheme.TitleFont,
			Text = props.PlayerName,
			TextSize = HudTheme.TitleTextSize,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		LobbyKit.label({
			Name = "Leader",
			LayoutOrder = 3,
			Visible = isNotCompact,
			Size = UDim2.new(1, 0, 0, 18),
			Text = "Party leader",
			TextColor3 = HudTheme.MutedTextColor,
			TextSize = HudTheme.SmallTextSize,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		positionButton("Primary", 4, props, onOpenRoles),
		positionButton("Secondary", 5, props, onOpenRoles),
	})
end

local function inviteSlot(layoutOrder: number, props: LobbyScreenProps): GuiObject
	return create("TextButton")({
		Name = "InviteSlot",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1 / PARTY_SIZE, -SLOT_GAP * (PARTY_SIZE - 1) / PARTY_SIZE, 0.82, 0),
		AutoButtonColor = true,
		BackgroundColor3 = LobbyKit.CardColor,
		BackgroundTransparency = 0.3,
		Text = "",
		Activated = props.OnInviteFriends,

		create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = LobbyKit.IdleStrokeColor,
		}),
		LobbyKit.label({
			Name = "Plus",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(48, 48),
			Font = HudTheme.TitleFont,
			Text = "+",
			TextColor3 = HudTheme.StrokeColor,
			TextSize = 44,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		LobbyKit.label({
			Name = "Invite",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -8, 0, 22),
			Text = "Invite",
			TextColor3 = HudTheme.MutedTextColor,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})
end

local function rolePicker(slot: RoleSlot, props: LobbyScreenProps, onClose: () -> ()): GuiObject
	local current = slotRole(slot, props)

	local buttons = {}
	-- One past the last role is Fill.
	for index = 1, #props.Roles + 1 do
		local role: string? = props.Roles[index]
		local isCurrent = function()
			return current() == role
		end
		table.insert(
			buttons,
			LobbyKit.button("Dark", LobbyKit.alwaysEnabled, function()
				props.OnSetRole(slot, role)
				onClose()
			end, {
				Name = roleText(role),
				LayoutOrder = index,
				Size = UDim2.fromOffset(96, LobbyKit.ButtonHeight),
				BackgroundColor3 = function()
					return if isCurrent()
						then LobbyKit.GoldButtonColor
						else LobbyKit.DarkButtonColor
				end,
				TextColor3 = function()
					return if isCurrent() then LobbyKit.GoldButtonTextColor else HudTheme.TextColor
				end,
				Text = roleText(role),
			})
		)
	end

	return create("TextButton")({
		Name = "RolePicker",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = DIM_TRANSPARENCY,
		Text = "",
		ZIndex = 5,
		-- A press on the dim area closes the picker, like Cancel.
		Activated = onClose,

		LobbyKit.panel({
			Name = "Panel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			-- Swallows presses, so tapping the panel doesn't close it.
			Active = true,
			BackgroundTransparency = 0,

			LobbyKit.padding(14),
			create("UIListLayout")({
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 10),
			}),
			LobbyKit.label({
				Name = "Title",
				LayoutOrder = 1,
				Size = UDim2.fromOffset(420, 26),
				Font = HudTheme.TitleFont,
				Text = `Choose your {if slot == "Primary" then "first" else "second"} position`,
				TextSize = HudTheme.TitleTextSize,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			create("Frame")({
				Name = "Choices",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,

				create("UIGridLayout")({
					CellSize = UDim2.fromOffset(96, LobbyKit.ButtonHeight),
					CellPadding = UDim2.fromOffset(8, 8),
					FillDirectionMaxCells = 3,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				}),
				buttons,
			}),
			LobbyKit.button("Dark", LobbyKit.alwaysEnabled, onClose, {
				Name = "Cancel",
				LayoutOrder = 3,
				Size = UDim2.fromOffset(160, LobbyKit.ButtonHeight),
				Text = "Cancel",
			}),
		}),
	})
end

--[[
	The party, your two positions, and Find Match.
]]
local function playPage(props: LobbyScreenProps, isCompact: () -> boolean): GuiObject
	local pickingSlot = source(nil :: RoleSlot?)

	local function openRoles(slot: RoleSlot)
		pickingSlot(slot)
	end

	local slots = {}
	for index = 1, PARTY_SIZE do
		table.insert(
			slots,
			if index == LOCAL_SLOT
				then localSlot(props, isCompact, openRoles)
				else inviteSlot(index, props)
		)
	end

	local function isFindMatchEnabled(): boolean
		return props.FindMatchBlocked() == nil
	end

	local function findMatchSize(): Vector2
		return if isCompact() then COMPACT_FIND_MATCH_SIZE else FIND_MATCH_SIZE
	end

	local function footerHeight(): number
		return findMatchSize().Y + 24
	end

	-- Typed any: a children binding sits among instances in the table below.
	local rolePickerLayer: any = show(function()
		return pickingSlot() ~= nil
	end, function()
		return rolePicker(pickingSlot() :: RoleSlot, props, function()
			pickingSlot(nil)
		end)
	end)

	return create("Frame")({
		Name = "PlayPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		LobbyKit.label({
			Name = "Mode",
			Size = UDim2.new(1, 0, 0, 22),
			Font = HudTheme.Font,
			Text = "PARTY  ·  NORMAL 5v5 VS BOTS",
			TextColor3 = HudTheme.MutedTextColor,
			TextSize = HudTheme.SmallTextSize,
		}),
		create("Frame")({
			Name = "Party",
			Position = UDim2.fromOffset(0, 30),
			Size = function()
				return UDim2.new(1, 0, 1, -30 - footerHeight() - 8)
			end,
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, SLOT_GAP),
			}),
			slots,
		}),
		create("Frame")({
			Name = "Footer",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = function()
				return UDim2.new(1, 0, 0, footerHeight())
			end,
			BackgroundTransparency = 1,

			LobbyKit.button("Gold", isFindMatchEnabled, props.OnFindMatch, {
				Name = "FindMatch",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = function()
					local size = findMatchSize()
					return UDim2.fromOffset(size.X, size.Y)
				end,
				Font = HudTheme.TitleFont,
				Text = "FIND MATCH",
				TextSize = 26,
			}),
			LobbyKit.label({
				Name = "Note",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, 20),
				Text = function()
					return props.FindMatchBlocked() or "Bots fill every empty slot"
				end,
				TextColor3 = HudTheme.MutedTextColor,
				TextSize = HudTheme.SmallTextSize,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		}),
		rolePickerLayer,
	})
end

return playPage
