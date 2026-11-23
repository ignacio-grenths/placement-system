--!strict

local Module = {
	-- Client to server: (x, z), a point on the ground to walk to.
	MoveCommand = script.MoveCommand,
	-- Client to server: (unit id), an enemy to attack.
	AttackCommand = script.AttackCommand,
	-- Client to server: no arguments; the hero stops where it is.
	StopCommand = script.StopCommand,
}

return Module
