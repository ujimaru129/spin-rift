--!strict
-- Who plays whom. Players wait in a queue; the longer they wait, the wider the rating gap and the
-- set of regions they accept, as in the spec:
--   0-10 s  ±50,  same region
--  10-30 s  ±150, same region
--  30-60 s  ±300, neighbouring regions too
--  60 s +   any rating, any region
-- After 90 s a player is offered a Bot match (no rating change).

local Regions = require(script.Parent.Regions)

local Matchmaker = {}

export type Entry = {
	id: string, -- the player's UserId as a string
	rating: number,
	region: string,
	joinedAt: number,
	[string]: any, -- anything else the caller keeps with the entry (loadout, server id …)
}

export type Window = { maxDiff: number, regions: "same" | "neighbors" | "any" }

Matchmaker.Steps = {
	{ after = 0, maxDiff = 50, regions = "same" },
	{ after = 10, maxDiff = 150, regions = "same" },
	{ after = 30, maxDiff = 300, regions = "neighbors" },
	{ after = 60, maxDiff = math.huge, regions = "any" },
}
Matchmaker.BOT_OFFER_AFTER = 90

function Matchmaker.window(waited: number): Window
	local w = Matchmaker.Steps[1]
	for _, step in Matchmaker.Steps do
		if waited >= step.after then
			w = step
		end
	end
	return { maxDiff = w.maxDiff, regions = w.regions :: any }
end

local function regionOk(w: Window, a: string, b: string): boolean
	if w.regions == "any" then
		return true
	elseif w.regions == "neighbors" then
		return Regions.areNeighbors(a, b)
	end
	return a == b
end

-- Can these two play? The one who has waited longer decides how wide to look.
function Matchmaker.compatible(a: Entry, b: Entry, now: number): boolean
	local w = Matchmaker.window(now - math.min(a.joinedAt, b.joinedAt))
	return math.abs(a.rating - b.rating) <= w.maxDiff and regionOk(w, a.region, b.region)
end

-- Pairs up as many players as possible: longest-waiting first, each with the closest-rated
-- compatible partner. Returns the pairs and the entries still waiting.
function Matchmaker.pair(entries: { Entry }, now: number): ({ { Entry } }, { Entry })
	local waiting = table.clone(entries)
	table.sort(waiting, function(x, y)
		if x.joinedAt ~= y.joinedAt then
			return x.joinedAt < y.joinedAt
		end
		return x.id < y.id
	end)
	local taken: { [string]: boolean } = {}
	local pairs: { { Entry } } = {}
	for _, a in waiting do
		if not taken[a.id] then
			local best: Entry? = nil
			for _, b in waiting do
				if b.id ~= a.id and not taken[b.id] and Matchmaker.compatible(a, b, now) then
					if best == nil or math.abs(b.rating - a.rating) < math.abs(best.rating - a.rating) then
						best = b
					end
				end
			end
			if best then
				taken[a.id] = true
				taken[best.id] = true
				table.insert(pairs, { a, best })
			end
		end
	end
	local rest: { Entry } = {}
	for _, e in waiting do
		if not taken[e.id] then
			table.insert(rest, e)
		end
	end
	return pairs, rest
end

function Matchmaker.offerBot(waited: number): boolean
	return waited >= Matchmaker.BOT_OFFER_AFTER
end

-- Short description of how wide the search is right now, for the waiting screen.
function Matchmaker.describe(waited: number): string
	local w = Matchmaker.window(waited)
	local diff = if w.maxDiff == math.huge then "レート差なし" else `レート差 ±{w.maxDiff}`
	local area = if w.regions == "same"
		then "同じ地域"
		elseif w.regions == "neighbors" then "近くの地域も"
		else "全地域"
	return `{diff}・{area}`
end

return Matchmaker
