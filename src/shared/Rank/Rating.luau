--!strict
-- Rating and ranks. An Elo-style rating (starting at 1000) measures strength; it is shown to
-- players as a rank: Bronze, Silver, Gold, Diamond, Master, each split into III, II and I.
-- The top 100 of each region are Rift Legends (decided from the leaderboard, not from here).

local Rating = {}

Rating.INITIAL = 1000
Rating.K = 40 -- a win against an equal opponent gains about 20
Rating.PLACEMENT_GAMES = 10 -- the first 10 games move the rating twice as much
Rating.MIN_DELTA = 8 -- every result moves the rating at least this much
Rating.MAX_DELTA = 36
Rating.SEASON_KEEP = 0.7 -- at a new season, keep 70% of the distance from 1000

export type Tier = {
	id: string, -- "Bronze" | "Silver" | "Gold" | "Diamond" | "Master" | "Legend"
	name: string, -- ブロンズ …
	division: string?, -- "III" | "II" | "I", nil for Master and Legend
	label: string, -- e.g. "ゴールド II"
	low: number, -- rating where this division starts
	high: number?, -- rating where the next one starts
}

-- Lower bounds of each rank, from the spec.
Rating.Ranks = {
	{ id = "Bronze", name = "ブロンズ", low = -math.huge, high = 1100, divisions = true },
	{ id = "Silver", name = "シルバー", low = 1100, high = 1300, divisions = true },
	{ id = "Gold", name = "ゴールド", low = 1300, high = 1500, divisions = true },
	{ id = "Diamond", name = "ダイヤ", low = 1500, high = 1750, divisions = true },
	{ id = "Master", name = "マスター", low = 1750, high = math.huge, divisions = false },
}

local DIVISIONS = { "III", "II", "I" }
local BRONZE_FLOOR = 900 -- Bronze III covers everything below Bronze II

function Rating.expected(a: number, b: number): number
	return 1 / (1 + 10 ^ ((b - a) / 400))
end

-- Rating change for a player rated `mine` against `theirs`. won = did they win.
-- gamesPlayed = ranked games finished before this one (fewer than 10 = placement, double change).
function Rating.delta(mine: number, theirs: number, won: boolean, gamesPlayed: number): number
	local e = Rating.expected(mine, theirs)
	local raw = Rating.K * ((if won then 1 else 0) - e)
	local size = math.clamp(math.abs(raw), Rating.MIN_DELTA, Rating.MAX_DELTA)
	if gamesPlayed < Rating.PLACEMENT_GAMES then
		size *= 2
	end
	return math.round(size) * (if won then 1 else -1)
end

function Rating.tier(rating: number): Tier
	for _, r in Rating.Ranks do
		if rating >= r.low and rating < r.high then
			if not r.divisions then
				return { id = r.id, name = r.name, label = r.name, low = r.low, high = nil }
			end
			local low = if r.low == -math.huge then BRONZE_FLOOR else r.low
			local step = (r.high - low) / 3
			local i = math.clamp(math.floor((rating - low) / step) + 1, 1, 3)
			if rating < low then
				i = 1
			end
			local d = DIVISIONS[i]
			local divLow = if i == 1 then r.low else low + step * (i - 1)
			local divHigh = if i == 3 then r.high else low + step * i
			return { id = r.id, name = r.name, division = d, label = `{r.name} {d}`, low = divLow, high = divHigh }
		end
	end
	error("unreachable")
end

function Rating.legend(): Tier
	return { id = "Legend", name = "リフトレジェンド", label = "リフトレジェンド", low = 0, high = nil }
end

-- Did moving from `before` to `after` cross into a different division?
function Rating.changedTier(before: number, after: number): boolean
	return Rating.tier(before).label ~= Rating.tier(after).label
end

-- New season: pull every rating part of the way back toward 1000.
function Rating.seasonReset(rating: number): number
	return math.round(Rating.INITIAL + (rating - Rating.INITIAL) * Rating.SEASON_KEEP)
end

return Rating
