--!strict
-- Computer opponent. It watches each shot coming its way, walks toward where the ball will
-- arrive and swings at a planned moment with some timing error. Pure logic: the caller passes in
-- a random function so tests can be deterministic.

local Config = require(script.Parent.Config)
local Trajectory = require(script.Parent.Trajectory)

export type Profile = {
	label: string,
	timingBias: number, -- seconds added to every swing (positive = late)
	timingSd: number, -- spread of the timing error
	missChance: number, -- chance per ball of not swinging at all
	moveSpeed: number, -- studs per second across the table
	aimSpread: number, -- 0 = always aims at the middle, 1 = uses the full width
}

local Bot = {}
Bot.__index = Bot

Bot.Profiles = {
	-- Practice wall: always returns a steady Good ball near the middle.
	Wall = { label = "壁打ち", timingBias = 0.1, timingSd = 0, missChance = 0, moveSpeed = 60, aimSpread = 0.25 } :: Profile,
	Easy = { label = "やさしい", timingBias = 0, timingSd = 0.11, missChance = 0.1, moveSpeed = 9, aimSpread = 0.4 } :: Profile,
	Normal = {
		label = "ふつう",
		timingBias = 0,
		timingSd = 0.07,
		missChance = 0.04,
		moveSpeed = 12,
		aimSpread = 0.7,
	} :: Profile,
	Hard = {
		label = "つよい",
		timingBias = 0,
		timingSd = 0.04,
		missChance = 0.015,
		moveSpeed = 15,
		aimSpread = 0.95,
	} :: Profile,
}

export type RandomFn = (min: number, max: number) -> number

export type Bot = typeof(setmetatable(
	{} :: {
		profile: Profile,
		random: RandomFn,
		side: number,
		z: number,
		targetZ: number,
		swingAt: number?,
		aimZ: number,
		shot: Trajectory.Shot?,
	},
	Bot
))

function Bot.new(profileName: string, side: number, random: RandomFn): Bot
	local profile = (Bot.Profiles :: any)[profileName] :: Profile
	assert(profile, "unknown bot profile: " .. tostring(profileName))
	return setmetatable({
		profile = profile,
		random = random,
		side = side,
		z = 0,
		targetZ = 0,
		swingAt = nil :: number?,
		aimZ = 0,
		shot = nil :: Trajectory.Shot?,
	}, Bot)
end

local function gaussian(random: RandomFn): number
	local u1 = math.max(random(0, 1), 1e-9)
	local u2 = random(0, 1)
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

function Bot.pickAim(self: Bot): number
	local limit = Config.Table.halfWidth - Config.AimMargin
	return self.random(-1, 1) * limit * self.profile.aimSpread
end

-- Tell the bot about a new shot. It plans a swing only for balls coming to its side.
function Bot.watch(self: Bot, shot: Trajectory.Shot?)
	self.shot = shot
	self.swingAt = nil
	if shot == nil or shot.hitterSide == self.side then
		self.targetZ = 0
		return
	end
	self.targetZ = shot.to.Z
	if self.random(0, 1) < self.profile.missChance then
		return
	end
	local p = self.profile
	self.swingAt = Trajectory.arrivalTime(shot) + p.timingBias + gaussian(self.random) * p.timingSd
	self.aimZ = self:pickAim()
end

-- Advance the bot. Returns the swing time when it swings this step, otherwise nil.
function Bot.step(self: Bot, dt: number, now: number): number?
	local delta = self.targetZ - self.z
	local move = self.profile.moveSpeed * dt
	self.z += math.clamp(delta, -move, move)
	local at = self.swingAt
	if at and now >= at then
		self.swingAt = nil
		return at
	end
	return nil
end

return Bot
