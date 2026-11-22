--!strict
-- The ball does not use Roblox physics. Each shot is a fixed path decided at the moment of contact:
-- two parabolic legs (paddle -> bounce on the table -> the other paddle) over a known duration.
-- Server and clients evaluate the same path against the shared server clock, so everyone sees the
-- same ball and the server knows exactly when it will reach each paddle.

local Config = require(script.Parent.Config)

local Trajectory = {}

export type Shot = {
	from: Vector3,
	bounce: Vector3,
	to: Vector3,
	arc1: number,
	arc2: number,
	startTime: number,
	duration: number,
	bounceFraction: number,
	kind: string, -- "Serve" | "Perfect" | "Good" | "Weak"
	hitterSide: number, -- -1 or 1: who hit it
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local BALL_REST_Y = Config.Table.surfaceY + Config.Ball.radius

-- Height of the first leg where it crosses the net (X = 0).
function Trajectory.heightOverNet(shot: Shot): number
	local u = (0 - shot.from.X) / (shot.bounce.X - shot.from.X)
	return lerp(shot.from.Y, BALL_REST_Y, u) + shot.arc1 * 4 * u * (1 - u)
end

-- Builds a shot from the hitter's contact point toward the opponent.
-- aimZ is where across the table (Z) the ball should arrive at the opponent's paddle;
-- it is clamped so the bounce stays on the table.
function Trajectory.plan(from: Vector3, hitterSide: number, aimZ: number, kind: string, startTime: number): Shot
	local style = (Config.Shots :: any)[kind] :: Config.ShotStyle
	assert(style, "unknown shot kind: " .. tostring(kind))
	local dir = -hitterSide -- the ball travels toward the other side
	local limit = Config.Table.halfWidth - Config.AimMargin
	local toZ = math.clamp(aimZ, -limit, limit)
	local fraction = Config.BounceFraction
	local bounceX = dir * Config.Table.halfLength * style.depth
	local bounceZ = math.clamp(lerp(from.Z, toZ, fraction), -limit, limit)

	local shot: Shot = {
		from = from,
		bounce = Vector3.new(bounceX, BALL_REST_Y, bounceZ),
		to = Vector3.new(dir * Config.HitX, Config.HitY, toZ),
		arc1 = style.arc1,
		arc2 = style.arc2,
		startTime = startTime,
		duration = style.duration,
		bounceFraction = fraction,
		kind = kind,
		hitterSide = hitterSide,
	}

	-- Raise the first arc until the ball clears the net.
	local needed = Config.Table.surfaceY + Config.Table.netHeight + Config.Ball.radius + Config.NetClearance
	local over = Trajectory.heightOverNet(shot)
	if over < needed then
		local u = (0 - shot.from.X) / (shot.bounce.X - shot.from.X)
		shot.arc1 += (needed - over) / (4 * u * (1 - u))
	end
	return shot
end

-- Position along the path for progress s in [0, 1].
function Trajectory.positionAtProgress(shot: Shot, s: number): Vector3
	s = math.clamp(s, 0, 1)
	local b = shot.bounceFraction
	if s < b then
		local u = s / b
		local base = shot.from:Lerp(shot.bounce, u)
		return Vector3.new(base.X, base.Y + shot.arc1 * 4 * u * (1 - u), base.Z)
	end
	local u = (s - b) / (1 - b)
	local base = shot.bounce:Lerp(shot.to, u)
	return Vector3.new(base.X, base.Y + shot.arc2 * 4 * u * (1 - u), base.Z)
end

function Trajectory.progressAt(shot: Shot, time: number): number
	return (time - shot.startTime) / shot.duration
end

function Trajectory.positionAt(shot: Shot, time: number): Vector3
	return Trajectory.positionAtProgress(shot, Trajectory.progressAt(shot, time))
end

-- When the ball reaches the receiver's paddle.
function Trajectory.arrivalTime(shot: Shot): number
	return shot.startTime + shot.duration
end

function Trajectory.bounceTime(shot: Shot): number
	return shot.startTime + shot.duration * shot.bounceFraction
end

-- Average speed in studs per second, used by clients to colour the trail.
function Trajectory.speed(shot: Shot): number
	return ((shot.bounce - shot.from).Magnitude + (shot.to - shot.bounce).Magnitude) / shot.duration
end

return Trajectory
