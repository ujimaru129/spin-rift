--!strict
-- The arenas. Each unlocks at a rank (by the player's best rating this season); some can also be
-- bought in the shop (item "arena_" .. id). Casual and practice matches use the arena's gimmick;
-- ranked matches never do, so ranked is fair.

local Arenas = {}

export type Arena = {
	id: string,
	unlockRating: number, -- best rating needed
	unlockRank: string, -- rank id shown on the lock
	unlockDivision: string?, -- and its division ("I"), if the lock is inside a rank
	wind: boolean, -- Sakura Float: wind nudges the ball sideways
	drag: number?, -- Aquarium Dome: the water makes every shot take this much longer
	sold: boolean?, -- also sold in the shop
}

Arenas.List = {
	{ id = "Rooftop", unlockRating = -math.huge, unlockRank = "Bronze", wind = false },
	-- Bronze I: a few wins in, so new players have something to reach for early
	{ id = "Sakura", unlockRating = 1034, unlockRank = "Bronze", unlockDivision = "I", wind = true },
	-- Silver, or bought in the shop
	{ id = "Aquarium", unlockRating = 1100, unlockRank = "Silver", wind = false, drag = 1.12, sold = true },
} :: { Arena }

Arenas.DEFAULT = "Rooftop"

function Arenas.get(id: string): Arena?
	for _, a in Arenas.List do
		if a.id == id then
			return a
		end
	end
	return nil
end

function Arenas.itemId(id: string): string
	return "arena_" .. id
end

-- By rank, or bought (`items` = the player's items).
function Arenas.unlocked(id: string, bestRating: number, items: { [string]: boolean }?): boolean
	local a = Arenas.get(id)
	if a == nil then
		return false
	end
	return bestRating >= a.unlockRating or (a.sold == true and items ~= nil and items[Arenas.itemId(id)] == true)
end

-- The arenas both players may use (for a ranked match).
function Arenas.shared(
	bestA: number,
	bestB: number,
	itemsA: { [string]: boolean }?,
	itemsB: { [string]: boolean }?
): { string }
	local out = {}
	for _, a in Arenas.List do
		if Arenas.unlocked(a.id, bestA, itemsA) and Arenas.unlocked(a.id, bestB, itemsB) then
			table.insert(out, a.id)
		end
	end
	return out
end

-- Wind strength (studs of sideways drift over a shot) at server time t. It changes slowly, so
-- players can read it from the HUD before they hit.
Arenas.WIND_MAX = 0.9
function Arenas.windAt(t: number): number
	return Arenas.WIND_MAX * math.sin(t * 0.35) * math.cos(t * 0.11)
end

return Arenas
