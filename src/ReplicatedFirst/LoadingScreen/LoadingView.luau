--!strict

const TweenService = game:GetService("TweenService")

-- Built from plain instances: the loading screen runs from ReplicatedFirst,
-- before ReplicatedStorage and its packages reach the client.
const GAME_TITLE = "CRASHPOINT VALLEY"
const CHIP_TEXT = "Loading..."

const TOP_COLOR = Color3.fromRGB(6, 14, 16)
const BOTTOM_COLOR = Color3.fromRGB(18, 34, 28)
const GLOW_COLOR = Color3.fromRGB(70, 150, 110)
const PANEL_COLOR = Color3.fromRGB(12, 24, 28)
const PANEL_TRANSPARENCY = 0.15
const GOLD_COLOR = Color3.fromRGB(240, 200, 110)
const DARK_GOLD_COLOR = Color3.fromRGB(170, 120, 40)
const TEXT_COLOR = Color3.fromRGB(240, 230, 210)
const MUTED_TEXT_COLOR = Color3.fromRGB(176, 168, 145)
const BAR_BACKGROUND_COLOR = Color3.fromRGB(4, 10, 12)

-- Width over height. The panel stays between the two widths, in pixels.
const PANEL_ASPECT = 2.3
const MAX_PANEL_WIDTH = 760
const MIN_PANEL_WIDTH = 300
const INNER_FRAME_INSET = 8
const GEM_SIZE = 12
const CORNERS = {
	Vector2.new(0, 0),
	Vector2.new(1, 0),
	Vector2.new(0, 1),
	Vector2.new(1, 1),
}

-- Seconds the bar takes to glide to a new value.
const PROGRESS_TWEEN_SECONDS = 0.35

export type LoadingView = typeof(setmetatable(
	{} :: {
		_Root: Frame,
		_Fill: Frame,
		_Percent: TextLabel,
		_Status: TextLabel,
		_Tip: TextLabel,
	},
	{} :: LoadingViewMethods
))

type LoadingViewMethods = {
	__index: LoadingViewMethods,
	SetProgress: (self: LoadingView, alpha: number) -> (),
	SetStatus: (self: LoadingView, text: string) -> (),
	SetTip: (self: LoadingView, text: string) -> (),
	FadeOut: (self: LoadingView, seconds: number) -> (),
	Destroy: (self: LoadingView) -> (),
}

const LoadingViewMethods = {} :: LoadingViewMethods
LoadingViewMethods.__index = LoadingViewMethods

local Module = {}

local function addCorner(parent: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function addStroke(parent: GuiObject, color: Color3, thickness: number, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = parent
end

local function makeLabel(
	name: string,
	font: Enum.Font,
	maxTextSize: number,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxTextSize
	constraint.Parent = label
	return label
end

local function makeGem(parent: GuiObject, corner: Vector2)
	local gem = Instance.new("Frame")
	gem.Name = "Gem"
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(corner.X, corner.Y)
	gem.Size = UDim2.fromOffset(GEM_SIZE, GEM_SIZE)
	gem.Rotation = 45
	gem.BackgroundColor3 = GOLD_COLOR
	gem.BorderSizePixel = 0
	gem.ZIndex = 3
	addStroke(gem, DARK_GOLD_COLOR, 1, 0)
	gem.Parent = parent
end

local function makeBackdrop(root: Frame)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(TOP_COLOR, BOTTOM_COLOR)
	gradient.Rotation = 90
	gradient.Parent = root

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.55)
	glow.Size = UDim2.fromScale(0.9, 0.8)
	glow.BackgroundColor3 = GLOW_COLOR
	glow.BackgroundTransparency = 0.82
	glow.BorderSizePixel = 0
	addCorner(glow, UDim.new(0.5, 0))
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = glow
	glow.Parent = root
end

local function makeTipBox(panel: Frame): TextLabel
	local box = Instance.new("Frame")
	box.Name = "TipBox"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.fromScale(0.5, 0.6)
	box.Size = UDim2.fromScale(0.66, 0.26)
	box.BackgroundColor3 = BAR_BACKGROUND_COLOR
	box.BackgroundTransparency = 0.25
	box.BorderSizePixel = 0
	addCorner(box, UDim.new(0, 3))
	addStroke(box, GOLD_COLOR, 1, 0.45)
	for _, corner in CORNERS do
		local notch = Instance.new("Frame")
		notch.Name = "Notch"
		notch.AnchorPoint = corner
		notch.Position = UDim2.fromScale(corner.X, corner.Y)
		notch.Size = UDim2.fromOffset(8, 8)
		notch.BackgroundColor3 = GOLD_COLOR
		notch.BorderSizePixel = 0
		notch.Parent = box
	end

	local heading = makeLabel("Heading", Enum.Font.GothamBold, 14, GOLD_COLOR)
	heading.Position = UDim2.fromScale(0.05, 0.1)
	heading.Size = UDim2.fromScale(0.9, 0.28)
	heading.Text = "TIP"
	heading.Parent = box

	local tip = makeLabel("Tip", Enum.Font.GothamMedium, 18, TEXT_COLOR)
	tip.Position = UDim2.fromScale(0.05, 0.4)
	tip.Size = UDim2.fromScale(0.9, 0.5)
	tip.Parent = box

	box.Parent = panel
	return tip
end

--[[
	Builds the loading screen inside the parent, filling it.
]]
function Module.new(parent: Instance): LoadingView
	local root = Instance.new("Frame")
	root.Name = "LoadingScreen"
	root.BackgroundColor3 = Color3.new(1, 1, 1)
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	-- Swallows clicks, so nothing underneath reacts while loading.
	root.Active = true
	makeBackdrop(root)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.58)
	panel.Size = UDim2.fromScale(0.62, 1)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = PANEL_TRANSPARENCY
	panel.BorderSizePixel = 0
	addCorner(panel, UDim.new(0, 3))
	addStroke(panel, GOLD_COLOR, 2, 0.1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = PANEL_ASPECT
	aspect.Parent = panel
	local panelSize = Instance.new("UISizeConstraint")
	panelSize.MinSize = Vector2.new(MIN_PANEL_WIDTH, 0)
	panelSize.MaxSize = Vector2.new(MAX_PANEL_WIDTH, math.huge)
	panelSize.Parent = panel
	panel.Parent = root

	local innerFrame = Instance.new("Frame")
	innerFrame.Name = "InnerFrame"
	innerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	innerFrame.Position = UDim2.fromScale(0.5, 0.5)
	innerFrame.Size = UDim2.new(1, -INNER_FRAME_INSET * 2, 1, -INNER_FRAME_INSET * 2)
	innerFrame.BackgroundTransparency = 1
	addCorner(innerFrame, UDim.new(0, 2))
	addStroke(innerFrame, GOLD_COLOR, 1, 0.65)
	innerFrame.Parent = panel
	for _, corner in CORNERS do
		makeGem(panel, corner)
	end

	local title = makeLabel("Title", Enum.Font.Fondamento, 80, GOLD_COLOR)
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 0, -34)
	title.Size = UDim2.fromScale(1.2, 0.32)
	title.Text = GAME_TITLE
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(70, 40, 10)
	titleStroke.Thickness = 2
	titleStroke.Parent = title
	title.Parent = panel

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.fromScale(0.5, 0)
	chip.Size = UDim2.fromScale(0.26, 0.15)
	chip.BackgroundColor3 = PANEL_COLOR
	chip.BorderSizePixel = 0
	chip.ZIndex = 2
	addCorner(chip, UDim.new(0, 3))
	addStroke(chip, GOLD_COLOR, 2, 0.1)
	local chipText = makeLabel("Text", Enum.Font.Fondamento, 30, GOLD_COLOR)
	chipText.Size = UDim2.fromScale(1, 1)
	chipText.Text = CHIP_TEXT
	chipText.ZIndex = 2
	chipText.Parent = chip
	chip.Parent = panel

	local status = makeLabel("Status", Enum.Font.GothamMedium, 18, MUTED_TEXT_COLOR)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.fromScale(0.5, 0.18)
	status.Size = UDim2.fromScale(0.8, 0.1)
	status.Parent = panel

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0.1, 0.4)
	bar.Size = UDim2.fromScale(0.68, 0.065)
	bar.BackgroundColor3 = BAR_BACKGROUND_COLOR
	bar.BorderSizePixel = 0
	addCorner(bar, UDim.new(1, 0))
	addStroke(bar, GOLD_COLOR, 1, 0.5)
	bar.Parent = panel

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	addCorner(fill, UDim.new(1, 0))
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(DARK_GOLD_COLOR, GOLD_COLOR)
	fillGradient.Parent = fill
	local fillGlow = Instance.new("UIStroke")
	fillGlow.Color = GOLD_COLOR
	fillGlow.Thickness = 3
	fillGlow.Transparency = 0.7
	fillGlow.Parent = fill
	fill.Parent = bar

	local percent = makeLabel("Percent", Enum.Font.GothamBold, 30, GOLD_COLOR)
	percent.AnchorPoint = Vector2.new(0, 0.5)
	percent.Position = UDim2.fromScale(0.8, 0.4)
	percent.Size = UDim2.fromScale(0.12, 0.16)
	percent.TextXAlignment = Enum.TextXAlignment.Left
	percent.Text = "0%"
	percent.Parent = panel

	const tip = makeTipBox(panel)

	root.Parent = parent

	return setmetatable({
		_Root = root,
		_Fill = fill,
		_Percent = percent,
		_Status = status,
		_Tip = tip,
	}, LoadingViewMethods)
end

--[[
	Glides the bar to the given fill, from 0 to 1, and shows it as a percent.
]]
function LoadingViewMethods.SetProgress(self: LoadingView, alpha: number)
	local clamped = math.clamp(alpha, 0, 1)
	local tweenInfo = TweenInfo.new(PROGRESS_TWEEN_SECONDS, Enum.EasingStyle.Quad)
	TweenService:Create(self._Fill, tweenInfo, {
		Size = UDim2.fromScale(clamped, 1),
	}):Play()
	self._Percent.Text = `{math.floor(clamped * 100)}%`
end

function LoadingViewMethods.SetStatus(self: LoadingView, text: string)
	self._Status.Text = text
end

function LoadingViewMethods.SetTip(self: LoadingView, text: string)
	self._Tip.Text = text
end

--[[
	Fades every part of the screen out over the given seconds. Each element
	fades on its own instead of through a CanvasGroup, which can draw blank
	at low graphics quality.
]]
function LoadingViewMethods.FadeOut(self: LoadingView, seconds: number)
	local tweenInfo = TweenInfo.new(seconds, Enum.EasingStyle.Quad)
	local instances: { Instance } = self._Root:GetDescendants()
	table.insert(instances, self._Root)
	for _, instance in instances do
		local goal: { [string]: number } = {}
		if instance:IsA("GuiObject") then
			goal.BackgroundTransparency = 1
		end
		if instance:IsA("TextLabel") then
			goal.TextTransparency = 1
		end
		if instance:IsA("UIStroke") then
			goal.Transparency = 1
		end
		if next(goal) then
			TweenService:Create(instance, tweenInfo, goal):Play()
		end
	end
end

function LoadingViewMethods.Destroy(self: LoadingView)
	self._Root:Destroy()
end

return Module
