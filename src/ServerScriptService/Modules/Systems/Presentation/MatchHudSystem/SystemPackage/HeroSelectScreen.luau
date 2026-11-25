--!strict

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const create = Vide.create
const derive = Vide.derive
const indexes = Vide.indexes
const show = Vide.show
const source = Vide.source

const HudTheme = require("./HudTheme")

const DIM_COLOR = Color3.new(0, 0, 0)
const DIM_TRANSPARENCY = 0.35
-- Room kept between the panel and the screen's edges, in UI units.
const EDGE_PADDING = 8
-- Past half size the panel's text can't be read, so it runs off instead.
const MINIMUM_FIT_SCALE = 0.5
const CARD_RADIUS = 6
const SWATCH_INSET = 4
const CARD_COLOR = HudTheme.BarBackground
const CARD_HOVER_COLOR = Color3.fromRGB(24, 36, 62)
const IDLE_STROKE_COLOR = Color3.fromRGB(40, 56, 90)
const SELECTED_STROKE_THICKNESS = 3
const BLOCKED_TRANSPARENCY = 0.3
const LOCK_COLOR = Color3.fromRGB(60, 140, 90)
const DISABLED_COLOR = Color3.fromRGB(48, 50, 60)
const ROW_MARK_WIDTH = 4
const ROW_TEXT_GAP = 8
const NEUTRAL_MARK_COLOR = Color3.fromRGB(90, 100, 120)

export type HeroCardView = {
	Id: string,
	Name: string,
	Title: string,
	Role: string,
	-- What the hero spends, such as "Mana" or "Cooldowns only".
	ResourceName: string,
	-- Ability names in slot order.
	Abilities: { string },
	Color: Color3,
	-- Why the hero can't be picked, such as "Taken". Nil when it can.
	Blocked: string?,
}

export type TeammateView = {
	Name: string,
	-- "" until the teammate chooses a hero.
	HeroName: string,
	IsLockedIn: boolean,
	IsLocalPlayer: boolean,
}

export type HeroSelectScreenProps = {
	IsOpen: () -> boolean,
	-- The grid's columns, left to right.
	Roles: { string },
	-- Every hero that can be picked, each in its role's column in list order.
	Heroes: () -> { HeroCardView },
	-- The local player's team.
	Team: () -> string,
	Teammates: () -> { TeammateView },
	-- Roster rows. Rows no teammate fills show the bot that will.
	TeamSize: number,
	SelectedHeroId: () -> string?,
	IsLockedIn: () -> boolean,
	-- Nil while the countdown waits for players to load.
	SecondsLeft: () -> number?,
	IsCompact: () -> boolean,
	-- Room the panel may take, in UI units. It shrinks to fit.
	MaxSize: () -> Vector2,
	-- The screen's UI scale, which the panel grows by on large screens.
	UiScale: () -> number,
	OnPick: (heroId: string) -> (),
	OnLockIn: () -> (),
}

type Metrics = {
	Padding: number,
	Gap: number,
	HeaderHeight: number,
	TitleTextSize: number,
	BodyTextSize: number,
	SmallTextSize: number,
	RosterWidth: number,
	RosterRowHeight: number,
	ColumnHeaderHeight: number,
	CardSize: Vector2,
	CardGap: number,
	SwatchHeight: number,
	InitialTextSize: number,
	FooterHeight: number,
	LockButtonSize: Vector2,
	-- Whether the footer lists the chosen hero's abilities.
	ShowsAbilities: boolean,
	-- Beside a teammate who hasn't hovered a hero yet.
	ChoosingText: string,
}

type RosterRow = {
	Name: string,
	HeroText: string,
	IsLockedIn: boolean,
	IsLocalPlayer: boolean,
	IsBot: boolean,
}

const REGULAR: Metrics = {
	Padding = 16,
	Gap = 12,
	HeaderHeight = 44,
	TitleTextSize = HudTheme.TitleTextSize,
	BodyTextSize = HudTheme.BodyTextSize,
	SmallTextSize = HudTheme.SmallTextSize,
	RosterWidth = 240,
	RosterRowHeight = 40,
	ColumnHeaderHeight = 24,
	CardSize = Vector2.new(128, 112),
	CardGap = 8,
	SwatchHeight = 72,
	InitialTextSize = 40,
	FooterHeight = 72,
	LockButtonSize = Vector2.new(200, 56),
	ShowsAbilities = true,
	ChoosingText = "Choosing...",
}

-- Sized so a 667 by 375 phone shows it near full size.
const COMPACT: Metrics = {
	Padding = 12,
	Gap = 8,
	HeaderHeight = 32,
	TitleTextSize = 18,
	BodyTextSize = 16,
	SmallTextSize = 14,
	RosterWidth = 140,
	RosterRowHeight = 24,
	ColumnHeaderHeight = 18,
	CardSize = Vector2.new(92, 72),
	CardGap = 6,
	SwatchHeight = 44,
	InitialTextSize = 26,
	FooterHeight = 48,
	LockButtonSize = Vector2.new(150, 44),
	ShowsAbilities = false,
	-- Leaves the narrow roster's width to player names.
	ChoosingText = "...",
}

local function formatSeconds(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function label(properties: { [any]: any }): TextLabel
	local base: { [any]: any } = {
		BackgroundTransparency = 1,
		Font = HudTheme.BodyFont,
		TextColor3 = HudTheme.TextColor,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in properties do
		base[key] = value
	end
	return create("TextLabel")(base)
end

local function heroCard(
	hero: () -> HeroCardView,
	layoutOrder: number,
	metrics: () -> Metrics,
	props: HeroSelectScreenProps
): TextButton
	local isHovered = source(false)

	local function isPickable(): boolean
		return hero().Blocked == nil and not props.IsLockedIn()
	end

	local function isSelected(): boolean
		return props.SelectedHeroId() == hero().Id
	end

	return create("TextButton")({
		Name = "HeroCard",
		LayoutOrder = layoutOrder,
		Size = function()
			local size = metrics().CardSize
			return UDim2.fromOffset(size.X, size.Y)
		end,
		BackgroundColor3 = function()
			return if isHovered() and isPickable() then CARD_HOVER_COLOR else CARD_COLOR
		end,
		Text = "",
		Selectable = isPickable,
		Activated = function()
			if isPickable() then
				props.OnPick(hero().Id)
			end
		end,
		MouseEnter = function()
			isHovered(true)
		end,
		MouseLeave = function()
			isHovered(false)
		end,

		create("UICorner")({ CornerRadius = UDim.new(0, CARD_RADIUS) }),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = function()
				return if isSelected() then HudTheme.StrokeColor else IDLE_STROKE_COLOR
			end,
			Thickness = function()
				return if isSelected() then SELECTED_STROKE_THICKNESS else 1
			end,
		}),
		create("Frame")({
			Name = "Swatch",
			Position = UDim2.fromOffset(SWATCH_INSET, SWATCH_INSET),
			Size = function()
				return UDim2.new(1, -SWATCH_INSET * 2, 0, metrics().SwatchHeight - SWATCH_INSET)
			end,
			BackgroundColor3 = function()
				return hero().Color
			end,

			create("UICorner")({ CornerRadius = UDim.new(0, CARD_RADIUS - SWATCH_INSET) }),
			label({
				Name = "Initial",
				Size = UDim2.fromScale(1, 1),
				Font = HudTheme.Font,
				Text = function()
					return string.sub(hero().Name, 1, 1)
				end,
				TextSize = function()
					return metrics().InitialTextSize
				end,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextStrokeTransparency = 0.4,
			}),
		}),
		label({
			Name = "HeroName",
			Position = function()
				return UDim2.fromOffset(SWATCH_INSET, metrics().SwatchHeight)
			end,
			Size = function()
				local size = metrics().CardSize
				return UDim2.fromOffset(size.X - SWATCH_INSET * 2, size.Y - metrics().SwatchHeight)
			end,
			Font = HudTheme.Font,
			Text = function()
				return hero().Name
			end,
			TextSize = function()
				return metrics().BodyTextSize
			end,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		show(function()
			return hero().Blocked ~= nil
		end, function()
			return create("Frame")({
				Name = "Blocked",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = DIM_COLOR,
				BackgroundTransparency = BLOCKED_TRANSPARENCY,
				ZIndex = 2,

				create("UICorner")({ CornerRadius = UDim.new(0, CARD_RADIUS) }),
				label({
					Name = "Reason",
					Size = UDim2.fromScale(1, 1),
					Font = HudTheme.Font,
					Text = function()
						return hero().Blocked or ""
					end,
					TextSize = function()
						return metrics().BodyTextSize
					end,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
			})
		end),
	})
end

local function roleColumn(
	role: string,
	layoutOrder: number,
	metrics: () -> Metrics,
	props: HeroSelectScreenProps
): Frame
	local heroes = derive(function()
		local inRole = {}
		for _, hero in props.Heroes() do
			if hero.Role == role then
				table.insert(inRole, hero)
			end
		end
		return inRole
	end)

	return create("Frame")({
		Name = `{role}Column`,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = function()
			return UDim2.fromOffset(metrics().CardSize.X, 0)
		end,

		create("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = function()
				return UDim.new(0, metrics().CardGap)
			end,
		}),
		label({
			Name = "RoleName",
			LayoutOrder = 0,
			Size = function()
				return UDim2.new(1, 0, 0, metrics().ColumnHeaderHeight)
			end,
			Font = HudTheme.Font,
			Text = string.upper(role),
			TextColor3 = HudTheme.MutedTextColor,
			TextSize = function()
				return metrics().SmallTextSize
			end,
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
		indexes(heroes, function(hero, index)
			return heroCard(hero, index, metrics, props)
		end),
	})
end

local function rosterRow(
	row: () -> RosterRow,
	layoutOrder: number,
	metrics: () -> Metrics,
	props: HeroSelectScreenProps
): Frame
	return create("Frame")({
		Name = "RosterRow",
		LayoutOrder = layoutOrder,
		Size = function()
			return UDim2.new(1, 0, 0, metrics().RosterRowHeight)
		end,
		BackgroundColor3 = CARD_COLOR,
		BackgroundTransparency = 0.3,

		create("UICorner")({ CornerRadius = UDim.new(0, CARD_RADIUS) }),
		create("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = HudTheme.StrokeColor,
			Enabled = function()
				return row().IsLocalPlayer
			end,
		}),
		create("Frame")({
			Name = "Mark",
			Position = UDim2.fromOffset(0, CARD_RADIUS),
			Size = UDim2.new(0, ROW_MARK_WIDTH, 1, -CARD_RADIUS * 2),
			BackgroundColor3 = function()
				return if row().IsLockedIn
					then HudTheme.TeamColors[props.Team()] or HudTheme.StrokeColor
					else NEUTRAL_MARK_COLOR
			end,
		}),
		create("Frame")({
			Name = "Text",
			Position = UDim2.fromOffset(ROW_MARK_WIDTH + ROW_TEXT_GAP, 0),
			Size = UDim2.new(1, -ROW_MARK_WIDTH - ROW_TEXT_GAP * 2, 1, 0),
			BackgroundTransparency = 1,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, ROW_TEXT_GAP),
			}),
			-- Hero text is short and player names run to 20 characters, so the
			-- name takes whatever width the hero text leaves.
			label({
				Name = "PlayerName",
				LayoutOrder = 1,
				Size = UDim2.fromScale(0, 1),
				Font = HudTheme.Font,
				Text = function()
					return row().Name
				end,
				TextColor3 = function()
					return if row().IsBot then HudTheme.MutedTextColor else HudTheme.TextColor
				end,
				TextSize = function()
					return metrics().SmallTextSize
				end,

				create("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
			}),
			label({
				Name = "HeroName",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = function()
					return row().HeroText
				end,
				TextColor3 = function()
					return if row().IsLockedIn then HudTheme.TextColor else HudTheme.MutedTextColor
				end,
				TextSize = function()
					return metrics().SmallTextSize
				end,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
	})
end

--[[
	Covers the screen before the match while players choose heroes: the
	team's picks on the left, every hero by role, and Lock In with the
	chosen hero's kit beside it.
]]
local function heroSelectScreen(props: HeroSelectScreenProps)
	local metrics = derive(function()
		return if props.IsCompact() then COMPACT else REGULAR
	end)

	local selected = derive(function(): HeroCardView?
		local heroId = props.SelectedHeroId()
		for _, hero in props.Heroes() do
			if hero.Id == heroId then
				return hero
			end
		end
		return nil
	end)

	local rows = derive(function()
		local result: { RosterRow } = {}
		for index = 1, props.TeamSize do
			local teammate = props.Teammates()[index]
			if teammate then
				local heroText = if teammate.HeroName == ""
					then metrics().ChoosingText
					elseif teammate.IsLockedIn then teammate.HeroName
					else `{teammate.HeroName}?`
				table.insert(result, {
					Name = teammate.Name,
					HeroText = heroText,
					IsLockedIn = teammate.IsLockedIn,
					IsLocalPlayer = teammate.IsLocalPlayer,
					IsBot = false,
				})
			else
				table.insert(result, {
					Name = "Bot",
					HeroText = "Random",
					IsLockedIn = false,
					IsLocalPlayer = false,
					IsBot = true,
				})
			end
		end
		return result
	end)

	local function rowCount(): number
		local counts: { [string]: number } = {}
		local most = 1
		for _, hero in props.Heroes() do
			counts[hero.Role] = (counts[hero.Role] or 0) + 1
			most = math.max(most, counts[hero.Role])
		end
		return most
	end

	local function gridWidth(): number
		local view = metrics()
		return #props.Roles * view.CardSize.X + (#props.Roles - 1) * view.CardGap
	end

	local function bodyHeight(): number
		local view = metrics()
		local count = rowCount()
		local grid = view.ColumnHeaderHeight + count * (view.CardSize.Y + view.CardGap)
		local roster = view.ColumnHeaderHeight
			+ props.TeamSize * (view.RosterRowHeight + view.CardGap)
		return math.max(grid, roster)
	end

	local function designSize(): Vector2
		local view = metrics()
		return Vector2.new(
			view.Padding * 2 + view.RosterWidth + view.Gap + gridWidth(),
			view.Padding * 2 + view.HeaderHeight + bodyHeight() + view.FooterHeight + view.Gap * 2
		)
	end

	local function fitScale(): number
		local design = designSize()
		local room = props.MaxSize()
		local fitX = (room.X - EDGE_PADDING * 2) / design.X
		local fitY = (room.Y - EDGE_PADDING * 2) / design.Y
		return math.clamp(math.min(fitX, fitY), MINIMUM_FIT_SCALE, 1) * props.UiScale()
	end

	local function detailsSize(): UDim2
		local view = metrics()
		return UDim2.new(1, -view.LockButtonSize.X - view.Gap, 1, 0)
	end

	local function heroTitleText(): string
		local hero = selected()
		return if hero then `{hero.Name}, {hero.Title}` else "Pick a hero"
	end

	local function heroRoleText(): string
		local hero = selected()
		return if hero
			then `{hero.Role}  ·  {hero.ResourceName}`
			else "Tap a hero to see their role and kit"
	end

	local function abilitiesText(): string
		local hero = selected()
		return if hero then table.concat(hero.Abilities, "  ·  ") else ""
	end

	local function lockLabel(): (string, boolean)
		local hero = selected()
		if props.IsLockedIn() then
			return "Locked in", false
		elseif not hero then
			return "Pick a hero", false
		elseif hero.Blocked then
			return hero.Blocked, false
		end
		return "Lock in", true
	end

	local function lockText(): string
		return (lockLabel())
	end

	local function isLockEnabled(): boolean
		local _, isEnabled = lockLabel()
		return isEnabled
	end

	return show(props.IsOpen, function()
		return create("Frame")({
			Name = "HeroSelect",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = DIM_COLOR,
			BackgroundTransparency = DIM_TRANSPARENCY,
			-- Keeps clicks from reaching the world under the screen.
			Active = true,
			ZIndex = 20,

			create("Frame")({
				Name = "Dock",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				Size = function()
					local size = designSize()
					return UDim2.fromOffset(size.X, size.Y)
				end,

				create("UIScale")({ Scale = fitScale }),
				create("Frame")({
					Name = "Panel",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = HudTheme.PanelColor,
					BackgroundTransparency = HudTheme.PanelTransparency,

					create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
					create("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = HudTheme.StrokeColor,
						Thickness = 2,
					}),
					create("UIPadding")({
						PaddingLeft = function()
							return UDim.new(0, metrics().Padding)
						end,
						PaddingRight = function()
							return UDim.new(0, metrics().Padding)
						end,
						PaddingTop = function()
							return UDim.new(0, metrics().Padding)
						end,
						PaddingBottom = function()
							return UDim.new(0, metrics().Padding)
						end,
					}),
					create("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = function()
							return UDim.new(0, metrics().Gap)
						end,
					}),

					create("Frame")({
						Name = "Header",
						LayoutOrder = 1,
						BackgroundTransparency = 1,
						Size = function()
							return UDim2.new(1, 0, 0, metrics().HeaderHeight)
						end,

						label({
							Name = "Title",
							Size = UDim2.fromScale(0.5, 1),
							Font = HudTheme.Font,
							Text = "Choose your hero",
							TextSize = function()
								return metrics().TitleTextSize
							end,
						}),
						label({
							Name = "Timer",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromScale(0.5, 1),
							Font = HudTheme.Font,
							Text = function()
								local secondsLeft = props.SecondsLeft()
								if secondsLeft then
									return `Match starts in {formatSeconds(secondsLeft)}`
								end
								return "Waiting for players to load"
							end,
							TextColor3 = HudTheme.MutedTextColor,
							TextSize = function()
								return metrics().BodyTextSize
							end,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),
					}),

					create("Frame")({
						Name = "Body",
						LayoutOrder = 2,
						BackgroundTransparency = 1,
						Size = function()
							return UDim2.new(1, 0, 0, bodyHeight())
						end,

						create("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = function()
								return UDim.new(0, metrics().Gap)
							end,
						}),
						create("Frame")({
							Name = "Roster",
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							Size = function()
								return UDim2.new(0, metrics().RosterWidth, 1, 0)
							end,

							create("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = function()
									return UDim.new(0, metrics().CardGap)
								end,
							}),
							label({
								Name = "TeamName",
								LayoutOrder = 0,
								Size = function()
									return UDim2.new(1, 0, 0, metrics().ColumnHeaderHeight)
								end,
								Font = HudTheme.Font,
								Text = function()
									return string.upper(`{props.Team()} team`)
								end,
								TextColor3 = function()
									return HudTheme.TeamColors[props.Team()] or HudTheme.TextColor
								end,
								TextSize = function()
									return metrics().SmallTextSize
								end,
							}),
							indexes(rows, function(row, index)
								return rosterRow(row, index, metrics, props)
							end),
						}),
						create("Frame")({
							Name = "Grid",
							LayoutOrder = 2,
							BackgroundTransparency = 1,
							Size = function()
								return UDim2.new(0, gridWidth(), 1, 0)
							end,

							create("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = function()
									return UDim.new(0, metrics().CardGap)
								end,
							}),
							indexes(function()
								return props.Roles
							end, function(role, index)
								return roleColumn(role(), index, metrics, props)
							end),
						}),
					}),

					create("Frame")({
						Name = "Footer",
						LayoutOrder = 3,
						BackgroundTransparency = 1,
						Size = function()
							return UDim2.new(1, 0, 0, metrics().FooterHeight)
						end,

						create("Frame")({
							Name = "Details",
							BackgroundTransparency = 1,
							Size = detailsSize,

							create("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							label({
								Name = "HeroTitle",
								LayoutOrder = 1,
								Size = function()
									return UDim2.new(1, 0, 0, metrics().TitleTextSize + 4)
								end,
								Font = HudTheme.Font,
								Text = heroTitleText,
								TextSize = function()
									return metrics().TitleTextSize
								end,
							}),
							label({
								Name = "HeroRole",
								LayoutOrder = 2,
								Size = function()
									return UDim2.new(1, 0, 0, metrics().SmallTextSize + 4)
								end,
								Text = heroRoleText,
								TextColor3 = HudTheme.MutedTextColor,
								TextSize = function()
									return metrics().SmallTextSize
								end,
							}),
							show(function()
								return metrics().ShowsAbilities
							end, function()
								return label({
									Name = "HeroAbilities",
									LayoutOrder = 3,
									Size = function()
										return UDim2.new(1, 0, 0, metrics().SmallTextSize + 4)
									end,
									Text = abilitiesText,
									TextColor3 = HudTheme.MutedTextColor,
									TextSize = function()
										return metrics().SmallTextSize
									end,
								})
							end),
						}),
						create("TextButton")({
							Name = "LockIn",
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = function()
								local size = metrics().LockButtonSize
								return UDim2.fromOffset(size.X, size.Y)
							end,
							BackgroundColor3 = function()
								return if isLockEnabled() then LOCK_COLOR else DISABLED_COLOR
							end,
							Font = HudTheme.Font,
							Text = lockText,
							TextSize = function()
								return metrics().TitleTextSize
							end,
							TextColor3 = function()
								return if isLockEnabled()
									then HudTheme.TextColor
									else HudTheme.MutedTextColor
							end,
							Activated = function()
								if isLockEnabled() then
									props.OnLockIn()
								end
							end,

							create("UICorner")({ CornerRadius = HudTheme.PanelCorner }),
						}),
					}),
				}),
			}),
		})
	end)
end

return heroSelectScreen
