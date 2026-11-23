-- How long rallies last and how often the stronger bot wins, with no abilities, for each pair of
-- bot levels. Used to tune how much skill decides a point. Run from the repo root:
--   lune run tools/rally [matches per pair, default 40]

local process = require("@lune/process")
local loader = require("../tests/loader")
local Sim = require("../tests/Sim")(loader)

local perPair = tonumber(process.args[1]) or 40
local pairs_ = {
	{ "Easy", "Easy" },
	{ "Normal", "Normal" },
	{ "Hard", "Hard" },
	{ "Normal", "Easy" },
	{ "Hard", "Normal" },
	{ "Hard", "Easy" },
}

print(string.format("%-14s %8s %8s %8s %8s", "pair", "shots/pt", "1st win", "miss:tm", "miss:rch"))
local seed = 1000
for _, pr in pairs_ do
	local shots, points, wins, timing, reach = 0, 0, 0, 0, 0
	for n = 1, perPair do
		seed += 1
		-- swap sides every other match so serving first does not skew it
		local flip = n % 2 == 0
		local profiles = if flip then { pr[2], pr[1] } else { pr[1], pr[2] }
		local m, _, st = Sim.play({ profiles = profiles, loadouts = { {}, {} }, seed = seed })
		local a = if flip then 2 else 1
		shots += st.shots
		points += st.points
		timing += st.misses.timing
		reach += st.misses.reach
		if m.games[a] > m.games[3 - a] then
			wins += 1
		end
	end
	print(
		string.format(
			"%-14s %8.1f %7.0f%% %7.0f%% %7.0f%%",
			pr[1] .. "-" .. pr[2],
			shots / points,
			100 * wins / perPair,
			100 * timing / points,
			100 * reach / points
		)
	)
end
