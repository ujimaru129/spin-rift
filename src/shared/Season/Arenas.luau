--!strict
-- The arenas available at launch. Each unlocks at a rank (by the player's best rating this season).
-- Casual and practice matches use the arena's gimmick; ranked matches never do, so ranked is fair.

local Arenas = {}

export type Arena = {
	id: string,
	unlockRating: number, -- best rating needed
	unlockRank: string, -- rank id shown on the lock
	wind: boolean, -- Sakura Float: wind nudges the ball sideways
}

Arenas.List = {
	{ id = "Rooftop", unlockRating = -math.huge, unlockRank = "Bronze", wind = false },
	{ id = "Sakura", unlockRating = 1100, unlockRank = "Silver", wind = true },
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

function Arenas.unlocked(id: string, bestRating: number): boolean
	local a = Arenas.get(id)
	return a ~= nil and bestRating >= a.unlockRating
end

-- The arenas both players may use (for a ranked match).
function Arenas.shared(bestA: number, bestB: number): { string }
	local out = {}
	for _, a in Arenas.List do
		if bestA >= a.unlockRating and bestB >= a.unlockRating then
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
