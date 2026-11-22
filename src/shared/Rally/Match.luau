--!strict
-- One match between two players: serve, rally, points, games, the Rift gauge and abilities.
-- Pure logic with no Instances. The caller passes in the time (server clock) on every call and
-- forwards the returned events to clients. Player 1 stands on side -1, player 2 on side 1.

local Config = require(script.Parent.Config)
local Judge = require(script.Parent.Judge)
local Trajectory = require(script.Parent.Trajectory)
local Abilities = require(script.Parent.Abilities)

export type Event = { [string]: any }
export type Phase = "Paused" | "Rally" | "Over"

local Match = {}
Match.__index = Match

export type Match = typeof(setmetatable(
	{} :: {
		phase: Phase,
		points: { number },
		games: { number },
		gauge: { number },
		server: number,
		servesDone: number,
		firstServerOfGame: number,
		nextServeAt: number,
		shot: Trajectory.Shot?,
		receiver: number,
		rally: number,
		winner: number?,
		loadouts: { { string } },
		armed: { [number]: string? }, -- shot ability waiting for the player's next return
		usedThisRally: { boolean },
		barrier: { boolean },
		slowedUntil: { number }, -- Gravity Well: server time each player's movement is slowed until
		whiffed: Trajectory.Shot?, -- a barrier-protected miss: no second swing at the same ball
		windAt: ((time: number) -> number)?, -- arena wind (casual Sakura Float), nil for none
		idle: { number }, -- points each player has lost in a row without doing anything
		idleLimit: number?, -- that many idle points in a row loses the match (nil = no limit)
	},
	Match
))

function Match.sideOf(index: number): number
	return if index == 1 then -1 else 1
end

function Match.other(index: number): number
	return if index == 1 then 2 else 1
end

-- idleLimit: a player who lets this many balls go by in a row without swinging, serving by
-- hand or using an ability loses the match (reason "idle"). For player-vs-player matches,
-- so two players who both walk away cannot keep a deuce going forever.
export type Options = { windAt: ((time: number) -> number)?, idleLimit: number? }

function Match.new(now: number, firstServer: number?, loadouts: { { string } }?, options: Options?): Match
	local first = firstServer or 1
	local l = loadouts or { {}, {} }
	return setmetatable({
		phase = "Paused" :: Phase,
		points = { 0, 0 },
		games = { 0, 0 },
		gauge = { 0, 0 },
		server = first,
		servesDone = 0,
		firstServerOfGame = first,
		nextServeAt = now + Config.GamePause,
		shot = nil :: Trajectory.Shot?,
		receiver = Match.other(first),
		rally = 0,
		winner = nil :: number?,
		loadouts = { l[1] or {}, l[2] or {} },
		armed = {},
		usedThisRally = { false, false },
		barrier = { false, false },
		slowedUntil = { 0, 0 },
		whiffed = nil :: Trajectory.Shot?,
		windAt = if options then options.windAt else nil,
		idle = { 0, 0 },
		idleLimit = if options then options.idleLimit else nil,
	}, Match)
end

function Match.snapshot(self: Match): Event
	return {
		kind = "Score",
		points = table.clone(self.points),
		games = table.clone(self.games),
		gauge = table.clone(self.gauge),
		server = self.server,
		barrier = table.clone(self.barrier),
	}
end

function Match.canServe(self: Match, now: number): boolean
	return self.phase == "Paused" and now >= self.nextServeAt
end

-- The current server puts the ball in play. fromZ = where across the table they stand.
-- auto = the server put it in for a player who did not serve in time (not player activity).
function Match.serve(self: Match, now: number, fromZ: number, aimZ: number, auto: boolean?): { Event }
	if not self:canServe(now) then
		return {}
	end
	if not auto then
		self.idle[self.server] = 0
	end
	local side = Match.sideOf(self.server)
	local from = Vector3.new(side * Config.HitX, Config.HitY, fromZ)
	local shot = Trajectory.plan(from, side, aimZ, "Serve", now, nil, self:wind(now))
	self.shot = shot
	self.receiver = Match.other(self.server)
	self.rally = 0
	self.phase = "Rally"
	return { { kind = "Shot", shot = shot } }
end

local function deuce(self: Match): boolean
	return self.points[1] >= Config.Score.deuceAt and self.points[2] >= Config.Score.deuceAt
end

function Match._award(self: Match, winner: number, reason: string, now: number): { Event }
	local events: { Event } = {}
	self.points[winner] += 1
	self.shot = nil
	self.armed = {}
	self.usedThisRally = { false, false }
	self.barrier = { false, false } -- a barrier lasts for the rally it was raised in
	table.insert(events, { kind = "Point", winner = winner, reason = reason })

	local p, q = self.points[winner], self.points[Match.other(winner)]
	if p >= Config.Score.pointsToWinGame and p - q >= Config.Score.winBy then
		self.games[winner] += 1
		table.insert(events, { kind = "Game", winner = winner, games = table.clone(self.games) })
		if self.games[winner] >= Config.Score.gamesToWinMatch then
			self.phase = "Over"
			self.winner = winner
			table.insert(events, {
				kind = "MatchOver",
				winner = winner,
				games = table.clone(self.games),
				points = table.clone(self.points),
			})
			table.insert(events, self:snapshot())
			return events
		end
		self.points = { 0, 0 }
		self.firstServerOfGame = Match.other(self.firstServerOfGame)
		self.server = self.firstServerOfGame
		self.servesDone = 0
		self.nextServeAt = now + Config.GamePause
	else
		self.servesDone += 1
		local perTurn = if deuce(self) then 1 else Config.Score.servesPerTurn
		if self.servesDone >= perTurn then
			self.server = Match.other(self.server)
			self.servesDone = 0
		end
		self.nextServeAt = now + Config.PointPause
	end
	self.phase = "Paused"
	table.insert(events, self:snapshot())
	return events
end

-- `index` returns the current ball at `time` with the given grade. Applies an armed shot ability.
function Match._returnBall(self: Match, index: number, time: number, grade: string, aimZ: number): { Event }
	local shot = self.shot :: Trajectory.Shot
	local events: { Event } = {}
	if self.barrier[index] and grade ~= "Barrier" then
		-- returned it without help: the barrier was only for this ball
		self.barrier[index] = false
		table.insert(events, { kind = "Ability", player = index, id = "Barrier", state = "expired" })
	end
	self.gauge[index] = math.min(Config.Gauge.max, self.gauge[index] + Judge.gaugeFor(grade :: any))
	local ability: string? = nil
	local armed = self.armed[index]
	if armed then
		local def = Abilities.get(armed)
		self.armed[index] = nil
		if def and self.gauge[index] >= def.cost and not self.usedThisRally[index] then
			ability = armed
			self.gauge[index] -= def.cost
			self.usedThisRally[index] = true
			table.insert(
				events,
				{ kind = "Ability", player = index, id = armed, state = "fired", gauge = self.gauge[index] }
			)
		else
			table.insert(events, { kind = "Ability", player = index, id = armed, state = "fizzled" })
		end
	end
	self.rally += 1
	local side = Match.sideOf(index)
	local from = Vector3.new(side * Config.HitX, Config.HitY, shot.to.Z)
	local kind = if grade == "Barrier" then "Weak" else grade
	if grade == "Barrier" then
		ability = "BarrierReturn"
	end
	local nextShot = Trajectory.plan(from, side, aimZ, kind, time, ability, self:wind(time))
	self.shot = nextShot
	self.receiver = Match.other(index)
	table.insert(events, 1, {
		kind = "Swing",
		player = index,
		grade = grade,
		offset = time - Trajectory.arrivalTime(shot),
		reached = true,
		rally = self.rally,
		gauge = self.gauge[index],
	})
	table.insert(events, { kind = "Shot", shot = nextShot })
	return events
end

-- A player swings. time = trusted swing time, playerZ = where they stood across the table.
-- Swings by the wrong player, or far too early, are ignored and return no events.
function Match.swing(self: Match, index: number, time: number, aimZ: number, playerZ: number): { Event }
	local shot = self.shot
	if self.phase ~= "Rally" or shot == nil or index ~= self.receiver or self.whiffed == shot then
		return {}
	end
	local offset = time - Trajectory.arrivalTime(shot)
	if offset < -Config.IgnoreEarlierThan then
		return {}
	end
	self.idle[index] = 0
	local grade = Judge.grade(offset, Trajectory.windowScale(shot))
	local reached = Judge.inReach(shot.to.Z, playerZ)
	if grade == "Miss" or not reached then
		local miss: Event = { kind = "Swing", player = index, grade = "Miss", offset = offset, reached = reached }
		if self.barrier[index] then
			-- the barrier will return it when the ball arrives
			miss.protected = true
			self.whiffed = shot
			return { miss }
		end
		local events: { Event } = { miss }
		for _, e in self:_award(Match.other(index), if reached then "whiff" else "reach", time) do
			table.insert(events, e)
		end
		return events
	end
	return self:_returnBall(index, time, grade, aimZ)
end

local function deny(index: number, id: string, reason: string): { Event }
	return { { kind = "AbilityDenied", player = index, id = id, reason = reason } }
end

-- A player uses the ability in loadout slot `slot`. dirZ is the direction they are moving (Blink).
function Match.useAbility(self: Match, index: number, slot: number, now: number, dirZ: number?): { Event }
	local id = self.loadouts[index][slot]
	local def = if id then Abilities.get(id) else nil
	if not id or not def then
		return {}
	end
	self.idle[index] = 0
	-- shot abilities may also be armed between points (they fire on your next return), so you
	-- can get ready while the ball is not in play; the others only work during a rally
	local between = self.phase == "Paused" and def.kind == "shot"
	if self.phase ~= "Rally" and not between then
		return deny(index, id, "notRally")
	end
	if self.usedThisRally[index] then
		return deny(index, id, "used")
	end
	if self.gauge[index] < def.cost then
		return deny(index, id, "gauge")
	end
	if def.kind == "shot" then
		if self.armed[index] == id then
			self.armed[index] = nil
			return { { kind = "Ability", player = index, id = id, state = "disarmed" } }
		end
		self.armed[index] = id
		return { { kind = "Ability", player = index, id = id, state = "armed" } }
	end

	local events: { Event } = {}
	local used: Event = { kind = "Ability", player = index, id = id, state = "used" }
	if id == "TimeSlow" then
		local shot = self.shot
		if not shot or self.receiver ~= index or now >= Trajectory.arrivalTime(shot) then
			return deny(index, id, "noBall")
		end
		local t = Abilities.Tuning.TimeSlow
		local slowed = Trajectory.withSlow(shot, now, t.length, t.factor)
		self.shot = slowed
		table.insert(events, { kind = "Shot", shot = slowed, update = true })
	elseif id == "Barrier" then
		local shot = self.shot
		if not shot or self.receiver ~= index or now >= Trajectory.arrivalTime(shot) then
			return deny(index, id, "noBall")
		end
		if self.barrier[index] then
			return deny(index, id, "active")
		end
		self.barrier[index] = true
	elseif id == "GravityWell" then
		local target = Match.other(index)
		local t = Abilities.Tuning.GravityWell
		self.slowedUntil[target] = now + t.length
		used.target = target
		used.untilTime = now + t.length
		used.factor = t.factor
	elseif id == "Blink" then
		local d = dirZ or 0
		used.dirZ = if d > 0 then 1 elseif d < 0 then -1 else 0
		used.distance = Abilities.Tuning.Blink.distance
	end
	self.gauge[index] -= def.cost
	self.usedThisRally[index] = true
	used.gauge = self.gauge[index]
	table.insert(events, 1, used)
	return events
end

-- Arena wind right now (0 when the arena has none).
function Match.wind(self: Match, time: number): number
	local f = self.windAt
	return if f then f(time) else 0
end

-- Movement speed multiplier for a player right now (Gravity Well).
function Match.moveFactor(self: Match, index: number, now: number): number
	return if now < self.slowedUntil[index] then Abilities.Tuning.GravityWell.factor else 1
end

-- Call every frame. Fires the Rift Barrier when the ball reaches a protected player, and awards
-- the point when the receiver lets the ball go past.
function Match.update(self: Match, now: number): { Event }
	local shot = self.shot
	if self.phase ~= "Rally" or not shot then
		return {}
	end
	local arrival = Trajectory.arrivalTime(shot)
	local r = self.receiver
	if self.barrier[r] and now >= arrival then
		self.barrier[r] = false
		local events: { Event } = { { kind = "Ability", player = r, id = "Barrier", state = "triggered" } }
		for _, e in self:_returnBall(r, arrival, "Barrier", 0) do
			table.insert(events, e)
		end
		return events
	end
	if now > arrival + Config.Timing.weak + Config.MissGrace then
		self.idle[r] += 1
		local limit = self.idleLimit
		if limit and self.idle[r] >= limit then
			return self:_end(Match.other(r), "idle")
		end
		return self:_award(Match.other(r), "miss", now)
	end
	return {}
end

-- Ends the match early: `winner` wins with the full number of games.
function Match._end(self: Match, winner: number, reason: string): { Event }
	self.phase = "Over"
	self.winner = winner
	self.shot = nil
	self.games[winner] = Config.Score.gamesToWinMatch
	return {
		{
			kind = "MatchOver",
			winner = winner,
			games = table.clone(self.games),
			points = table.clone(self.points),
			reason = reason,
		},
		self:snapshot(),
	}
end

-- A player left. The other one wins the match.
function Match.forfeit(self: Match, loser: number): { Event }
	if self.phase == "Over" then
		return {}
	end
	return self:_end(Match.other(loser), "forfeit")
end

return Match
