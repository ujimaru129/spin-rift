-- Plays whole Bot vs Bot matches in Lune, the same way MatchService runs them on the server.
-- Used by the tests and by tools/balance.luau to measure how strong each ability is.

return function(loader)
	local Rally = loader.require("src/shared/Rally")
	local Match, Bot = Rally.Match, Rally.Bot

	local Sim = {}

	-- Small deterministic RNG (Lune has no Roblox `Random`).
	function Sim.rng(seed: number)
		local state = (seed % 2147483646) + 1
		return function(lo: number, hi: number): number
			-- Park-Miller: stays below 2^53, so the arithmetic is exact in doubles
			state = (state * 16807) % 2147483647
			return lo + (hi - lo) * state / 2147483647
		end
	end

	export type Options = {
		profiles: { string },
		loadouts: { { string } },
		seed: number,
		dt: number?,
	}

	-- Returns the finished match and counts of abilities used, keyed "player:id".
	function Sim.play(o: Options)
		local random = Sim.rng(o.seed)
		local first = if random(0, 1) < 0.5 then 1 else 2
		local m = Match.new(0, first, o.loadouts)
		local bots = {
			Bot.new(o.profiles[1], -1, random, o.loadouts[1]),
			Bot.new(o.profiles[2], 1, random, o.loadouts[2]),
		}
		local used: { [string]: number } = {}
		local dt = o.dt or 1 / 30
		local now = 0
		local steps = 0
		while m.phase ~= "Over" do
			steps += 1
			if steps > 30 * 60 * 40 then
				error(
					`match did not finish: phase={m.phase} rally={m.rally} points={m.points[1]}-{m.points[2]} games={m.games[1]}-{m.games[2]} shot={m.shot ~= nil}`
				)
			end
			now += dt
			local events = {}
			local function add(list)
				for _, e in list do
					table.insert(events, e)
				end
			end
			if m:canServe(now) then
				local b = bots[m.server]
				add(m:serve(now, b.z, b:pickAim()))
			end
			for i, b in bots do
				local at = b:step(dt, now)
				if at then
					add(m:swing(i, at, b.aimZ, b.z))
				end
				if m.phase == "Rally" then
					local slot, dir = b:think({
						now = now,
						gauge = m.gauge[i],
						used = m.usedThisRally[i],
						armed = m.armed[i],
						barrier = m.barrier[i],
						receiving = m.receiver == i,
						shot = m.shot,
					})
					if slot then
						add(m:useAbility(i, slot, now, dir))
					end
				end
			end
			add(m:update(now))
			for _, e in events do
				if e.kind == "Shot" then
					bots[1]:watch(e.shot)
					bots[2]:watch(e.shot)
				elseif e.kind == "Point" then
					bots[1]:watch(nil)
					bots[2]:watch(nil)
				elseif e.kind == "Ability" and (e.state == "used" or e.state == "fired") then
					local key = `{e.player}:{e.id}`
					used[key] = (used[key] or 0) + 1
					if e.id == "GravityWell" then
						bots[e.target]:slow(e.untilTime, e.factor)
					elseif e.id == "Blink" then
						bots[e.player]:blink(e.dirZ, e.distance)
					end
				end
			end
		end
		return m, used
	end

	return Sim
end
