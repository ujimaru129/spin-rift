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
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local Arena = require(script.Parent.Arena)

local ONLINE = "Online"
local ARENA_SPACING = 400 -- studs between arenas
local AUTO_SERVE_AFTER = 5 -- seconds a player may wait before their serve goes in automatically
local MIN_SWING_GAP = 0.15 -- ignore button mashing faster than this

type Seat = {
	index: number, -- 1 or 2; player 1 stands on side -1
	player: Player?, -- nil for a bot
	bot: Bot.Bot?,
	model: Model?, -- the bot's avatar
	lastSwing: number,
	left: boolean,
}

type Session = {
	mode: string,
	slot: number,
	origin: Vector3,
	arena: Model,
	match: Match.Match,
	seats: { Seat },
}

local MatchService = {}

local sessions: { [Session]: boolean } = {}
local byPlayer: { [Player]: Session } = {}
local queue: { Player } = {}
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

local function dispatch(session: Session, events: { Match.Event })
	local pointEnded = false
	for _, e in events do
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
	end
	local m = session.match
	if pointEnded and m.phase == "Paused" then
		send(session, { kind = "ServeWait", server = m.server, at = m.nextServeAt })
	end
end

local function placeCharacter(session: Session, seat: Seat)
	local character = seat.player and seat.player.Character
	if character then
		local side = Match.sideOf(seat.index)
		character:PivotTo(Arena.playerSpawn(session.origin, side))
		Arena.attachPaddle(character, if side == -1 then Palette.TeamA else Palette.TeamB)
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

local function seatName(seat: Seat, mode: string): string
	if seat.player then
		return seat.player.DisplayName
	end
	return if mode == "Wall" then "WALL" else "BOT（" .. (Bot.Profiles :: any)[mode].label .. "）"
end

local function begin(mode: string, seats: { Seat }, firstServer: number)
	local slot = freeSlot()
	local origin = Vector3.new(slot * ARENA_SPACING, 200, 0)
	local session: Session = {
		mode = mode,
		slot = slot,
		origin = origin,
		arena = Arena.build(origin, slot),
		match = Match.new(now(), firstServer),
		seats = seats,
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
				opponent = seatName(other, mode),
				origin = origin,
			})
		end
	end
	send(session, session.match:snapshot())
	send(session, { kind = "ServeWait", server = session.match.server, at = session.match.nextServeAt })
end

local function humanSeat(index: number, player: Player): Seat
	return { index = index, player = player, lastSwing = 0, left = false }
end

local function startPractice(player: Player, mode: string)
	local rng = Random.new()
	local bot = Bot.new(mode, Match.sideOf(2), function(a, b)
		return rng:NextNumber(a, b)
	end)
	local seats = { humanSeat(1, player), { index = 2, bot = bot, lastSwing = 0, left = false } :: Seat }
	-- the player serves first against the wall, the Bot serves first in a match
	begin(mode, seats, if mode == "Wall" then 1 else 2)
end

local function removeFromQueue(player: Player)
	local i = table.find(queue, player)
	if i then
		table.remove(queue, i)
	end
end

local function tryPair()
	while #queue >= 2 do
		local a = table.remove(queue, 1) :: Player
		local b = table.remove(queue, 1) :: Player
		begin(ONLINE, { humanSeat(1, a), humanSeat(2, b) }, math.random(1, 2))
	end
end

-- Takes a player out of whatever they are in. In an unfinished online match the other player wins.
local function leave(player: Player)
	removeFromQueue(player)
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

local function request(player: Player, mode: unknown)
	if type(mode) ~= "string" then
		return
	end
	if mode ~= ONLINE and not (Bot.Profiles :: any)[mode] then
		return
	end
	leave(player)
	if mode == ONLINE then
		table.insert(queue, player)
		fire(player, { kind = "Queued" })
		tryPair()
	else
		startPractice(player, mode)
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
				events = m:serve(t, seatZ(session, seat), 0)
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
end

function MatchService.start()
	Net.create()
	matchEvent = Net.get(Net.MATCH_EVENT)
	Net.get(Net.REQUEST_MATCH).OnServerEvent:Connect(request)
	Net.get(Net.LEAVE_MATCH).OnServerEvent:Connect(function(player)
		local wasPlaying = byPlayer[player] ~= nil
		leave(player)
		fire(player, { kind = "Left" })
		if wasPlaying then
			player:LoadCharacter()
		end
	end)
	Net.get(Net.SWING).OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(leave)
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
