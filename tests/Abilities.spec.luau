local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

return function(loader, expect)
	local Rally = loader.require("src/shared/Rally")
	local Config, Trajectory, Match, Abilities = Rally.Config, Rally.Trajectory, Rally.Match, Rally.Abilities
	local Sim = require("./Sim")(loader)

	-- A match in the middle of a rally where player 2 is about to receive, with full gauges.
	local function rallyWith(loadout1, loadout2)
		local m = Match.new(0, 1, { loadout1, loadout2 })
		m:serve(m.nextServeAt, 0, 0)
		m.gauge = { Config.Gauge.max, Config.Gauge.max }
		return m
	end

	local function returnBall(m, offset, aimZ)
		local shot = m.shot
		return m:swing(m.receiver, Trajectory.arrivalTime(shot) + (offset or 0), aimZ or 0, shot.to.Z)
	end

	local function find(events, kind)
		for _, e in events do
			if e.kind == kind then
				return e
			end
		end
		return nil
	end

	return {
		{
			"there are 8 abilities with the costs from the spec",
			function()
				expect(#Abilities.List).toBe(8)
				local costs = {}
				for _, d in Abilities.List do
					costs[d.id] = d.cost
				end
				expect(costs.Curve).toBe(3)
				expect(costs.Smash).toBe(5)
				expect(costs.Phantom).toBe(4)
				expect(costs.Blind).toBe(3)
				expect(costs.TimeSlow).toBe(4)
				expect(costs.Barrier).toBe(8) -- spec said 6; raised in balance tuning
				expect(costs.GravityWell).toBe(3) -- spec said 4; lowered in balance tuning
				expect(costs.Blink).toBe(2)
			end,
		},
		{
			"loadouts keep up to 2 distinct known abilities, otherwise the default",
			function()
				expect(table.concat(Abilities.sanitize({ "Smash", "Smash", "Blink", "Curve" }), ",")).toBe(
					"Smash,Blink"
				)
				expect(table.concat(Abilities.sanitize({ "Nope" }), ",")).toBe("Curve,Barrier")
				expect(table.concat(Abilities.sanitize("Smash"), ",")).toBe("Curve,Barrier")
			end,
		},
		{
			"an armed Curve changes the next return and costs 3 gauge",
			function()
				local m = rallyWith({}, { "Curve" })
				local armed = m:useAbility(2, 1, 1)
				expect(armed[1].state).toBe("armed")
				expect(m.gauge[2]).toBe(10) -- not paid yet
				local events = returnBall(m, 0, 3)
				expect(find(events, "Ability").state).toBe("fired")
				local shot = find(events, "Shot").shot
				expect(shot.effects.ability).toBe("Curve")
				expect(shot.effects.curve < 0).toBeTruthy() -- aimed right, bends left first
				expect(m.gauge[2]).toBe(7) -- +2 for the perfect return is capped at 10, then 3 is paid
			end,
		},
		{
			"a curved shot still lands on the table and ends where it was aimed",
			function()
				for _, z in { -4, -2, 0, 2, 4 } do
					for _, fromZ in { -4, 0, 4 } do
						local shot =
							Trajectory.plan(Vector3.new(-Config.HitX, Config.HitY, fromZ), -1, z, "Good", 0, "Curve")
						local b = Trajectory.bouncePoint(shot)
						if math.abs(b.Z) > Config.Table.halfWidth then
							error(`curve from {fromZ} to {z} bounces off the table at z={b.Z}`)
						end
						expect(Trajectory.positionAt(shot, Trajectory.arrivalTime(shot)).Z).toBeNear(shot.to.Z, 1e-6)
					end
				end
			end,
		},
		{
			"Lightning Smash is 1.6x faster and narrows the receiver's timing windows",
			function()
				local from = Vector3.new(-Config.HitX, Config.HitY, 0)
				local normal = Trajectory.plan(from, -1, 0, "Perfect", 0)
				local smash = Trajectory.plan(from, -1, 0, "Perfect", 0, "Smash")
				expect(normal.duration / smash.duration).toBeNear(1.6, 1e-6)
				expect(Trajectory.heightOverNet(smash) >= Config.Table.surfaceY + Config.Table.netHeight).toBeTruthy()
				-- a 0.1s late swing is Good on a normal ball but Weak on a Smash
				local m = rallyWith({}, { "Smash" })
				m.shot = smash
				m.receiver = 2
				local events = m:swing(2, Trajectory.arrivalTime(smash) + 0.1, 0, smash.to.Z)
				expect(events[1].grade).toBe("Weak")
			end,
		},
		{
			"Time Slow stretches the flight of the ball coming at you",
			function()
				local m = rallyWith({}, { "TimeSlow" })
				local before = Trajectory.arrivalTime(m.shot)
				local events = m:useAbility(2, 1, 0.3 + m.shot.startTime)
				expect(events[1].state).toBe("used")
				expect(events[2].update).toBe(true)
				local after = Trajectory.arrivalTime(m.shot)
				-- the rest of the flight is shorter than 2s, so all of it runs at half speed
				local left = before - (0.3 + m.shot.startTime)
				expect(after - before).toBeNear(left, 1e-6)
				expect(m.gauge[2]).toBe(10 - 4)
				expect(Trajectory.windowScale(m.shot)).toBeNear(1.3, 1e-9)
			end,
		},
		{
			"Time Slow only works on a ball coming at you",
			function()
				local m = rallyWith({ "TimeSlow" }, {})
				local events = m:useAbility(1, 1, m.shot.startTime + 0.1)
				expect(events[1].kind).toBe("AbilityDenied")
				expect(events[1].reason).toBe("noBall")
			end,
		},
		{
			"Rift Barrier returns a missed ball once, as a weak ball",
			function()
				local m = rallyWith({}, { "Barrier" })
				m:useAbility(2, 1, m.shot.startTime + 0.1)
				expect(m.barrier[2]).toBe(true)
				-- player 2 whiffs: protected, no point
				local miss = returnBall(m, -0.3)
				expect(#miss).toBe(1)
				expect(miss[1].protected).toBe(true)
				expect(#returnBall(m, 0)).toBe(0) -- no second try at the same ball
				local events = m:update(Trajectory.arrivalTime(m.shot))
				expect(events[1].state).toBe("triggered")
				expect(find(events, "Swing").grade).toBe("Barrier")
				expect(find(events, "Shot").shot.kind).toBe("Weak")
				expect(Trajectory.windowScale(find(events, "Shot").shot)).toBe(2.3)
				expect(m.barrier[2]).toBe(false)
				expect(m.points[1] + m.points[2]).toBe(0)
			end,
		},
		{
			"Gravity Well slows the opponent for 4 seconds",
			function()
				local m = rallyWith({ "GravityWell" }, {})
				local t = m.shot.startTime + 0.2
				local events = m:useAbility(1, 1, t)
				expect(events[1].target).toBe(2)
				expect(m:moveFactor(2, t + 1)).toBe(0.5)
				expect(m:moveFactor(2, t + 4.1)).toBe(1)
				expect(m:moveFactor(1, t + 1)).toBe(1)
			end,
		},
		{
			"only one ability per player per rally, and gauge must cover the cost",
			function()
				local m = rallyWith({ "Blink", "GravityWell" }, {})
				local t = m.shot.startTime + 0.1
				expect(m:useAbility(1, 1, t, 1)[1].dirZ).toBe(1)
				local again = m:useAbility(1, 2, t)
				expect(again[1].reason).toBe("used")
				local poor = rallyWith({}, { "Barrier" })
				poor.gauge[2] = 5
				expect(poor:useAbility(2, 1, t)[1].reason).toBe("gauge")
			end,
		},
		{
			"abilities reset when the point ends, and cannot be used between points",
			function()
				local m = rallyWith({ "Blink" }, {})
				m:useAbility(1, 1, m.shot.startTime + 0.1, 1)
				m:update(Trajectory.arrivalTime(m.shot) + 5)
				expect(m.phase).toBe("Paused")
				expect(m.usedThisRally[1]).toBe(false)
				expect(m:useAbility(1, 1, 100)[1].reason).toBe("notRally")
			end,
		},
		{
			"an armed shot ability fizzles if the gauge ran out before the return",
			function()
				local m = rallyWith({}, { "Smash" })
				m:useAbility(2, 1, m.shot.startTime + 0.1)
				m.gauge[2] = 2
				local events = returnBall(m, 0.1)
				expect(find(events, "Ability").state).toBe("fizzled")
				expect(find(events, "Shot").shot.effects.ability).toBe(nil)
			end,
		},
		{
			"bots with abilities play full matches and use every ability",
			function()
				local seen = {}
				for i, def in Abilities.List do
					local other = Abilities.List[(i % #Abilities.List) + 1].id
					local m, used = Sim.play({
						profiles = { "Normal", "Normal" },
						loadouts = { { def.id }, { other } },
						seed = i * 31,
					})
					expect(m.phase).toBe("Over")
					if (used["1:" .. def.id] or 0) > 0 then
						seen[def.id] = true
					end
				end
				for _, def in Abilities.List do
					if not seen[def.id] then
						error(def.id .. " was never used by a bot")
					end
				end
			end,
		},
	}
end
