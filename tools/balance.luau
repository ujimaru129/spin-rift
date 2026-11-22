-- Measures how strong each ability is: Bot "ふつう" vs Bot "ふつう", each bringing one ability,
-- every pair of abilities, many matches each with sides swapped. Run from the repo root:
--   lune run tools/balance [matches per pair, default 24]
-- The spec's target for phase 3 is a win rate between 45% and 55% for every ability.

local process = require("@lune/process")
local loader = require("../tests/loader")
local Sim = require("../tests/Sim")(loader)
local Abilities = loader.require("src/shared/Rally/Abilities")

local perPair = tonumber(process.args[1]) or 24
local ids = {}
for _, d in Abilities.List do
	table.insert(ids, d.id)
end
table.insert(ids, "(なし)")

local wins, games = {}, {}
for _, id in ids do
	wins[id], games[id] = 0, 0
end

local seed = 1
for i, a in ids do
	for j, b in ids do
		if i < j then
			for n = 1, perPair do
				seed += 1
				local left, right = a, b
				if n % 2 == 0 then
					left, right = b, a
				end
				local function loadout(id)
					return if id == "(なし)" then {} else { id }
				end
				local m = Sim.play({
					profiles = { "Normal", "Normal" },
					loadouts = { loadout(left), loadout(right) },
					seed = seed,
				})
				local winner = if m.winner == 1 then left else right
				wins[winner] += 1
				games[left] += 1
				games[right] += 1
			end
		end
	end
end

print(string.format("%-14s %6s %8s", "ability", "games", "win %"))
table.sort(ids, function(x, y)
	return wins[x] / games[x] > wins[y] / games[y]
end)
for _, id in ids do
	local rate = wins[id] / games[id] * 100
	local mark = if id == "(なし)"
		then ""
		elseif rate < 45 then "  ← 弱い"
		elseif rate > 55 then "  ← 強い"
		else ""
	print(string.format("%-14s %6d %7.1f%s", id, games[id], rate, mark))
end
