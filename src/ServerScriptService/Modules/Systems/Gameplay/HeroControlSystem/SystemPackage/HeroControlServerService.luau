--!strict

const Players = game:GetService("Players")

const UnitServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitServerService"
)

const HeroControlNetwork = require("./HeroControlNetwork")

-- Commands a client may send per second on average, and in one burst.
-- Holding the move button sends about seven a second.
const COMMANDS_PER_SECOND = 20
const COMMAND_BURST = 30
-- Unit ids travel as unsigned 16-bit values.
const MAX_UNIT_ID = 65535

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Unit = UnitTypes.Unit

type Bucket = {
	Tokens: number,
	LastTime: number,
}

local Module = {}

local boundsHalfSize = math.huge
local buckets: { [Player]: Bucket? } = {}

local function takeToken(player: Player): boolean
	local now = os.clock()
	local bucket: Bucket = buckets[player] or { Tokens = COMMAND_BURST, LastTime = now }
	buckets[player] = bucket

	bucket.Tokens =
		math.min(bucket.Tokens + (now - bucket.LastTime) * COMMANDS_PER_SECOND, COMMAND_BURST)
	bucket.LastTime = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function getControllableHero(player: Player): Unit?
	local hero = UnitServerService:FindOwnedHero(player)
	if not hero or hero.IsDead then
		return nil
	end
	return hero
end

local function onMoveCommand(player: Player, x: unknown, z: unknown)
	-- x ~= x catches NaN, and the huge checks catch infinity; both would
	-- pass the clamp below.
	if
		typeof(x) ~= "number"
		or typeof(z) ~= "number"
		or x ~= x
		or z ~= z
		or math.abs(x) == math.huge
		or math.abs(z) == math.huge
	then
		return
	end
	if not takeToken(player) then
		return
	end

	local hero = getControllableHero(player)
	if not hero then
		return
	end

	local target = Vector3.new(
		math.clamp(x, -boundsHalfSize, boundsHalfSize),
		0,
		math.clamp(z, -boundsHalfSize, boundsHalfSize)
	)
	UnitServerService:IssueOrder(hero, { Kind = "Move", Target = target })
end

local function onAttackCommand(player: Player, targetId: unknown)
	if
		typeof(targetId) ~= "number"
		or targetId ~= math.floor(targetId)
		or targetId < 1
		or targetId > MAX_UNIT_ID
	then
		return
	end
	if not takeToken(player) then
		return
	end

	local hero = getControllableHero(player)
	local target = UnitServerService:GetUnit(targetId)
	if not hero or not target or not UnitServerService:CanAttack(hero, target) then
		return
	end
	UnitServerService:IssueOrder(hero, { Kind = "Attack", TargetId = targetId })
end

local function onStopCommand(player: Player)
	if not takeToken(player) then
		return
	end

	local hero = getControllableHero(player)
	if hero then
		UnitServerService:IssueOrder(hero, { Kind = "Idle" })
	end
end

local function onPlayerRemoving(player: Player)
	buckets[player] = nil
end

--[[
	Sets how far from the center, in studs, a move command may aim. Points
	past it are pulled back to the edge.
]]
function Module:SetBounds(halfSize: number)
	boundsHalfSize = halfSize
end

function Module:Init()
	HeroControlNetwork.MoveCommand.OnServerEvent:Connect(onMoveCommand)
	HeroControlNetwork.AttackCommand.OnServerEvent:Connect(onAttackCommand)
	HeroControlNetwork.StopCommand.OnServerEvent:Connect(onStopCommand)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Module
