--!strict
-- Each player's ranked record, saved in a DataStore: rating, games played, wins, losses and how
-- often they left a match early. Changes go through UpdateAsync so two servers never overwrite
-- each other. If DataStores cannot be reached (for example Studio without API access), records
-- live in memory for this session only and a warning is printed once.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rating = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rank"):WaitForChild("Rating"))

local PlayerData = {}

-- Bump this at the start of a new season: ratings are pulled toward 1000 on the next load.
PlayerData.SEASON = 1
local STORE_NAME = "PlayerData_v1"
local RETRIES = 3

export type Data = {
	rating: number,
	best: number, -- highest rating this season
	games: number, -- ranked games finished this season
	wins: number,
	losses: number,
	leaves: number, -- ranked matches abandoned, ever
	leaveBanUntil: number, -- os.time() until which ranked play is blocked for leaving too often
	season: number,
}

local cache: { [number]: Data } = {}
local store: DataStore? = nil
local storeOk = true
local warned = false

local function fresh(): Data
	return {
		rating = Rating.INITIAL,
		best = Rating.INITIAL,
		games = 0,
		wins = 0,
		losses = 0,
		leaves = 0,
		leaveBanUntil = 0,
		season = PlayerData.SEASON,
	}
end

-- Fills in missing fields and applies a season reset if the record is from an older season.
local function normalize(raw: any): Data
	local d = fresh()
	if type(raw) == "table" then
		for k, v in d do
			if type(raw[k]) == type(v) then
				(d :: any)[k] = raw[k]
			end
		end
	end
	if d.season < PlayerData.SEASON then
		d.rating = Rating.seasonReset(d.rating)
		d.best = d.rating
		d.games, d.wins, d.losses = 0, 0, 0
		d.season = PlayerData.SEASON
	end
	return d
end

local function getStore(): DataStore?
	if not storeOk then
		return nil
	end
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		else
			storeOk = false
		end
	end
	return store
end

local function noStore(reason: string)
	storeOk = false
	if not warned then
		warned = true
		warn(
			`[PlayerData] DataStore を使えないため、成績はこのサーバーの中だけに保存します（{reason}）`
		)
	end
end

local function key(userId: number): string
	return "u_" .. tostring(userId)
end

local function retry<T>(fn: () -> T): (boolean, T?)
	local lastErr: any = nil
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < RETRIES then
			task.wait(attempt)
		end
	end
	noStore(tostring(lastErr))
	return false, nil
end

-- Loads (or creates) a player's record. Safe to call more than once.
function PlayerData.load(userId: number): Data
	local s = getStore()
	if s then
		local ok, raw = retry(function()
			return (s :: DataStore):GetAsync(key(userId))
		end)
		if ok then
			cache[userId] = normalize(raw)
			return cache[userId]
		end
	end
	cache[userId] = cache[userId] or fresh()
	return cache[userId]
end

function PlayerData.get(userId: number): Data
	return cache[userId] or PlayerData.load(userId)
end

-- Applies a change to a player's record, both in the DataStore (atomically) and in the cache.
function PlayerData.update(userId: number, change: (Data) -> ()): Data
	local s = getStore()
	if s then
		local ok, result = retry(function()
			return (s :: DataStore):UpdateAsync(key(userId), function(raw)
				local d = normalize(raw)
				change(d)
				return d
			end)
		end)
		if ok and result then
			cache[userId] = normalize(result)
			return cache[userId]
		end
	end
	local d = cache[userId] or fresh()
	change(d)
	cache[userId] = d
	return d
end

-- Records a finished ranked match for one player.
function PlayerData.recordResult(userId: number, delta: number, won: boolean, left: boolean): Data
	return PlayerData.update(userId, function(d)
		d.rating += delta
		d.best = math.max(d.best, d.rating)
		d.games += 1
		if won then
			d.wins += 1
		else
			d.losses += 1
		end
		if left then
			d.leaves += 1
			-- every third abandoned match blocks ranked play for 10 minutes
			if d.leaves % 3 == 0 then
				d.leaveBanUntil = os.time() + 600
			end
		end
	end)
end

function PlayerData.forget(userId: number)
	cache[userId] = nil
end

return PlayerData
