--!strict
-- Computer opponent. It watches each shot coming its way, walks toward where the ball will
-- arrive and swings at a planned moment with some timing error. It is fooled by abilities the
-- way a person would be (a curve is read late, Phantom and Blind make timing worse) and uses its
-- own abilities when they make sense. Pure logic: the caller passes in a random function so tests
-- can be deterministic.

local Config = require(script.Parent.Config)
local Trajectory = require(script.Parent.Trajectory)
local Abilities = require(script.Parent.Abilities)

export type Profile = {
	label: string,
	timingBias: number, -- seconds added to every swing (positive = late)
	timingSd: number, -- spread of the timing error
	missChance: number, -- chance per ball of not swinging at all
	moveSpeed: number, -- studs per second across the table
	aimSpread: number, -- 0 = always aims at the middle, 1 = uses the full width
	useChance: number, -- chance of using an ability when there is a chance to
	immune: boolean?, -- the practice wall is not fooled by abilities
}

-- How much each trick hurts a bot's read of the ball.
local CONFUSION = {
	phantomMiss = 0.015,
	phantomSd = 1.05,
	blindSd = 1.5,
	zigzagSd = 1.45, -- the swing makes the arrival hard to read early
	stallSd = 1.9, -- the stop throws the timing off
	meteorSd = 1.15,
}

local Bot = {}
Bot.__index = Bot

Bot.Profiles = {
	-- Practice wall: always returns a steady Good ball near the middle.
	Wall = {
		label = "壁打ち",
		timingBias = 0.1,
		timingSd = 0,
		missChance = 0,
		moveSpeed = 60,
		aimSpread = 0.25,
		useChance = 0,
		immune = true,
	} :: Profile,
	Easy = {
		label = "やさしい",
		timingBias = 0,
		timingSd = 0.11,
		missChance = 0.1,
		moveSpeed = 9,
		aimSpread = 0.4,
		useChance = 0.3,
	} :: Profile,
	Normal = {
		label = "ふつう",
		timingBias = 0,
		timingSd = 0.07,
		missChance = 0.04,
		moveSpeed = 12,
		aimSpread = 0.7,
		useChance = 0.5,
	} :: Profile,
	Hard = {
		label = "つよい",
		timingBias = 0,
		timingSd = 0.04,
		missChance = 0.015,
		moveSpeed = 15,
		aimSpread = 0.95,
		useChance = 0.7,
	} :: Profile,
}

export type RandomFn = (min: number, max: number) -> number

-- What the bot can see when deciding whether to use an ability.
export type Situation = {
	now: number,
	gauge: number,
	used: boolean, -- already used an ability this rally
	armed: string?,
	barrier: boolean,
	receiving: boolean, -- the ball is coming to the bot
	shot: Trajectory.Shot?,
}

export type Bot = typeof(setmetatable(
	{} :: {
		profile: Profile,
		random: RandomFn,
		side: number,
		loadout: { string },
		z: number,
		targetZ: number,
		trueZ: number,
		revealAt: number?, -- a curve: when the bot works out where it really goes
		swingAt: number?,
		aimZ: number,
		shot: Trajectory.Shot?,
		thoughtAbout: Trajectory.Shot?,
		eager: boolean, -- rolled once per shot: willing to spend gauge on a tight ball
		slowUntil: number,
		slowFactor: number,
		jammedUntil: number?, -- EMP
	},
	Bot
))

function Bot.new(profileName: string, side: number, random: RandomFn, loadout: { string }?): Bot
	local profile = (Bot.Profiles :: any)[profileName] :: Profile
	assert(profile, "unknown bot profile: " .. tostring(profileName))
	return setmetatable({
		profile = profile,
		random = random,
		side = side,
		loadout = loadout or {},
		z = 0,
		targetZ = 0,
		trueZ = 0,
		revealAt = nil :: number?,
		swingAt = nil :: number?,
		aimZ = 0,
		shot = nil :: Trajectory.Shot?,
		thoughtAbout = nil :: Trajectory.Shot?,
		eager = false,
		slowUntil = 0,
		slowFactor = 1,
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

-- Tell the bot about a new shot (or an updated one, after Time Slow).
-- It plans a swing only for balls coming to its side.
function Bot.watch(self: Bot, shot: Trajectory.Shot?)
	self.shot = shot
	self.swingAt = nil
	self.revealAt = nil
	if shot == nil or shot.hitterSide == self.side then
		self.targetZ = 0
		return
	end
	local p = self.profile
	local fx = shot.effects
	local sd, miss = p.timingSd, p.missChance
	self.trueZ = shot.to.Z
	self.targetZ = shot.to.Z
	if not p.immune then
		if fx.curve then
			-- it first looks like the ball keeps going the way it is bending
			self.targetZ = shot.to.Z + fx.curve * 1.2
			self.revealAt = Trajectory.timeAtProgress(shot, Abilities.Tuning.Curve.revealAt)
		end
		if fx.phantom then
			miss += CONFUSION.phantomMiss
			sd *= CONFUSION.phantomSd
		end
		if fx.blind then
			sd *= CONFUSION.blindSd
		end
		if fx.zigzag then
			sd *= CONFUSION.zigzagSd
		end
		if fx.stallStart then
			sd *= CONFUSION.stallSd
		end
		if fx.meteor then
			sd *= CONFUSION.meteorSd
		end
		if self.jammedUntil and shot.startTime < self.jammedUntil then
			sd *= Abilities.Tuning.EMP.timingSd
		end
	end
	if self.random(0, 1) < miss then
		return
	end
	self.swingAt = Trajectory.arrivalTime(shot) + p.timingBias + gaussian(self.random) * sd
	self.aimZ = self:pickAim()
end

-- Gravity Well on the bot.
-- EMP: the bot's "screen" is jammed until then, so it times balls worse.
function Bot.jam(self: Bot, untilTime: number)
	self.jammedUntil = untilTime
end

function Bot.slow(self: Bot, untilTime: number, factor: number)
	self.slowUntil = untilTime
	self.slowFactor = factor
end

-- Blink: jump across the table toward where the ball is going.
function Bot.blink(self: Bot, dirZ: number, distance: number)
	local limit = Config.Table.halfWidth + 3
	self.z = math.clamp(self.z + dirZ * distance, -limit, limit)
end

function Bot.speed(self: Bot, now: number): number
	return self.profile.moveSpeed * (if now < self.slowUntil then self.slowFactor else 1)
end

-- Can the bot still get to the ball in time? margin < 1 asks "comfortably", not just barely.
local function canReach(self: Bot, now: number, margin: number?): boolean
	local shot = self.shot
	if not shot or self.revealAt then
		return true -- has not worked out the curve yet
	end
	local left = math.max(Trajectory.arrivalTime(shot) - now, 0)
	local k = margin or 1
	return math.abs(self.trueZ - self.z) <= self:speed(now) * left * k + Config.Reach * 0.8
end

-- Decide whether to use an ability now. Returns the loadout slot to use (and a direction for
-- Blink), or nil. Chance-based uses are rolled once per shot so the bot does not spam; uses that
-- answer a problem (the ball is out of reach) are checked every step.
function Bot.think(self: Bot, s: Situation): (number?, number?)
	if s.used or #self.loadout == 0 or s.shot == nil then
		return nil, nil
	end
	local firstLook = self.thoughtAbout ~= s.shot
	self.thoughtAbout = s.shot
	local chance = self.profile.useChance
	if firstLook then
		self.eager = self.random(0, 1) < chance
	end
	local order = {}
	for i = 1, #self.loadout do
		table.insert(order, math.floor(self.random(0, 1) * (#order + 1)) + 1, i)
	end
	for _, slot in order do
		local id = self.loadout[slot]
		local def = Abilities.get(id)
		if def and s.gauge >= def.cost then
			local roll = if firstLook then self.random(0, 1) else 1
			if def.kind == "shot" then
				if s.receiving and s.armed == nil and roll < chance then
					return slot, nil
				end
			elseif id == "TimeSlow" then
				local fast = s.shot and (s.shot.effects.smash or s.shot.kind == "Perfect")
				if s.receiving and s.shot and ((fast and roll < chance) or not canReach(self, s.now)) then
					return slot, nil
				end
			elseif id == "Blink" then
				-- a long way to go: jump instead of running (only once the bot knows where it goes)
				local far = self.revealAt == nil and math.abs(self.trueZ - self.z) > 2.2
				local tight = self.eager and (far or not canReach(self, s.now, 0.5))
				if s.receiving and (tight or not canReach(self, s.now)) then
					return slot, if self.trueZ > self.z then 1 else -1
				end
			elseif id == "Barrier" then
				-- raise it against a dangerous ball, or one the bot cannot reach
				local fx = s.shot.effects
				local danger = fx.ability ~= nil or s.shot.kind == "Perfect"
				if s.receiving and not s.barrier and ((danger and roll < chance) or not canReach(self, s.now)) then
					return slot, nil
				end
			elseif id == "GravityWell" or id == "EMP" then
				if not s.receiving and s.shot and roll < chance then
					return slot, nil
				end
			end
		end
	end
	return nil, nil
end

-- Advance the bot. Returns the swing time when it swings this step, otherwise nil.
function Bot.step(self: Bot, dt: number, now: number): number?
	if self.revealAt and now >= self.revealAt then
		self.targetZ = self.trueZ
		self.revealAt = nil
	end
	local delta = self.targetZ - self.z
	local move = self:speed(now) * dt
	self.z += math.clamp(delta, -move, move)
	local at = self.swingAt
	if at and now >= at then
		self.swingAt = nil
		return at
	end
	return nil
end

return Bot
