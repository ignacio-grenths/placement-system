--!strict

const StructureServerService = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/StructureSystem/SystemPackage/StructureServerService"
)

const MinionWaveServerService = require("../SystemPackage/MinionWaveServerService")

const UnitTypes = require(
	"@game/ServerScriptService/Modules/Systems/Gameplay/Combat/UnitSystem/SystemPackage/UnitTypes"
)

type Team = UnitTypes.Team

local Module = {}

local function getOpponent(team: Team): Team?
	if team == "Blue" then
		return "Red"
	elseif team == "Red" then
		return "Blue"
	end
	return nil
end

local function onGateDestroyed(losingTeam: Team, laneName: string)
	-- Annotated because luau-lsp widens a returned string literal to string.
	local attackingTeam: Team? = getOpponent(losingTeam)
	if attackingTeam then
		MinionWaveServerService:SetSuperLane(attackingTeam, laneName, true)
	end
end

local function onGateRebuilt(owningTeam: Team, laneName: string)
	local attackingTeam: Team? = getOpponent(owningTeam)
	if attackingTeam then
		MinionWaveServerService:SetSuperLane(attackingTeam, laneName, false)
	end
end

function Module:Init()
	StructureServerService.GateDestroyed:Connect(onGateDestroyed)
	StructureServerService.GateRebuilt:Connect(onGateRebuilt)
end

return Module
