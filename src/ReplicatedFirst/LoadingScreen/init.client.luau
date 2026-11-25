--!strict

const ContentProvider = game:GetService("ContentProvider")
const Players = game:GetService("Players")
const ReplicatedFirst = game:GetService("ReplicatedFirst")

const LoadingView = require("@self/LoadingView")

-- Set on the local player by the client Start script once every system has
-- started.
const LOADED_ATTRIBUTE = "IsClientLoaded"
-- Shown at least this long, so a fast load doesn't flash the screen.
const MIN_SHOW_SECONDS = 2
-- Fades out after this long whatever is left, so a stuck load never traps
-- the player behind the screen.
const MAX_SHOW_SECONDS = 45
const FADE_SECONDS = 0.6
const TIP_SECONDS = 5
-- How long a stage's bar takes to creep most of the way to its cap.
const CREEP_SECONDS = 6
const TIPS = {
	"Right-click the ground to move, or tap where you want to go.",
	"Press B to recall to your fountain, where you heal and shop.",
	"Stand in brush to hide from enemies outside it.",
	"Press T to place a Sensor Ward and watch over the area around it.",
	"Land the last hit on enemy minions to earn their gold.",
	"Each team fields one hero per role: Top, Jungle, Mid, Bot, and Support.",
	"Bring down the enemy core to win the match.",
}

type Stage = {
	Status: string,
	-- Fill the bar reaches while the stage waits.
	Cap: number,
	IsDone: () -> boolean,
}

const STAGES: { Stage } = {
	{
		Status = "Joining the server",
		Cap = 0.3,
		IsDone = function()
			return game:IsLoaded()
		end,
	},
	{
		Status = "Gathering assets",
		Cap = 0.6,
		IsDone = function()
			return ContentProvider.RequestQueueSize == 0
		end,
	},
	{
		Status = "Building the valley",
		Cap = 0.95,
		IsDone = function()
			return Players.LocalPlayer:GetAttribute(LOADED_ATTRIBUTE) == true
		end,
	},
}

const playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
const screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
-- Above every other screen, the hero select included.
screenGui.DisplayOrder = 1000
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

const view = LoadingView.new(screenGui)
const shownAt = os.clock()

local tipIndex = math.random(#TIPS)
view:SetTip(TIPS[tipIndex])
task.spawn(function()
	while screenGui.Parent do
		task.wait(TIP_SECONDS)
		tipIndex = tipIndex % #TIPS + 1
		view:SetTip(TIPS[tipIndex])
	end
end)

local function hasTimedOut(): boolean
	return os.clock() - shownAt > MAX_SHOW_SECONDS
end

local progress = 0
for _, stage in STAGES do
	view:SetStatus(stage.Status)
	local stageStart = os.clock()
	local stageFrom = progress
	while not stage.IsDone() and not hasTimedOut() do
		-- Eases toward the cap without reaching it, so the bar keeps moving.
		local creep = 1 - math.exp(-(os.clock() - stageStart) * 3 / CREEP_SECONDS)
		progress = stageFrom + (stage.Cap - stageFrom) * creep
		view:SetProgress(progress)
		task.wait(0.1)
	end
	progress = stage.Cap
	view:SetProgress(progress)
end

view:SetStatus("Ready")
view:SetProgress(1)
task.wait(math.max(0.4, MIN_SHOW_SECONDS - (os.clock() - shownAt)))
view:FadeOut(FADE_SECONDS)
task.wait(FADE_SECONDS)
screenGui:Destroy()
