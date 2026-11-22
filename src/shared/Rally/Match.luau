--!strict
-- One match between two players: serve, rally, points, games and the ability gauge.
-- Pure logic with no Instances. The caller passes in the time (server clock) on every call and
-- forwards the returned events to clients. Player 1 stands on side -1, player 2 on side 1.

local Config = require(script.Parent.Config)
local Judge = require(script.Parent.Judge)
local Trajectory = require(script.Parent.Trajectory)

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
	},
	Match
))

function Match.sideOf(index: number): number
	return if index == 1 then -1 else 1
end

function Match.other(index: number): number
	return if index == 1 then 2 else 1
end

function Match.new(now: number, firstServer: number?): Match
	local first = firstServer or 1
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
	}, Match)
end

function Match.snapshot(self: Match): Event
	return {
		kind = "Score",
		points = table.clone(self.points),
		games = table.clone(self.games),
		gauge = table.clone(self.gauge),
		server = self.server,
	}
end

function Match.canServe(self: Match, now: number): boolean
	return self.phase == "Paused" and now >= self.nextServeAt
end

-- The current server puts the ball in play. fromZ = where across the table they stand.
function Match.serve(self: Match, now: number, fromZ: number, aimZ: number): { Event }
	if not self:canServe(now) then
		return {}
	end
	local side = Match.sideOf(self.server)
	local from = Vector3.new(side * Config.HitX, Config.HitY, fromZ)
	local shot = Trajectory.plan(from, side, aimZ, "Serve", now)
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
	table.insert(events, { kind = "Point", winner = winner, reason = reason })

	local p, q = self.points[winner], self.points[Match.other(winner)]
	if p >= Config.Score.pointsToWinGame and p - q >= Config.Score.winBy then
		self.games[winner] += 1
		table.insert(events, { kind = "Game", winner = winner, games = table.clone(self.games) })
		if self.games[winner] >= Config.Score.gamesToWinMatch then
			self.phase = "Over"
			self.winner = winner
			table.insert(events, { kind = "MatchOver", winner = winner, games = table.clone(self.games) })
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

-- A player swings. time = trusted swing time, playerZ = where they stood across the table.
-- Swings by the wrong player, or far too early, are ignored and return no events.
function Match.swing(self: Match, index: number, time: number, aimZ: number, playerZ: number): { Event }
	local shot = self.shot
	if self.phase ~= "Rally" or shot == nil or index ~= self.receiver then
		return {}
	end
	local offset = time - Trajectory.arrivalTime(shot)
	if offset < -Config.IgnoreEarlierThan then
		return {}
	end
	local grade = Judge.grade(offset)
	local reached = Judge.inReach(shot.to.Z, playerZ)
	if grade == "Miss" or not reached then
		local events = { { kind = "Swing", player = index, grade = "Miss", offset = offset, reached = reached } }
		for _, e in self:_award(Match.other(index), if reached then "whiff" else "reach", time) do
			table.insert(events, e)
		end
		return events
	end

	self.gauge[index] = math.min(Config.Gauge.max, self.gauge[index] + Judge.gaugeFor(grade))
	self.rally += 1
	local side = Match.sideOf(index)
	local from = Vector3.new(side * Config.HitX, Config.HitY, shot.to.Z)
	local nextShot = Trajectory.plan(from, side, aimZ, grade, time)
	self.shot = nextShot
	self.receiver = Match.other(index)
	return {
		{
			kind = "Swing",
			player = index,
			grade = grade,
			offset = offset,
			reached = true,
			rally = self.rally,
			gauge = self.gauge[index],
		},
		{ kind = "Shot", shot = nextShot },
	}
end

-- Call every frame. Awards the point when the receiver lets the ball go past.
function Match.update(self: Match, now: number): { Event }
	local shot = self.shot
	if self.phase == "Rally" and shot and now > Trajectory.arrivalTime(shot) + Config.Timing.weak then
		return self:_award(Match.other(self.receiver), "miss", now)
	end
	return {}
end

return Match
