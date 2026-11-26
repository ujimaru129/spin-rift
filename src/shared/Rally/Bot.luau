--!strict
-- Computer opponent. It watches each shot coming its way, walks toward where the ball will
-- arrive and swings at a planned moment with some timing error. It is fooled by abilities the
-- way a person would be (a curve is read late, Phantom and Blind make timing worse). Its own
-- abilities fire by themselves, the same as a player's (see Match.autoUse). Pure logic: the caller passes in a random function so tests
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
	reaction: number, -- seconds after the opponent's hit before the bot starts moving
	aimSpread: number, -- 0 = always aims at the middle, 1 = uses the full width
	immune: boolean?, -- the practice wall is not fooled by abilities
}

-- How much each trick hurts a bot's read of the ball.
local CONFUSION = {
	phantomMiss = 0.015,
	phantomSd = 1.05,
	blindSd = 1.5,
	zigzagSd = 1.45, -- the swing makes the arrival hard to read early (for a 1.6-stud swing)
	stallSd = 1.9, -- the stop throws the timing off (for a 0.4 s stop; a shorter one, less)
	meteorSd = 1.15,
	feintLead = 1, -- how much of the feint the bot believes before it reads the cut
	feintRead = 0.25, -- share of the second leg gone before it reads the cut
	kickSd = 1.15, -- the late, fast second leg throws the timing off
}

local Bot = {}
Bot.__index = Bot

Bot.Profiles = {
	-- Practice wall: always returns a steady Good ball near the middle.
	Wall = {
		label = "壁打ち",
		timingBias = 0.07, -- inside the Good window even when a long rally has narrowed it
		timingSd = 0,
		missChance = 0,
		moveSpeed = 60,
		reaction = 0,
		aimSpread = 0.25,
		immune = true,
	} :: Profile,
	Easy = {
		label = "やさしい",
		timingBias = 0,
		timingSd = 0.11,
		missChance = 0.1,
		moveSpeed = 9,
		reaction = 0.4,
		aimSpread = 0.4,
	} :: Profile,
	Normal = {
		label = "ふつう",
		timingBias = 0,
		timingSd = 0.07,
		missChance = 0.04,
		moveSpeed = 12,
		reaction = 0.28,
		aimSpread = 0.7,
	} :: Profile,
	Hard = {
		label = "つよい",
		timingBias = 0,
		timingSd = 0.04,
		missChance = 0.015,
		moveSpeed = 15,
		reaction = 0.2,
		aimSpread = 0.95,
	} :: Profile,
}

export type RandomFn = (min: number, max: number) -> number

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
		moveAt: number, -- does not start moving toward the ball before this time (reaction)
		aimZ: number,
		shot: Trajectory.Shot?,
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
		moveAt = 0,
		aimZ = 0,
		shot = nil :: Trajectory.Shot?,
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
	return self.random(-1, 1) * Config.BotMaxAim * self.profile.aimSpread
end

-- Tell the bot about a new shot (or an updated one, after Time Slow).
-- It plans a swing only for balls coming to its side.
function Bot.watch(self: Bot, shot: Trajectory.Shot?)
	self.shot = shot
	self.swingAt = nil
	self.revealAt = nil
	if shot == nil or shot.hitterSide == self.side then
		self.targetZ = 0
		self.moveAt = 0
		return
	end
	local p = self.profile
	self.moveAt = shot.startTime + p.reaction
	local fx = shot.effects
	-- a faster ball is harder to time, the same way it is for a person
	local sd, miss = p.timingSd / (1 - (shot.pace or 0)), p.missChance
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
			sd *= 1 + (CONFUSION.zigzagSd - 1) * math.clamp(fx.zigzag / 1.6, 0, 1.5)
		end
		if fx.stallStart and fx.stallEnd then
			local share = math.clamp((fx.stallEnd - fx.stallStart) / 0.4, 0, 1.5)
			sd *= 1 + (CONFUSION.stallSd - 1) * share
		end
		if fx.meteor then
			sd *= CONFUSION.meteorSd
		end
		if fx.feint then
			-- it believes the ball is going the wrong way until it bounces
			self.targetZ = shot.to.Z + fx.feint * 2 * CONFUSION.feintLead
			local b = shot.bounceFraction
			self.revealAt = Trajectory.timeAtProgress(shot, b + (1 - b) * CONFUSION.feintRead)
		end
		if fx.kick then
			sd *= CONFUSION.kickSd
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

-- Advance the bot. Returns the swing time when it swings this step, otherwise nil.
function Bot.step(self: Bot, dt: number, now: number): number?
	if self.revealAt and now >= self.revealAt then
		self.targetZ = self.trueZ
		self.revealAt = nil
	end
	local delta = if now >= self.moveAt then self.targetZ - self.z else 0
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
