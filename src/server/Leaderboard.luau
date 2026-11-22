--!strict
-- Rating leaderboards: one for the whole world and one per region, kept in OrderedDataStores.
-- The top 100 of each region are Rift Legends. Reads are cached for a minute so lobby servers
-- do not hammer the DataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboard = {}

Leaderboard.SEASON = 1
Leaderboard.LEGEND_TOP = 100
local CACHE_SECONDS = 60

export type Row = { rank: number, userId: number, name: string, rating: number }

local cache: { [string]: { at: number, rows: { Row } } } = {}
local names: { [number]: string } = {}

local function storeFor(scope: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(`Rating_S{Leaderboard.SEASON}_{scope}`)
	end)
	return if ok then store else nil
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else `Player {userId}`
	return names[userId]
end

-- Records a player's current rating on the world board and their region's board.
function Leaderboard.submit(userId: number, rating: number, region: string)
	for _, scope in { "GLOBAL", region } do
		local store = storeFor(scope)
		if store then
			pcall(function()
				store:SetAsync(tostring(userId), math.floor(rating))
			end)
		end
	end
	-- forget cached reads of the boards that changed
	for k in cache do
		if string.sub(k, 1, #"GLOBAL:") == "GLOBAL:" or string.sub(k, 1, #region + 1) == region .. ":" then
			cache[k] = nil
		end
	end
end

-- The top `count` rows of a board ("GLOBAL" or a region id), best first.
function Leaderboard.top(scope: string, count: number?): { Row }
	local n = count or 10
	local hit = cache[scope .. ":" .. n]
	if hit and os.clock() - hit.at < CACHE_SECONDS then
		return hit.rows
	end
	local rows: { Row } = {}
	local store = storeFor(scope)
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, math.min(n, 100))
		end)
		if ok and pages then
			local page = pages:GetCurrentPage()
			for i, item in page do
				if i > n then
					break
				end
				local userId = tonumber(item.key) or 0
				table.insert(rows, { rank = i, userId = userId, name = nameOf(userId), rating = item.value })
			end
		end
	end
	cache[scope .. ":" .. n] = { at = os.clock(), rows = rows }
	return rows
end

-- Is this player in the top 100 of their region?
function Leaderboard.isLegend(userId: number, region: string): boolean
	for _, row in Leaderboard.top(region, Leaderboard.LEGEND_TOP) do
		if row.userId == userId then
			return true
		end
	end
	return false
end

return Leaderboard
