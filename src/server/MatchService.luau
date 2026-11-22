--!strict
-- Runs every match on this server: practice against the wall or a Bot, and online 1v1 between
-- two players waiting in the queue. Each match gets its own floating arena.
--
-- The server owns the match. Clients only send "I swung at server time T, aiming at A, standing
-- at Z". The server clamps T and Z to what the network delay allows and decides the result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RallyFolder = Shared:WaitForChild("Rally")
local Config = require(RallyFolder:WaitForChild("Config"))
local Judge = require(RallyFolder:WaitForChild("Judge"))
local Match = require(RallyFolder:WaitForChild("Match"))
local Bot = require(RallyFolder:WaitForChild("Bot"))
local Abilities = require(RallyFolder:WaitForChild("Abilities"))
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local Rank = Shared:WaitForChild("Rank")
local Rating = require(Rank:WaitForChild("Rating"))
local Regions = require(Rank:WaitForChild("Regions"))
local Arena = require(script.Parent.Arena)
local PlayerData = require(script.Parent.PlayerData)
local Leaderboard = require(script.Parent.Leaderboard)
local RankedQueue = require(script.Parent.RankedQueue)
local RankedResult = require(script.Parent.RankedResult)
local RankedRoom = require(script.Parent.RankedRoom)
local Analytics = require(script.Parent.Analytics)
local Progression = require(script.Parent.Progression)
local SeasonFolder = Shared:WaitForChild("Season")
local Arenas = require(SeasonFolder:WaitForChild("Arenas"))
local Cosmetics = require(SeasonFolder:WaitForChild("Cosmetics"))
local Feedback = require(script.Parent.Feedback)

local ONLINE = "Online" -- casual match with someone in this server
local RANKED = "Ranked"
local TUTORIAL = "Tutorial"
local TUTORIAL_RETURNS = 3 -- returns needed in the first tutorial step
local ARENA_SPACING = 400 -- studs between arenas
local AUTO_SERVE_AFTER = 5 -- seconds a player may wait before their serve goes in automatically
-- balls in a row a player may let go by without doing anything before they lose a 1v1 match
-- (stops two idle players from playing an endless deuce)
local IDLE_LIMIT = 4 -- points in a row with no input (a match is only 5 points)
local MIN_SWING_GAP = 0.15 -- ignore button mashing faster than this
local WALK_SPEED = 16
local ZONE_HALF_Z = 8 -- how far across the table a Blink may take a player

type Seat = {
	index: number, -- 1 or 2; player 1 stands on side -1
	player: Player?, -- nil for a bot
	bot: Bot.Bot?,
	model: Model?, -- the bot's avatar
	lastSwing: number,
	left: boolean,
	loadout: { string },
}

type Session = {
	mode: string,
	slot: number,
	origin: Vector3,
	arena: Model,
	match: Match.Match,
	seats: { Seat },
	onOver: ((winner: number, reason: string?) -> ())?,
	tutorial: { step: string, returns: number }?,
}

local MatchService = {}

local sessions: { [Session]: boolean } = {}
local byPlayer: { [Player]: Session } = {}
local queue: { Player } = {}
local queuedLoadouts: { [Player]: { string } } = {}
local queuedArenas: { [Player]: string } = {}
local usedSlots: { [number]: boolean } = {}
local matchEvent: RemoteEvent

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Half of the debug round-trip delay, applied once in each direction.
local function debugDelay(): number
	local ms = ReplicatedStorage:GetAttribute(Net.DEBUG_LAG_ATTRIBUTE)
	return if type(ms) == "number" and ms > 0 then ms / 2000 else 0
end

local function later(fn: () -> ())
	local d = debugDelay()
	if d > 0 then
		task.delay(d, fn)
	else
		fn()
	end
end

local function fire(player: Player, event: Match.Event)
	later(function()
		if player.Parent then
			matchEvent:FireClient(player, event)
		end
	end)
end

local function freeSlot(): number
	local i = 1
	while usedSlots[i] do
		i += 1
	end
	usedSlots[i] = true
	return i
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function seatZ(session: Session, seat: Seat): number
	if seat.bot then
		return seat.bot.z
	end
	local root = seat.player and rootPart(seat.player)
	return if root then root.Position.Z - session.origin.Z else 0
end

local function send(session: Session, event: Match.Event)
	for _, seat in session.seats do
		if seat.player and not seat.left then
			fire(seat.player, event)
		end
	end
end

local function humanoidOf(player: Player?): Humanoid?
	local character = player and player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Abilities that act on the world outside the match rules: movement.
local function applyAbility(session: Session, e: Match.Event)
	if e.state ~= "used" then
		return
	end
	if e.id == "EMP" then
		local target = session.seats[e.target]
		if target.bot then
			target.bot:jam(e.untilTime)
		end
		return
	end
	if e.id == "GravityWell" then
		local target = session.seats[e.target]
		if target.bot then
			target.bot:slow(e.untilTime, e.factor)
		else
			local humanoid = humanoidOf(target.player)
			if humanoid then
				humanoid.WalkSpeed = WALK_SPEED * e.factor
				task.delay(e.untilTime - now(), function()
					if humanoid.Parent and now() >= session.match.slowedUntil[e.target] then
						humanoid.WalkSpeed = WALK_SPEED
					end
				end)
			end
		end
	elseif e.id == "Blink" then
		local seat = session.seats[e.player]
		if seat.bot then
			seat.bot:blink(e.dirZ, e.distance)
		else
			local character = seat.player and seat.player.Character
			local root = seat.player and rootPart(seat.player)
			if character and root then
				local z = root.Position.Z - session.origin.Z
				local target = math.clamp(z + e.dirZ * e.distance, -ZONE_HALF_Z, ZONE_HALF_Z)
				character:PivotTo(character:GetPivot() + Vector3.new(0, 0, target - z))
			end
		end
	end
end

-- Tutorial: 3 returns, then a PERFECT, then an ability. Points do not count.
local function advanceTutorial(session: Session, events: { Match.Event })
	local tut = session.tutorial
	local player = session.seats[1].player
	if not tut or not player then
		return
	end
	local m = session.match
	local before = tut.step .. tut.returns
	for _, e in events do
		if e.kind == "Swing" and e.player == 1 and e.grade ~= "Miss" then
			tut.returns += 1
			if tut.returns == 1 then
				Analytics.funnel(player, "FirstReturn")
			end
			if e.grade == "Perfect" then
				Analytics.funnel(player, "FirstPerfect")
			end
			-- one step per return, so every instruction is shown
			if tut.step == "hit" and tut.returns >= TUTORIAL_RETURNS then
				tut.step = "perfect"
			elseif tut.step == "perfect" and e.grade == "Perfect" then
				tut.step = "ability"
			end
		elseif e.kind == "Ability" and e.player == 1 and (e.state == "fired" or e.state == "used") then
			Analytics.funnel(player, "FirstAbility")
			if tut.step == "ability" then
				tut.step = "done"
				Analytics.funnel(player, "TutorialDone")
				task.spawn(function()
					PlayerData.update(player.UserId, function(d)
						d.tutorialDone = true
					end)
				end)
			end
		elseif e.kind == "Point" then
			m.points = { 0, 0 }
		end
	end
	if tut.step == "ability" and m.gauge[1] < Config.Gauge.max then
		-- keep the gauge full so the player can try an ability right away
		m.gauge[1] = Config.Gauge.max
		send(session, m:snapshot())
	end
	if tut.step .. tut.returns ~= before then
		send(session, { kind = "Tutorial", step = tut.step, left = math.max(TUTORIAL_RETURNS - tut.returns, 0) })
	end
end

local function logMatchOver(session: Session, e: Match.Event)
	for _, seat in session.seats do
		local p = seat.player
		if p and not seat.left then
			Analytics.event(p, "MatchFinished", 1, { session.mode, if e.winner == seat.index then "win" else "loss" })
			task.spawn(Progression.awardMatch, p, session.mode, e.winner == seat.index)
			Analytics.funnel(p, "FirstMatchFinished")
			if session.mode == RANKED then
				Analytics.funnel(p, "FirstRankedFinished")
			end
		end
	end
end

local function dispatch(session: Session, events: { Match.Event })
	local pointEnded = false
	for _, e in events do
		if e.kind == "Ability" and (e.state == "used" or e.state == "fired") then
			local p = session.seats[e.player].player
			if p then
				Analytics.event(p, "AbilityUsed", 1, { e.id, session.mode })
			end
		elseif e.kind == "MatchOver" then
			logMatchOver(session, e)
		end
		if e.kind == "Ability" then
			applyAbility(session, e)
		end
		for _, seat in session.seats do
			if seat.bot then
				if e.kind == "Shot" then
					seat.bot:watch(e.shot)
				elseif e.kind == "Point" then
					seat.bot:watch(nil)
				end
			end
		end
		if e.kind == "Point" then
			pointEnded = true
		end
		send(session, e)
		if e.kind == "MatchOver" and session.onOver then
			local cb = session.onOver
			session.onOver = nil
			task.spawn(cb, e.winner, e.reason)
		end
	end
	local m = session.match
	if session.tutorial then
		advanceTutorial(session, events)
	end
	if pointEnded and m.phase == "Paused" then
		send(session, { kind = "ServeWait", server = m.server, at = m.nextServeAt })
	end
end

local function placeCharacter(session: Session, seat: Seat)
	local character = seat.player and seat.player.Character
	if character then
		local side = Match.sideOf(seat.index)
		character:PivotTo(Arena.playerSpawn(session.origin, side))
		local data = PlayerData.get((seat.player :: Player).UserId)
		local item = Cosmetics.get(data.equipped.paddle)
		if item and item.rgb then
			local material = (Enum.Material :: any)[item.material or "Neon"] or Enum.Material.Neon
			Arena.attachPaddle(character, Color3.fromRGB(item.rgb[1], item.rgb[2], item.rgb[3]), material)
		else
			Arena.attachPaddle(character, if side == -1 then Palette.TeamA else Palette.TeamB)
		end
	end
end

local function destroy(session: Session)
	sessions[session] = nil
	usedSlots[session.slot] = nil
	session.arena:Destroy()
	for _, seat in session.seats do
		if seat.model then
			seat.model:Destroy()
		end
		if seat.player and byPlayer[seat.player] == session then
			byPlayer[seat.player] = nil
		end
	end
end

local function seatName(seat: Seat): string
	return if seat.player then seat.player.DisplayName else ""
end

-- The cosmetics a seat shows in a match (false for a bot).
local function seatLook(seat: Seat): any
	if not seat.player then
		return false
	end
	return table.clone(PlayerData.get(seat.player.UserId).equipped)
end

local function begin(
	mode: string,
	seats: { Seat },
	firstServer: number,
	onOver: ((winner: number, reason: string?) -> ())?,
	arenaId: string?
)
	local slot = freeSlot()
	local origin = Vector3.new(slot * ARENA_SPACING, 200, 0)
	local arenaDef = Arenas.get(arenaId or Arenas.DEFAULT) or Arenas.List[1]
	-- gimmicks are for casual play only; ranked is always fair
	local windy = arenaDef.wind and mode ~= RANKED and mode ~= TUTORIAL
	local session: Session = {
		mode = mode,
		slot = slot,
		origin = origin,
		arena = Arena.build(origin, slot, arenaDef.id),
		match = Match.new(now(), firstServer, { seats[1].loadout, seats[2].loadout }, {
			windAt = if windy then Arenas.windAt else nil,
			idleLimit = if mode == ONLINE or mode == RANKED then IDLE_LIMIT else nil,
		}),
		seats = seats,
		onOver = onOver,
	}
	sessions[session] = true
	for _, seat in seats do
		if seat.player then
			byPlayer[seat.player] = session
			placeCharacter(session, seat)
		elseif seat.bot then
			seat.model = Arena.buildOpponent(origin)
		end
	end
	for _, seat in seats do
		if seat.player then
			local other = seats[Match.other(seat.index)]
			fire(seat.player, {
				kind = "Start",
				mode = mode,
				you = seat.index,
				side = Match.sideOf(seat.index),
				opponent = seatName(other),
				-- a Bot opponent's level ("Wall", "Easy", …); clients turn it into words
				opponentMode = if other.bot then (if mode == TUTORIAL then "Wall" else mode) else nil,
				origin = origin,
				loadout = seat.loadout,
				opponentLoadout = other.loadout,
				ranked = mode == RANKED,
				arena = arenaDef.id,
				wind = windy,
				looks = { seatLook(seats[1]), seatLook(seats[2]) },
			})
		end
	end
	send(session, session.match:snapshot())
	send(session, { kind = "ServeWait", server = session.match.server, at = session.match.nextServeAt })
end

local function humanSeat(index: number, player: Player, loadout: { string }): Seat
	return { index = index, player = player, lastSwing = 0, left = false, loadout = loadout }
end

-- Two different abilities for a practice Bot. The wall brings none.
local function botLoadout(mode: string, rng: Random): { string }
	if mode == "Wall" then
		return {}
	end
	local ids = {}
	for _, def in Abilities.List do
		table.insert(ids, def.id)
	end
	local a = table.remove(ids, rng:NextInteger(1, #ids)) :: string
	local b = table.remove(ids, rng:NextInteger(1, #ids)) :: string
	return { a, b }
end

local function startPractice(player: Player, mode: string, loadout: { string }, arena: string?)
	local tutorial = mode == TUTORIAL
	local botMode = if tutorial then "Wall" else mode
	local rng = Random.new()
	local bl = botLoadout(botMode, rng)
	local bot = Bot.new(botMode, Match.sideOf(2), function(a, b)
		return rng:NextNumber(a, b)
	end, bl)
	local seats = {
		humanSeat(1, player, if tutorial then { "Curve", "Barrier" } else loadout),
		{ index = 2, bot = bot, lastSwing = 0, left = false, loadout = bl } :: Seat,
	}
	-- the player serves first against the wall, the Bot serves first in a match
	begin(mode, seats, if botMode == "Wall" then 1 else 2, nil, if tutorial then Arenas.DEFAULT else arena)
	local session = byPlayer[player]
	if tutorial and session then
		session.tutorial = { step = "hit", returns = 0 }
		Analytics.funnel(player, "TutorialStarted")
		send(session, { kind = "Tutorial", step = "hit", left = TUTORIAL_RETURNS })
	end
end

local function removeFromQueue(player: Player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
	end
	queuedLoadouts[player] = nil
end

local function tryPair()
	while #queue >= 2 do
		local a = table.remove(queue, 1) :: Player
		local b = table.remove(queue, 1) :: Player
		local la, lb = queuedLoadouts[a], queuedLoadouts[b]
		local arena = queuedArenas[a]
		queuedLoadouts[a], queuedLoadouts[b] = nil, nil
		queuedArenas[a], queuedArenas[b] = nil, nil
		begin(ONLINE, { humanSeat(1, a, la), humanSeat(2, b, lb) }, math.random(1, 2), nil, arena)
	end
end

-- A ranked match between two players in this server. onOver gets the winner (1 or 2) and the
-- reason ("forfeit" if someone left, "idle" if someone stopped playing).
function MatchService.startRanked(players: { Player }, loadouts: { { string } }, onOver: (number, string?) -> ())
	for _, p in players do
		RankedQueue.leave(p)
		removeFromQueue(p)
	end
	-- an arena both players have unlocked (looks only: no gimmicks in ranked)
	local choices = Arenas.shared(PlayerData.get(players[1].UserId).best, PlayerData.get(players[2].UserId).best)
	local arena = choices[math.random(1, math.max(#choices, 1))]
	begin(RANKED, {
		humanSeat(1, players[1], Abilities.sanitize(loadouts[1])),
		humanSeat(2, players[2], Abilities.sanitize(loadouts[2])),
	}, math.random(1, 2), onOver, arena)
end

local function sendProfile(player: Player)
	local data = PlayerData.get(player.UserId)
	local region = RankedQueue.regionOf(player)
	local tier = Rating.tier(data.rating)
	local legend = data.rating >= 1750 and Leaderboard.isLegend(player.UserId, region)
	fire(player, {
		kind = "Profile",
		rating = data.rating,
		tier = if legend then Rating.legend().label else tier.label,
		tierId = if legend then "Legend" else tier.id,
		games = data.games,
		wins = data.wins,
		losses = data.losses,
		region = region,
		regionName = Regions.Names[region],
		placement = math.max(0, Rating.PLACEMENT_GAMES - data.games),
		tutorialDone = data.tutorialDone,
		best = data.best,
		arena = data.arena,
		pass = Progression.state(data),
	})
end

-- Two players in this server were paired for ranked (Studio, or a server without teleports).
local function startLocalRanked(players: { Player }, entries: { any })
	local sides = {}
	for _, e in entries do
		table.insert(sides, { userId = e.userId, rating = e.rating, games = e.games, region = e.region })
	end
	MatchService.startRanked(players, { entries[1].loadout, entries[2].loadout }, function(winner, reason)
		local leaver = if reason == "forfeit" or reason == "idle" then (if winner == 1 then 2 else 1) else nil
		RankedResult.finish(sides, winner, leaver, fire)
		for _, p in players do
			if p.Parent then
				sendProfile(p)
			end
		end
	end)
end

-- Takes a player out of whatever they are in. In an unfinished match the other player wins.
-- `why` says how a ranked wait ended if the player was in the ranked queue (see RankedQueue).
local function leave(player: Player, why: string?)
	removeFromQueue(player)
	RankedQueue.leave(player, why)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.WalkSpeed = WALK_SPEED
	end
	local session = byPlayer[player]
	if not session then
		return
	end
	byPlayer[player] = nil
	for _, seat in session.seats do
		if seat.player == player then
			seat.left = true
			dispatch(session, session.match:forfeit(seat.index))
		end
	end
	local anyone = false
	for _, seat in session.seats do
		if seat.player and not seat.left then
			anyone = true
		end
	end
	if not anyone then
		destroy(session)
	end
end

-- The arena a player asked for, if they have unlocked it; remembered for next time.
local function chooseArena(player: Player, requested: unknown): string
	local data = PlayerData.get(player.UserId)
	if type(requested) == "string" and Arenas.unlocked(requested, data.best) then
		data.arena = requested
		return requested
	end
	return if Arenas.unlocked(data.arena, data.best) then data.arena else Arenas.DEFAULT
end

local function request(player: Player, mode: unknown, loadout: unknown, arenaRequest: unknown)
	if type(mode) ~= "string" then
		return
	end
	if mode ~= ONLINE and mode ~= RANKED and mode ~= TUTORIAL and not (Bot.Profiles :: any)[mode] then
		return
	end
	local isBot = (Bot.Profiles :: any)[mode] ~= nil
	leave(player, if isBot then "bot" elseif mode == RANKED then "requeue" else "other")
	local chosen = Abilities.sanitize(loadout)
	local arena = chooseArena(player, arenaRequest)
	if mode == RANKED then
		if RankedRoom.isRoom() then
			return
		end
		local ok, reason = RankedQueue.join(player, chosen)
		Analytics.event(player, "RankedQueued", 1, { if ok then "ok" else tostring(reason) })
		if ok then
			fire(player, { kind = "Queued", ranked = true })
		else
			fire(player, { kind = "RankDenied", reason = reason })
		end
	elseif mode == ONLINE then
		table.insert(queue, player)
		queuedLoadouts[player] = chosen
		queuedArenas[player] = arena
		fire(player, { kind = "Queued" })
		tryPair()
	else
		startPractice(player, mode, chosen, arena)
	end
end

local function aimToZ(aim: number): number
	return math.clamp(aim, -1, 1) * (Config.Table.halfWidth - Config.AimMargin)
end

local function handleSwing(player: Player, reported: number, aim: number, reportedZ: number?)
	local session = byPlayer[player]
	if not session then
		return
	end
	local seat: Seat? = nil
	for _, s in session.seats do
		if s.player == player then
			seat = s
		end
	end
	if not seat then
		return
	end
	local received = now()
	if received - seat.lastSwing < MIN_SWING_GAP then
		return
	end
	seat.lastSwing = received
	local m = session.match
	local ping = player:GetNetworkPing() + debugDelay() * 2
	local z = Judge.trustedPlayerZ(reportedZ, seatZ(session, seat), ping)
	if m.server == seat.index and m:canServe(received) then
		dispatch(session, m:serve(received, z, aimToZ(aim)))
		return
	end
	local t = Judge.trustedSwingTime(reported, received)
	dispatch(session, m:swing(seat.index, t, aimToZ(aim), z))
end

local function onSwing(player: Player, reported: unknown, aim: unknown, myZ: unknown)
	if type(reported) ~= "number" or type(aim) ~= "number" then
		return
	end
	if reported ~= reported or aim ~= aim then -- NaN
		return
	end
	local z: number? = if type(myZ) == "number" then myZ else nil
	later(function()
		handleSwing(player, reported, aim, z)
	end)
end

local function seatOf(session: Session, player: Player): Seat?
	for _, s in session.seats do
		if s.player == player then
			return s
		end
	end
	return nil
end

local function onAbility(player: Player, slot: unknown, dirZ: unknown)
	if slot ~= 1 and slot ~= 2 then
		return
	end
	local d: number? = if type(dirZ) == "number" and dirZ == dirZ then dirZ else nil
	later(function()
		local session = byPlayer[player]
		local seat = session and seatOf(session, player)
		if session and seat then
			dispatch(session, session.match:useAbility(seat.index, slot :: number, now(), d))
		end
	end)
end

local function step(dt: number)
	local t = now()
	for session in sessions do
		local m = session.match
		local events: { Match.Event } = {}
		if m:canServe(t) then
			local seat = session.seats[m.server]
			if seat.bot then
				events = m:serve(t, seat.bot.z, seat.bot:pickAim())
			elseif t >= m.nextServeAt + AUTO_SERVE_AFTER then
				events = m:serve(t, seatZ(session, seat), 0, true)
			end
		end
		for _, seat in session.seats do
			local bot = seat.bot
			if bot then
				local swingAt = bot:step(dt, t)
				if swingAt then
					for _, e in m:swing(seat.index, swingAt, bot.aimZ, bot.z) do
						table.insert(events, e)
					end
				end
				if m.phase == "Rally" then
					local slot, dir = bot:think({
						now = t,
						gauge = m.gauge[seat.index],
						used = m.usedThisRally[seat.index],
						armed = m.armed[seat.index],
						barrier = m.barrier[seat.index],
						receiving = m.receiver == seat.index,
						shot = m.shot,
					})
					if slot then
						for _, e in m:useAbility(seat.index, slot, t, dir) do
							table.insert(events, e)
						end
					end
				end
				-- line the avatar's paddle up with where the bot stands
				local side = Match.sideOf(seat.index)
				local turn = if side == 1 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
				local at = session.origin + Vector3.new(side * (Config.HitX + 2.2), 0, bot.z - 1.3 * side)
				if seat.model then
					seat.model:PivotTo(CFrame.new(at) * turn)
				end
			end
		end
		for _, e in m:update(t) do
			table.insert(events, e)
		end
		dispatch(session, events)
	end
	RankedQueue.step()
end

function MatchService.start()
	Net.create()
	matchEvent = Net.get(Net.MATCH_EVENT)
	Net.get(Net.REQUEST_MATCH).OnServerEvent:Connect(request)
	Net.get(Net.LEAVE_MATCH).OnServerEvent:Connect(function(player)
		local wasPlaying = byPlayer[player] ~= nil
		leave(player, "cancel")
		fire(player, { kind = "Left" })
		if wasPlaying then
			player:LoadCharacter()
		end
	end)
	Net.get(Net.SWING).OnServerEvent:Connect(onSwing)
	Net.get(Net.USE_ABILITY).OnServerEvent:Connect(onAbility)
	Net.get(Net.HELLO).OnServerEvent:Connect(function(player)
		Analytics.funnel(player, "Joined")
		task.spawn(function()
			PlayerData.load(player.UserId)
			if player.Parent then
				sendProfile(player)
				if RankedRoom.isRoom() and not byPlayer[player] then
					fire(player, { kind = "RoomWaiting" })
				end
			end
		end)
	end)
	Net.get(Net.EQUIP).OnServerEvent:Connect(function(player, kind, id)
		task.spawn(Progression.equip, player, kind, id)
	end)
	Net.get(Net.BUY_PREMIUM).OnServerEvent:Connect(function(player)
		task.spawn(Progression.buyPremium, player)
	end)
	Net.get(Net.SEND_FEEDBACK).OnServerEvent:Connect(function(player, category, text, locale)
		task.spawn(function()
			fire(player, { kind = "FeedbackResult", status = Feedback.submit(player, category, text, locale) })
		end)
	end)
	Net.get(Net.REQUEST_LEADERBOARD).OnServerEvent:Connect(function(player, scope: unknown)
		if scope ~= "GLOBAL" and not table.find(Regions.List, scope) then
			return
		end
		task.spawn(function()
			local rows = Leaderboard.top(scope :: string, 10)
			fire(player, { kind = "Leaderboard", scope = scope, rows = rows })
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player, "quit")
		RankedQueue.forget(player)
		PlayerData.forget(player.UserId)
	end)
	RankedQueue.init({ fire = fire, startLocal = startLocalRanked })
	Progression.start(fire)
	if RankedRoom.isRoom() then
		task.spawn(RankedRoom.start, { fire = fire, startRanked = MatchService.startRanked })
	end
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			local session = byPlayer[player]
			if not session then
				return
			end
			for _, seat in session.seats do
				if seat.player == player then
					task.defer(placeCharacter, session, seat)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	RunService.Heartbeat:Connect(step)
end

return MatchService
