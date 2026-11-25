--!strict

const TweenService = game:GetService("TweenService")

-- Built from plain instances: the loading screen runs from ReplicatedFirst,
-- before ReplicatedStorage and its packages reach the client.
const GAME_TITLE = "CRASHPOINT VALLEY"
const SUBTITLE = "5v5 Battle Arena"

const TOP_COLOR = Color3.fromRGB(14, 10, 30)
const BOTTOM_COLOR = Color3.fromRGB(44, 26, 70)
const GOLD_COLOR = Color3.fromRGB(240, 200, 110)
const TEXT_COLOR = Color3.fromRGB(240, 236, 250)
const MUTED_TEXT_COLOR = Color3.fromRGB(176, 164, 205)
const BAR_BACKGROUND_COLOR = Color3.fromRGB(10, 8, 22)

-- Seconds the bar takes to glide to a new value.
const PROGRESS_TWEEN_SECONDS = 0.35

export type LoadingView = typeof(setmetatable(
	{} :: {
		_Root: Frame,
		_Fill: Frame,
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
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(TOP_COLOR, BOTTOM_COLOR)
	gradient.Rotation = 90
	gradient.Parent = root

	local title = makeLabel("Title", Enum.Font.Fondamento, 96, GOLD_COLOR)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.4)
	title.Size = UDim2.fromScale(0.86, 0.16)
	title.Text = GAME_TITLE
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(70, 40, 10)
	titleStroke.Thickness = 2
	titleStroke.Parent = title
	title.Parent = root

	local subtitle = makeLabel("Subtitle", Enum.Font.GothamMedium, 28, MUTED_TEXT_COLOR)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.49)
	subtitle.Size = UDim2.fromScale(0.6, 0.045)
	subtitle.Text = SUBTITLE
	subtitle.Parent = root

	local status = makeLabel("Status", Enum.Font.GothamBold, 22, TEXT_COLOR)
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.new(0.5, 0, 0.8, -10)
	status.Size = UDim2.fromScale(0.6, 0.035)
	status.Parent = root

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.BackgroundColor3 = BAR_BACKGROUND_COLOR
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromScale(0.5, 0.8)
	bar.Size = UDim2.new(0.5, 0, 0, 10)
	addCorner(bar, UDim.new(1, 0))
	local barSize = Instance.new("UISizeConstraint")
	barSize.MinSize = Vector2.new(240, 0)
	barSize.MaxSize = Vector2.new(640, math.huge)
	barSize.Parent = bar
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = GOLD_COLOR
	barStroke.Transparency = 0.6
	barStroke.Parent = bar
	bar.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = GOLD_COLOR
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	addCorner(fill, UDim.new(1, 0))
	fill.Parent = bar

	local tip = makeLabel("Tip", Enum.Font.GothamMedium, 20, MUTED_TEXT_COLOR)
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.new(0.5, 0, 0.8, 26)
	tip.Size = UDim2.fromScale(0.8, 0.06)
	tip.Parent = root

	root.Parent = parent

	return setmetatable({
		_Root = root,
		_Fill = fill,
		_Status = status,
		_Tip = tip,
	}, LoadingViewMethods)
end

--[[
	Glides the bar to the given fill, from 0 to 1.
]]
function LoadingViewMethods.SetProgress(self: LoadingView, alpha: number)
	local tweenInfo = TweenInfo.new(PROGRESS_TWEEN_SECONDS, Enum.EasingStyle.Quad)
	TweenService:Create(self._Fill, tweenInfo, {
		Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1),
	}):Play()
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
