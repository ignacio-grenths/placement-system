--!strict

const GuiService = game:GetService("GuiService")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const Vide = require("@game/ReplicatedStorage/Packages/vide")

const batch = Vide.batch
const source = Vide.source

-- UI is authored for a screen this many pixels on its short side.
const REFERENCE_SHORT_SIDE = 1080
const MINIMUM_SCALE = 1
const MAXIMUM_SCALE = 3
-- A TV is read from a couch, so its UI gets a quarter more.
const LARGE_DISPLAY_BOOST = 1.25
-- A short side under this many UI units is a phone held sideways.
const PHONE_SHORT_SIDE = 600
const FALLBACK_VIEWPORT = Vector2.new(1920, 1080)

export type SimulatedScreen = {
	Size: Vector2,
	Inset: Vector2?,
	IsTouch: boolean?,
	IsGamepad: boolean?,
	IsLargeDisplay: boolean?,
}

local Module = {}

local realViewport = source(FALLBACK_VIEWPORT)
local realInset = source(Vector2.zero)
local prefersTouch = source(false)
local prefersGamepad = source(false)
local isLargeDisplay = source(false)
local isSimulating = false
local viewportConnection: RBXScriptConnection? = nil

local function refresh()
	if isSimulating then
		return
	end

	local camera = workspace.CurrentCamera
	local topLeftInset = GuiService:GetGuiInset()
	-- One batch, so a device switch reruns each binding once, with every fact
	-- already updated.
	batch(function()
		-- ViewportSize can read (1, 1) before the first frame, which would pass
		-- for a tiny phone, so the fallback stays until a real size arrives.
		if camera and camera.ViewportSize.X > 1 and camera.ViewportSize.Y > 1 then
			realViewport(camera.ViewportSize)
		end
		realInset(topLeftInset)
		prefersTouch(UserInputService.PreferredInput == Enum.PreferredInput.Touch)
		prefersGamepad(UserInputService.PreferredInput == Enum.PreferredInput.Gamepad)
		isLargeDisplay(GuiService.ViewportDisplaySize == Enum.DisplaySize.Large)
	end)
end

local function watchCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	refresh()
end

--[[
	How much the whole UI grows on this screen. Bind it to a UIScale under
	every ScreenGui the game builds.
]]
function Module.uiScale(): number
	local view = realViewport()
	local boost = if isLargeDisplay() then LARGE_DISPLAY_BOOST else 1
	return math.clamp(
		math.min(view.X, view.Y) / REFERENCE_SHORT_SIDE * boost,
		MINIMUM_SCALE,
		MAXIMUM_SCALE
	)
end

--[[
	The viewport in UI units.
]]
function Module.viewport(): Vector2
	return realViewport() / Module.uiScale()
end

--[[
	The part of the viewport below the Roblox topbar, in UI units.
]]
function Module.usableSize(): Vector2
	local view = Module.viewport()
	return Vector2.new(view.X, view.Y - realInset().Y / Module.uiScale())
end

--[[
	Whether touch is the primary input.
]]
function Module.isTouch(): boolean
	return prefersTouch()
end

--[[
	Whether a gamepad is the primary input, so prompts show its buttons.
]]
function Module.isGamepad(): boolean
	return prefersGamepad()
end

function Module.isPhone(): boolean
	local view = Module.viewport()
	return math.min(view.X, view.Y) < PHONE_SHORT_SIDE
end

--[[
	Whether a HUD should use its touch layout: touch is the primary input, or
	the screen is too small for the desktop layout.
]]
function Module.isTouchLayout(): boolean
	return prefersTouch() or Module.isPhone()
end

--[[
	Replaces the live readings with the given screen, for a story or a spec.
	Pass nil to go back to them.
]]
function Module:Simulate(screen: SimulatedScreen?)
	isSimulating = screen ~= nil
	if not screen then
		refresh()
		return
	end

	batch(function()
		realViewport(screen.Size)
		realInset(screen.Inset or Vector2.zero)
		prefersTouch(screen.IsTouch == true)
		prefersGamepad(screen.IsGamepad == true)
		isLargeDisplay(screen.IsLargeDisplay == true)
	end)
end

-- Stories and specs load a fresh copy of this module on every reload, and a
-- connection would keep each copy alive, so edit mode reads the screen once.
if RunService:IsRunning() then
	watchCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refresh)
	GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(refresh)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
else
	refresh()
end

return Module
