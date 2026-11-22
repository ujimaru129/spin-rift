--!strict
-- Practice matches: one player against the wall or a Bot, each on their own floating arena.
-- The server owns the match. Clients only send "I swung at server time T, aiming at A";
-- the server clamps T, checks reach from the character's position and decides the result.

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

local HUMAN, BOT = 1, 2
local ARENA_SPACING = 400 -- studs between practice arenas
local AUTO_SERVE_AFTER = 5 -- seconds a player may wait before their serve goes in automatically
local MIN_SWING_GAP = 0.15 -- ignore button mashing faster than this

type Session = {
	player: Player,
	mode: string,
	slot: number,
	origin: Vector3,
	arena: Model,
	opponent: Model,
	match: Match.Match,
	bot: Bot.Bot,
	lastSwing: number,
}

local PracticeService = {}

local sessions: { [Player]: Session } = {}
local usedSlots: { [number]: boolean } = {}
local matchEvent: RemoteEvent

local function freeSlot(): number
	local i = 1
	while usedSlots[i] do
		i += 1
	end
	usedSlots[i] = true
	return i
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function send(session: Session, event: Match.Event)
	matchEvent:FireClient(session.player, event)
end

local function dispatch(session: Session, events: { Match.Event })
	local pointEnded = false
	for _, e in events do
		if e.kind == "Shot" then
			session.bot:watch(e.shot)
		elseif e.kind == "Point" then
			session.bot:watch(nil)
			pointEnded = true
		end
		send(session, e)
	end
	local m = session.match
	if pointEnded and m.phase == "Paused" then
		send(session, { kind = "ServeWait", server = m.server, at = m.nextServeAt })
	end
end

local function stop(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	usedSlots[s.slot] = nil
	s.arena:Destroy()
	s.opponent:Destroy()
end

local function placeCharacter(session: Session)
	local character = session.player.Character
	if character then
		character:PivotTo(Arena.playerSpawn(session.origin))
		Arena.attachPaddle(character, Palette.TeamA)
	end
end

local function start(player: Player, mode: string)
	stop(player)
	local slot = freeSlot()
	local origin = Vector3.new(slot * ARENA_SPACING, 200, 0)
	local rng = Random.new()
	local t = now()
	local session: Session = {
		player = player,
		mode = mode,
		slot = slot,
		origin = origin,
		arena = Arena.build(origin, slot),
		opponent = Arena.buildOpponent(origin + Vector3.new(Config.HitX + 2.2, 0, 0)),
		-- the player serves first against the wall, the Bot serves first in a match
		match = Match.new(t, if mode == "Wall" then HUMAN else BOT),
		bot = Bot.new(mode, Match.sideOf(BOT), function(a, b)
			return rng:NextNumber(a, b)
		end),
		lastSwing = 0,
	}
	sessions[player] = session
	placeCharacter(session)
	send(session, {
		kind = "Start",
		mode = mode,
		label = (Bot.Profiles :: any)[mode].label,
		origin = origin,
		side = Match.sideOf(HUMAN),
	})
	send(session, session.match:snapshot())
	send(session, { kind = "ServeWait", server = session.match.server, at = session.match.nextServeAt })
end

local function playerZ(session: Session): number
	local root = rootPart(session.player)
	return if root then root.Position.Z - session.origin.Z else 0
end

local function aimToZ(aim: number): number
	return math.clamp(aim, -1, 1) * (Config.Table.halfWidth - Config.AimMargin)
end

local function onSwing(player: Player, reported: unknown, aim: unknown)
	local s = sessions[player]
	if not s or type(reported) ~= "number" or type(aim) ~= "number" then
		return
	end
	if reported ~= reported or aim ~= aim then -- NaN
		return
	end
	local received = now()
	if received - s.lastSwing < MIN_SWING_GAP then
		return
	end
	s.lastSwing = received
	local m = s.match
	local z = playerZ(s)
	if m.server == HUMAN and m:canServe(received) then
		dispatch(s, m:serve(received, z, aimToZ(aim)))
		return
	end
	local t = Judge.trustedSwingTime(reported, received)
	dispatch(s, m:swing(HUMAN, t, aimToZ(aim), z))
end

local function step(dt: number)
	local t = now()
	for _, s in sessions do
		local m = s.match
		local events: { Match.Event } = {}
		if m:canServe(t) then
			if m.server == BOT then
				events = m:serve(t, s.bot.z, s.bot:pickAim())
			elseif t >= m.nextServeAt + AUTO_SERVE_AFTER then
				events = m:serve(t, playerZ(s), 0)
			end
		end
		local swingAt = s.bot:step(dt, t)
		if swingAt then
			for _, e in m:swing(BOT, swingAt, s.bot.aimZ, s.bot.z) do
				table.insert(events, e)
			end
		end
		for _, e in m:update(t) do
			table.insert(events, e)
		end
		dispatch(s, events)
		-- keep the opponent's paddle lined up with where the bot stands
		s.opponent:PivotTo(CFrame.new(s.origin + Vector3.new(Config.HitX + 2.2, 0, s.bot.z - 1.3)))
	end
end

function PracticeService.start()
	Net.create()
	matchEvent = Net.get(Net.MATCH_EVENT)
	Net.get(Net.START_PRACTICE).OnServerEvent:Connect(function(player, mode: unknown)
		if type(mode) == "string" and (Bot.Profiles :: any)[mode] then
			start(player, mode)
		end
	end)
	Net.get(Net.LEAVE_PRACTICE).OnServerEvent:Connect(function(player)
		stop(player)
		matchEvent:FireClient(player, { kind = "Left" })
		player:LoadCharacter()
	end)
	Net.get(Net.SWING).OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(stop)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local s = sessions[player]
			if s then
				task.defer(placeCharacter, s)
			end
		end)
	end)
	RunService.Heartbeat:Connect(step)
end

return PracticeService
