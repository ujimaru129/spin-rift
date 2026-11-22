--!strict
-- The ball does not use Roblox physics. Each shot is a fixed path decided at the moment of contact:
-- two parabolic legs (paddle -> bounce on the table -> the other paddle) over a known duration.
-- Server and clients evaluate the same path against the shared server clock, so everyone sees the
-- same ball and the server knows exactly when it will reach each paddle.
--
-- Abilities change a shot through `effects`: a sideways curve, a faster flatter Smash, Phantom
-- copies and Blind (drawn by clients), and a Time Slow window that stretches part of the flight.

local Config = require(script.Parent.Config)
local Abilities = require(script.Parent.Abilities)

local Trajectory = {}

export type Effects = {
	ability: string?, -- the shot ability that made this shot, if any
	curve: number?, -- sideways bend in studs at mid-flight
	smash: boolean?, -- timing windows are scaled by Abilities.Tuning.Smash.window
	phantom: boolean?,
	blind: boolean?,
	slowStart: number?, -- server time the Time Slow window starts
	slowEnd: number?,
	slowFactor: number?,
}

export type Shot = {
	from: Vector3,
	bounce: Vector3,
	to: Vector3,
	arc1: number,
	arc2: number,
	startTime: number,
	duration: number, -- flight time without any slow-down
	bounceFraction: number,
	kind: string, -- "Serve" | "Perfect" | "Good" | "Weak"
	hitterSide: number, -- -1 or 1: who hit it
	effects: Effects,
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

local function curveOffset(shot: Shot, s: number): number
	local c = shot.effects.curve
	return if c then c * math.sin(math.pi * s) else 0
end

-- Builds a shot from the hitter's contact point toward the opponent.
-- aimZ is where across the table (Z) the ball should arrive at the opponent's paddle;
-- it is clamped so the bounce stays on the table. ability = a shot ability to apply.
function Trajectory.plan(
	from: Vector3,
	hitterSide: number,
	aimZ: number,
	kind: string,
	startTime: number,
	ability: string?
): Shot
	local style = (Config.Shots :: any)[kind] :: Config.ShotStyle
	assert(style, "unknown shot kind: " .. tostring(kind))
	local dir = -hitterSide -- the ball travels toward the other side
	local limit = Config.Table.halfWidth - Config.AimMargin
	local toZ = math.clamp(aimZ, -limit, limit)
	local fraction = Config.BounceFraction
	local bounceX = dir * Config.Table.halfLength * style.depth
	local bounceZ = math.clamp(lerp(from.Z, toZ, fraction), -limit, limit)

	local duration, arc1, arc2 = style.duration, style.arc1, style.arc2
	local effects: Effects = { ability = ability }
	if ability == "Smash" then
		local t = Abilities.Tuning.Smash
		duration /= t.speed
		arc1 *= t.arc
		arc2 *= t.arc
		effects.smash = true
	elseif ability == "Phantom" then
		effects.phantom = true
	elseif ability == "Blind" then
		effects.blind = true
	end

	local shot: Shot = {
		from = from,
		bounce = Vector3.new(bounceX, BALL_REST_Y, bounceZ),
		to = Vector3.new(dir * Config.HitX, Config.HitY, toZ),
		arc1 = arc1,
		arc2 = arc2,
		startTime = startTime,
		duration = duration,
		bounceFraction = fraction,
		kind = kind,
		hitterSide = hitterSide,
		effects = effects,
	}

	if ability == "Curve" then
		-- Bend toward the middle-and-beyond so it first looks like it goes the other way,
		-- and shrink the bend if the bounce would leave the table.
		local sign = if toZ > 0 then -1 elseif toZ < 0 then 1 else (if from.Z > 0 then 1 else -1)
		local amount = Abilities.Tuning.Curve.amount
		local edge = Config.Table.halfWidth - 0.4
		local bend = math.sin(math.pi * fraction)
		while amount > 0.2 and math.abs(bounceZ + sign * amount * bend) > edge do
			amount *= 0.8
		end
		effects.curve = sign * amount
	end

	-- Raise the first arc until the ball clears the net.
	local needed = Config.Table.surfaceY + Config.Table.netHeight + Config.Ball.radius + Config.NetClearance
	local over = Trajectory.heightOverNet(shot)
	if over < needed then
		local u = (0 - shot.from.X) / (shot.bounce.X - shot.from.X)
		shot.arc1 += (needed - over) / (4 * u * (1 - u))
	end
	return shot
end

-- A copy of the shot that runs at `factor` speed from `startAt` for `length` seconds (Time Slow).
function Trajectory.withSlow(shot: Shot, startAt: number, length: number, factor: number): Shot
	local copy = table.clone(shot)
	copy.effects = table.clone(shot.effects)
	copy.effects.slowStart = startAt
	copy.effects.slowEnd = startAt + length
	copy.effects.slowFactor = factor
	return copy
end

-- Seconds of flight "used up" by server time t, after any slow-down.
local function flightTimeAt(shot: Shot, t: number): number
	local elapsed = t - shot.startTime
	local fx = shot.effects
	local a, b, f = fx.slowStart, fx.slowEnd, fx.slowFactor
	if a and b and f then
		local inside = math.clamp(t, a, b) - a
		elapsed -= inside * (1 - f)
	end
	return elapsed
end

-- Server time at which the ball has used up `flight` seconds of its flight.
local function timeForFlight(shot: Shot, flight: number): number
	local fx = shot.effects
	local a, b, f = fx.slowStart, fx.slowEnd, fx.slowFactor
	local plain = shot.startTime + flight
	if not (a and b and f) or plain <= a then
		return plain
	end
	local beforeSlow = a - shot.startTime
	local left = flight - beforeSlow
	local slowFlight = (b - a) * f
	if left <= slowFlight then
		return a + left / f
	end
	return b + (left - slowFlight)
end

-- Position along the path for progress s in [0, 1].
function Trajectory.positionAtProgress(shot: Shot, s: number): Vector3
	s = math.clamp(s, 0, 1)
	local b = shot.bounceFraction
	local p: Vector3
	if s < b then
		local u = s / b
		local base = shot.from:Lerp(shot.bounce, u)
		p = Vector3.new(base.X, base.Y + shot.arc1 * 4 * u * (1 - u), base.Z)
	else
		local u = (s - b) / (1 - b)
		local base = shot.bounce:Lerp(shot.to, u)
		p = Vector3.new(base.X, base.Y + shot.arc2 * 4 * u * (1 - u), base.Z)
	end
	return Vector3.new(p.X, p.Y, p.Z + curveOffset(shot, s))
end

function Trajectory.progressAt(shot: Shot, time: number): number
	return flightTimeAt(shot, time) / shot.duration
end

function Trajectory.timeAtProgress(shot: Shot, s: number): number
	return timeForFlight(shot, s * shot.duration)
end

function Trajectory.positionAt(shot: Shot, time: number): Vector3
	return Trajectory.positionAtProgress(shot, Trajectory.progressAt(shot, time))
end

-- When the ball reaches the receiver's paddle.
function Trajectory.arrivalTime(shot: Shot): number
	return Trajectory.timeAtProgress(shot, 1)
end

function Trajectory.bounceTime(shot: Shot): number
	return Trajectory.timeAtProgress(shot, shot.bounceFraction)
end

-- Where the ball actually lands on the table (with any curve).
function Trajectory.bouncePoint(shot: Shot): Vector3
	return Trajectory.positionAtProgress(shot, shot.bounceFraction)
end

-- How the receiver's timing windows are scaled for this shot: narrower against a Lightning Smash,
-- wider against a weak ball (much wider against the barrier's return) and a slowed ball.
function Trajectory.windowScale(shot: Shot): number
	local fx = shot.effects
	local k = 1
	if fx.smash then
		k = Abilities.Tuning.Smash.window
	elseif fx.ability == "BarrierReturn" then
		k = Abilities.Tuning.Barrier.returnWindow
	elseif shot.kind == "Weak" then
		k = Config.WeakBallWindow
	end
	if fx.slowFactor then
		k *= Abilities.Tuning.TimeSlow.window
	end
	return k
end

-- Average speed in studs per second, used by clients to colour the trail.
function Trajectory.speed(shot: Shot): number
	return ((shot.bounce - shot.from).Magnitude + (shot.to - shot.bounce).Magnitude) / shot.duration
end

return Trajectory
