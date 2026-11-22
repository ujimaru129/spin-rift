--!strict
-- The ranked queue, run by every lobby server.
--
-- In a published game ("global" mode) all lobby servers share one queue in MemoryStore. One
-- server at a time holds a short lock and pairs players with the Matchmaker; for each pair it
-- reserves a private server, writes the match details for it, and leaves each player an
-- assignment. Every server checks for its own players' assignments and teleports them.
--
-- In Studio, where teleporting is not possible ("local" mode), players in this server are paired
-- with each other and the ranked match is played right here.

local LocalizationService = game:GetService("LocalizationService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Rank = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rank")
local Matchmaker = require(Rank:WaitForChild("Matchmaker"))
local Regions = require(Rank:WaitForChild("Regions"))
local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)

local RankedQueue = {}

local QUEUE_MAP = "RankedQueue_v1"
local ASSIGN_MAP = "RankedAssign_v1"
local MATCH_MAP = "RankedMatch_v1"
local LOCK_MAP = "RankedLock_v1"
local ENTRY_TTL = 120 -- seconds a queue entry lives without a refresh
local REFRESH_EVERY = 30
local LOCK_TTL = 10
local MATCH_TTL = 900

export type Hooks = {
	fire: (player: Player, event: { [string]: any }) -> (),
	startLocal: (players: { Player }, entries: { Matchmaker.Entry }) -> (),
}

type Waiting = { player: Player, entry: Matchmaker.Entry, refreshedAt: number }

local hooks: Hooks
local mode: "local" | "global" = "local"
local waiting: { [Player]: Waiting } = {}
local regions: { [Player]: string } = {}
local busy = false
local lastTick = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

function RankedQueue.init(h: Hooks)
	hooks = h
	mode = if RunService:IsStudio() or game.PlaceId == 0 then "local" else "global"
end

-- For tests: force the MemoryStore path.
function RankedQueue.setMode(m: "local" | "global")
	mode = m
end

function RankedQueue.mode(): string
	return mode
end

function RankedQueue.regionOf(player: Player): string
	local cached = regions[player]
	if cached then
		return cached
	end
	local ok, code = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	local region = Regions.fromCountry(if ok then code else nil)
	regions[player] = region
	return region
end

function RankedQueue.isQueued(player: Player): boolean
	return waiting[player] ~= nil
end

local function map(name: string): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(name)
end

-- Puts a player in the queue. Returns false (with a reason) when they may not play ranked now.
function RankedQueue.join(player: Player, loadout: { string }): (boolean, string?)
	local data = PlayerData.get(player.UserId)
	if data.leaveBanUntil > os.time() then
		return false, "banned"
	end
	local entry: Matchmaker.Entry = {
		id = tostring(player.UserId),
		userId = player.UserId,
		name = player.DisplayName,
		rating = data.rating,
		games = data.games,
		region = RankedQueue.regionOf(player),
		joinedAt = now(),
		loadout = loadout,
		jobId = game.JobId,
	}
	waiting[player] = { player = player, entry = entry, refreshedAt = 0 }
	return true, nil
end

-- How long a player waited and how the wait ended, for Creator Dashboard > Analytics.
-- RankedWait: value = seconds waited; fields = how it ended, wait range, region.
-- How it ended: "matched", "bot" (took the bot offer), "cancel", "quit" (left the game),
-- "requeue" (asked for ranked again), "other" (picked another mode).
local function logWait(player: Player, entry: Matchmaker.Entry, t: number, outcome: string)
	local waited = math.max(0, math.floor(t - entry.joinedAt + 0.5))
	Analytics.event(player, "RankedWait", waited, { outcome, Matchmaker.waitBucket(waited), entry.region })
end

-- Takes a player out of the queue. `why` is how the wait ended (see logWait); default "cancel".
function RankedQueue.leave(player: Player, why: string?): boolean
	local w = waiting[player]
	if not w then
		return false
	end
	waiting[player] = nil
	logWait(player, w.entry, now(), why or "cancel")
	if mode == "global" then
		task.spawn(function()
			pcall(function()
				map(QUEUE_MAP):RemoveAsync(w.entry.id)
			end)
		end)
	end
	return true
end

function RankedQueue.forget(player: Player)
	RankedQueue.leave(player, "quit")
	regions[player] = nil
end

local function sendStatus(t: number)
	for player, w in waiting do
		local waited = t - w.entry.joinedAt
		hooks.fire(player, {
			kind = "RankQueue",
			waited = waited,
			search = Matchmaker.describe(waited),
			botOffer = Matchmaker.offerBot(waited),
		})
	end
end

local function tickLocal(t: number)
	local entries = {}
	local byId: { [string]: Player } = {}
	for player, w in waiting do
		table.insert(entries, w.entry)
		byId[w.entry.id] = player
	end
	local pairs = Matchmaker.pair(entries, t)
	for _, pair in pairs do
		local a, b = byId[pair[1].id], byId[pair[2].id]
		logWait(a, waiting[a].entry, t, "matched")
		logWait(b, waiting[b].entry, t, "matched")
		waiting[a], waiting[b] = nil, nil
		hooks.startLocal({ a, b }, pair)
	end
end

-- Only one server pairs players at a time.
local function takeLock(t: number): boolean
	local ok, holder = pcall(function()
		return map(LOCK_MAP):UpdateAsync("lock", function(old: any)
			if old == nil or old.jobId == game.JobId or old.expires < t then
				return { jobId = game.JobId, expires = t + LOCK_TTL }
			end
			return nil
		end, LOCK_TTL)
	end)
	return ok and holder ~= nil and (holder :: any).jobId == game.JobId
end

local function pairGlobally(t: number)
	local q = map(QUEUE_MAP)
	local ok, items = pcall(function()
		return q:GetRangeAsync(Enum.SortDirection.Ascending, 200)
	end)
	if not ok or not items then
		return
	end
	local entries = {}
	for _, item in items :: { any } do
		table.insert(entries, item.value)
	end
	local pairs = Matchmaker.pair(entries, t)
	for _, pair in pairs do
		local reserved, code, privateId = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		if reserved and code then
			local stored = pcall(function()
				map(MATCH_MAP):SetAsync(privateId, { players = pair, createdAt = t }, MATCH_TTL)
				for _, e in pair do
					map(ASSIGN_MAP):SetAsync(e.id, { code = code, privateId = privateId }, ENTRY_TTL)
					q:RemoveAsync(e.id)
				end
			end)
			if not stored then
				warn("[RankedQueue] could not store a match; players stay in the queue")
			end
		end
	end
end

local function tickGlobal(t: number)
	local q = map(QUEUE_MAP)
	local assignments = map(ASSIGN_MAP)
	for player, w in waiting do
		-- keep our entries alive in the shared queue
		if t - w.refreshedAt >= REFRESH_EVERY then
			local ok = pcall(function()
				q:SetAsync(w.entry.id, w.entry, ENTRY_TTL, w.entry.rating)
			end)
			if ok then
				w.refreshedAt = t
			end
		end
		-- has some server paired this player?
		local ok, assignment = pcall(function()
			return assignments:GetAsync(w.entry.id)
		end)
		if ok and assignment and waiting[player] then
			waiting[player] = nil
			logWait(player, w.entry, now(), "matched")
			pcall(function()
				assignments:RemoveAsync(w.entry.id)
			end)
			hooks.fire(player, { kind = "Teleporting" })
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = (assignment :: any).code
			local sent = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, { player }, options)
			end)
			if not sent then
				hooks.fire(player, { kind = "RankCancelled", reason = "teleport" })
			end
		end
	end
	if takeLock(t) then
		pairGlobally(t)
	end
end

-- Called every frame by MatchService; does its work about once a second.
function RankedQueue.step()
	local t = now()
	if t - lastTick < 1 then
		return
	end
	lastTick = t
	sendStatus(t)
	if mode == "local" then
		tickLocal(t)
	elseif not busy and next(waiting) ~= nil then
		busy = true
		task.spawn(function()
			local ok, err = pcall(tickGlobal, t)
			if not ok then
				warn("[RankedQueue] " .. tostring(err))
			end
			busy = false
		end)
	end
end

-- Match details a reserved server stored for itself (used by RankedRoom).
function RankedQueue.readMatch(privateId: string): any
	local ok, info = pcall(function()
		return map(MATCH_MAP):GetAsync(privateId)
	end)
	return if ok then info else nil
end

return RankedQueue
