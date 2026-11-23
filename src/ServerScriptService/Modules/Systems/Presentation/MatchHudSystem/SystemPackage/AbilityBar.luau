--!strict

const UserInputService = game:GetService("UserInputService")

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const cleanup = Vide.cleanup
const create = Vide.create
const derive = Vide.derive
const indexes = Vide.indexes
const read = Vide.read
const show = Vide.show

-- Pixels a touch travels before a press on a button aims instead of
-- casting at the nearest target.
const DRAG_THRESHOLD = 14
-- Pixels of drag that aim at an ability's full range.
const FULL_DRAG = 120
const CORNER_RADIUS = UDim.new(0, 10)
const STROKE_THICKNESS = 2
const LABEL_FONT = Enum.Font.GothamBold
const NAME_PADDING = 6

const READY_COLOR = Color3.fromRGB(34, 40, 54)
const BLOCKED_COLOR = Color3.fromRGB(26, 26, 32)
const EMPTY_COLOR = Color3.fromRGB(20, 22, 28)
const STROKE_COLOR = Color3.fromRGB(110, 140, 190)
const TEXT_COLOR = Color3.fromRGB(240, 242, 248)
const MUTED_TEXT_COLOR = Color3.fromRGB(150, 155, 170)
const COST_COLOR = Color3.fromRGB(120, 200, 255)
const BLOCKED_COST_COLOR = Color3.fromRGB(255, 110, 110)
const COOLDOWN_SHADE = Color3.new(0, 0, 0)
const COOLDOWN_SHADE_TRANSPARENCY = 0.35
const CHANNEL_BACKGROUND = Color3.fromRGB(20, 22, 28)
const CHANNEL_FILL = Color3.fromRGB(120, 200, 255)
-- Text is drawn see-through on buttons that can't cast, as a second cue to
-- the darker fill and red cost.
const BLOCKED_TEXT_TRANSPARENCY = 0.45
const COOLING_NAME_TRANSPARENCY = 0.85

-- Sizes in UI units for a 1080p screen. The HUD's UIScale grows them on
-- larger screens. Touch buttons are bigger so thumbs hit them.
type Metrics = {
	MainSize: number,
	SmallSize: number,
	Gap: number,
	Margin: number,
	KeyTextSize: number,
	NameTextSize: number,
	CostTextSize: number,
	CooldownTextSize: number,
	ChannelSize: Vector2,
}

const DESKTOP: Metrics = table.freeze({
	MainSize = 64,
	SmallSize = 48,
	Gap = 8,
	Margin = 20,
	KeyTextSize = 14,
	NameTextSize = 12,
	CostTextSize = 12,
	CooldownTextSize = 24,
	ChannelSize = Vector2.new(240, 22),
})

const TOUCH: Metrics = table.freeze({
	MainSize = 84,
	SmallSize = 60,
	Gap = 12,
	Margin = 24,
	KeyTextSize = 14,
	NameTextSize = 14,
	CostTextSize = 14,
	CooldownTextSize = 28,
	ChannelSize = Vector2.new(240, 26),
})

export type AbilityView = {
	Slot: string,
	-- The key or button that casts it, such as "Q" or "LB".
	KeyLabel: string,
	Name: string,
	-- Main buttons are the hero's own abilities; spells and recall are small.
	IsMain: boolean,
	Cost: number,
	CanAfford: boolean,
	-- Seconds left, 0 when ready.
	CooldownRemaining: number,
	CooldownDuration: number,
	-- True while the slot holds no ability yet.
	IsEmpty: boolean,
}

export type ChannelView = {
	Name: string,
	-- 0 at the start of the channel, 1 when it completes.
	Progress: number,
}

export type AbilityBarProps = {
	Abilities: () -> { AbilityView },
	Channel: () -> ChannelView?,
	IsTouch: boolean | () -> boolean,
	-- Called with the slot and, for a dragged touch, the aim as a screen
	-- direction (y down) whose length is the share of full range, up to 1.
	-- Nil aim means cast at the nearest fitting target.
	OnCast: (slot: string, aim: Vector2?) -> (),
}

type ButtonProps = {
	Ability: () -> AbilityView,
	Metrics: () -> Metrics,
	LayoutOrder: number,
	OnCast: (slot: string, aim: Vector2?) -> (),
}

local function formatCooldown(remaining: number): string
	return if remaining >= 1
		then tostring(math.ceil(remaining))
		else string.format("%.1f", remaining)
end

local function abilityButton(props: ButtonProps): TextButton
	local ability = props.Ability
	local metrics = props.Metrics
	local activeTouch: InputObject? = nil
	local touchStart = Vector2.zero

	-- Touch casts on release so the thumb can drag to aim first. The release
	-- can land anywhere on screen, so it is heard from the input service.
	cleanup(UserInputService.TouchEnded:Connect(function(touch: InputObject)
		if touch ~= activeTouch then
			return
		end
		activeTouch = nil
		local drag = Vector2.new(touch.Position.X, touch.Position.Y) - touchStart
		local aim = if drag.Magnitude >= DRAG_THRESHOLD
			then drag.Unit * math.min(drag.Magnitude / FULL_DRAG, 1)
			else nil
		props.OnCast(ability().Slot, aim)
	end))

	local function isBlocked(): boolean
		local view = ability()
		return view.IsEmpty or not view.CanAfford
	end

	local function getSize(): number
		return if ability().IsMain then metrics().MainSize else metrics().SmallSize
	end

	return create("TextButton")({
		Name = function()
			return ability().Slot
		end,
		LayoutOrder = props.LayoutOrder,
		Text = "",
		Size = function()
			local size = getSize()
			return UDim2.fromOffset(size, size)
		end,
		BackgroundColor3 = function()
			local view = ability()
			return if view.IsEmpty
				then EMPTY_COLOR
				elseif view.CanAfford then READY_COLOR
				else BLOCKED_COLOR
		end,

		Activated = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				return
			end
			props.OnCast(ability().Slot, nil)
		end,
		InputBegan = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				activeTouch = input
				touchStart = Vector2.new(input.Position.X, input.Position.Y)
			end
		end,

		create("UICorner")({ CornerRadius = CORNER_RADIUS }),
		create("UIStroke")({
			Color = STROKE_COLOR,
			Thickness = STROKE_THICKNESS,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = function()
				return if isBlocked() then BLOCKED_TEXT_TRANSPARENCY else 0
			end,
		}),

		create("TextLabel")({
			Name = "AbilityName",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = function()
				local size = getSize() - NAME_PADDING * 2
				return UDim2.fromOffset(size, size)
			end,
			Font = LABEL_FONT,
			Text = function()
				return ability().Name
			end,
			TextSize = function()
				return metrics().NameTextSize
			end,
			TextWrapped = true,
			TextColor3 = TEXT_COLOR,
			TextTransparency = function()
				-- The countdown takes the name's place while the ability cools down.
				if ability().CooldownRemaining > 0 then
					return COOLING_NAME_TRANSPARENCY
				end
				return if isBlocked() then BLOCKED_TEXT_TRANSPARENCY else 0
			end,
		}),

		create("TextLabel")({
			Name = "KeyLabel",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 5, 1, -3),
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = LABEL_FONT,
			Text = function()
				return ability().KeyLabel
			end,
			TextSize = function()
				return metrics().KeyTextSize
			end,
			TextColor3 = MUTED_TEXT_COLOR,
			ZIndex = 3,
		}),

		create("TextLabel")({
			Name = "Cost",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 3),
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = LABEL_FONT,
			Visible = function()
				return ability().Cost > 0
			end,
			Text = function()
				return tostring(ability().Cost)
			end,
			TextSize = function()
				return metrics().CostTextSize
			end,
			TextColor3 = function()
				return if ability().CanAfford then COST_COLOR else BLOCKED_COST_COLOR
			end,
			ZIndex = 3,
		}),

		create("Frame")({
			Name = "CooldownShade",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = function()
				local view = ability()
				local share = if view.CooldownDuration > 0
					then math.clamp(view.CooldownRemaining / view.CooldownDuration, 0, 1)
					else 0
				return UDim2.fromScale(1, share)
			end,
			BackgroundColor3 = COOLDOWN_SHADE,
			BackgroundTransparency = COOLDOWN_SHADE_TRANSPARENCY,
			Visible = function()
				return ability().CooldownRemaining > 0
			end,
			ZIndex = 2,

			create("UICorner")({ CornerRadius = CORNER_RADIUS }),
		}),

		create("TextLabel")({
			Name = "CooldownTime",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = LABEL_FONT,
			Visible = function()
				return ability().CooldownRemaining > 0
			end,
			Text = function()
				return formatCooldown(ability().CooldownRemaining)
			end,
			TextSize = function()
				return metrics().CooldownTextSize
			end,
			TextColor3 = TEXT_COLOR,
			TextStrokeTransparency = 0.4,
			ZIndex = 3,
		}),
	})
end

local function channelBar(
	channel: () -> ChannelView?,
	metrics: () -> Metrics,
	layoutOrder: number
): Frame
	return create("Frame")({
		Name = "ChannelBar",
		LayoutOrder = layoutOrder,
		Size = function()
			local size = metrics().ChannelSize
			return UDim2.fromOffset(size.X, size.Y)
		end,
		BackgroundColor3 = CHANNEL_BACKGROUND,
		Visible = function()
			return channel() ~= nil
		end,

		create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		create("Frame")({
			Name = "Fill",
			Size = function()
				local current = channel()
				return UDim2.fromScale(if current then math.clamp(current.Progress, 0, 1) else 0, 1)
			end,
			BackgroundColor3 = CHANNEL_FILL,

			create("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
		}),
		create("TextLabel")({
			Name = "ChannelName",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = LABEL_FONT,
			Text = function()
				local current = channel()
				return if current then current.Name else ""
			end,
			TextSize = function()
				return metrics().KeyTextSize
			end,
			TextColor3 = TEXT_COLOR,
			TextStrokeTransparency = 0.4,
		}),
	})
end

local function buttonRow(
	abilities: () -> { AbilityView },
	metrics: () -> Metrics,
	onCast: (slot: string, aim: Vector2?) -> (),
	layoutOrder: number
): Frame
	return create("Frame")({
		Name = "Row",
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = function()
				return UDim.new(0, metrics().Gap)
			end,
		}),
		indexes(abilities, function(ability, index)
			return abilityButton({
				Ability = ability,
				Metrics = metrics,
				LayoutOrder = index,
				OnCast = onCast,
			})
		end),
	})
end

--[[
	The hero's ability, summoner spell, and recall buttons, with cooldowns,
	costs, and the progress of a channel. Touch players get a larger cluster
	in the bottom-right corner; everyone else a row at the bottom middle.
]]
local function abilityBar(props: AbilityBarProps): Frame
	local isTouch = derive(function()
		return read(props.IsTouch)
	end)
	local metrics = derive(function(): Metrics
		return if isTouch() then TOUCH else DESKTOP
	end)
	local mainAbilities = derive(function()
		local mains = {}
		for _, view in props.Abilities() do
			if view.IsMain then
				table.insert(mains, view)
			end
		end
		return mains
	end)
	local smallAbilities = derive(function()
		local smalls = {}
		for _, view in props.Abilities() do
			if not view.IsMain then
				table.insert(smalls, view)
			end
		end
		return smalls
	end)

	return create("Frame")({
		Name = "AbilityBar",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		AnchorPoint = function()
			return if isTouch() then Vector2.new(1, 1) else Vector2.new(0.5, 1)
		end,
		Position = function()
			local margin = metrics().Margin
			return if isTouch()
				then UDim2.new(1, -margin, 1, -margin)
				else UDim2.new(0.5, 0, 1, -margin)
		end,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = function()
				return if isTouch()
					then Enum.HorizontalAlignment.Right
					else Enum.HorizontalAlignment.Center
			end,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = function()
				return UDim.new(0, metrics().Gap)
			end,
		}),

		channelBar(props.Channel, metrics, 1),

		show(isTouch, function()
			-- Spells above a two-by-two block of abilities, within thumb reach
			-- of the bottom-right corner.
			return create("Frame")({
				Name = "TouchCluster",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, TOUCH.Gap),
				}),
				buttonRow(smallAbilities, metrics, props.OnCast, 1),
				create("Frame")({
					Name = "MainGrid",
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.XY,

					create("UIGridLayout")({
						CellSize = UDim2.fromOffset(TOUCH.MainSize, TOUCH.MainSize),
						CellPadding = UDim2.fromOffset(TOUCH.Gap, TOUCH.Gap),
						FillDirectionMaxCells = 2,
					}),
					indexes(mainAbilities, function(ability, index)
						return abilityButton({
							Ability = ability,
							Metrics = metrics,
							LayoutOrder = index,
							OnCast = props.OnCast,
						})
					end),
				}),
			})
		end, function()
			return create("Frame")({
				Name = "DesktopRow",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.XY,

				create("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					Padding = UDim.new(0, DESKTOP.Gap * 2),
				}),
				buttonRow(mainAbilities, metrics, props.OnCast, 1),
				buttonRow(smallAbilities, metrics, props.OnCast, 2),
			})
		end),
	})
end

return abilityBar
