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
			"there are 15 abilities with the costs from the spec (four added after launch, three in the shop)",
			function()
				expect(#Abilities.List).toBe(15)
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
				expect(costs.Zigzag).toBe(3)
				expect(costs.QuantumStop).toBe(4)
				expect(costs.Meteor).toBe(4)
				expect(costs.EMP).toBe(3)
				expect(costs.Feint).toBe(3)
				expect(costs.SpinKick).toBe(4)
				expect(costs.Drain).toBe(2)
				local paid = {}
				for _, d in Abilities.List do
					if d.paid then
						table.insert(paid, d.id)
					end
				end
				expect(table.concat(paid, ",")).toBe("Feint,SpinKick,Drain")
			end,
		},
		{
			"shop abilities can only be brought by players who bought them",
			function()
				expect(table.concat(Abilities.sanitize({ "Feint", "Smash" }), ",")).toBe("Smash")
				expect(table.concat(Abilities.sanitize({ "Drain" }), ",")).toBe("Curve,Barrier")
				local owned = { ability_Feint = true }
				expect(table.concat(Abilities.sanitize({ "Feint", "Drain", "Smash" }, owned), ",")).toBe("Feint,Smash")
				expect(Abilities.usable("Smash", nil)).toBe(true)
				expect(Abilities.usable("SpinKick", owned)).toBe(false)
			end,
		},
		{
			"a Feint heads the wrong way, cuts back after the bounce, stays on the table and ends where aimed",
			function()
				for _, aim in { -5, -2, 0, 2, 5 } do
					local from = Vector3.new(-Config.HitX, Config.HitY, -aim / 2)
					local plain = Trajectory.plan(from, -1, aim, "Good", 0)
					local feint = Trajectory.plan(from, -1, aim, "Good", 0, "Feint")
					local f = feint.effects.feint
					expect(f ~= nil).toBeTruthy()
					if aim ~= 0 then
						-- it leans away from where it is really going
						expect(f * aim < 0).toBeTruthy()
					end
					local b = Trajectory.bouncePoint(feint)
					expect(math.abs(b.Z) <= Config.Table.halfWidth).toBeTruthy()
					expect(math.abs(b.Z - Trajectory.bouncePoint(plain).Z)).toBeNear(math.abs(f), 1e-6)
					expect(Trajectory.positionAt(feint, Trajectory.arrivalTime(feint)).Z).toBeNear(feint.to.Z, 1e-6)
					expect(Trajectory.arrivalTime(feint)).toBeNear(Trajectory.arrivalTime(plain), 1e-6)
				end
			end,
		},
		{
			"a Spin Kick bounces late and comes fast after the bounce, with narrower timing windows",
			function()
				local from = Vector3.new(-Config.HitX, Config.HitY, 0)
				local plain = Trajectory.plan(from, -1, 1, "Good", 0)
				local kick = Trajectory.plan(from, -1, 1, "Good", 0, "SpinKick")
				expect(kick.bounceFraction).toBe(Abilities.Tuning.SpinKick.bounceAt)
				expect(Trajectory.bounceTime(kick) > Trajectory.bounceTime(plain)).toBeTruthy()
				expect(Trajectory.arrivalTime(kick)).toBeNear(Trajectory.arrivalTime(plain), 1e-6)
				expect(Trajectory.windowScale(kick)).toBe(Abilities.Tuning.SpinKick.window)
				expect(math.abs(Trajectory.bouncePoint(kick).Z) <= Config.Table.halfWidth).toBeTruthy()
			end,
		},
		{
			"Rift Drain steals the opponent's gauge, and fires by itself once they have enough",
			function()
				local m = rallyWith({ "Drain" }, {})
				m.gauge = { 2, 6 }
				local events = m:useAbility(1, 1, m.shot.startTime + 0.1)
				local used = find(events, "Ability")
				expect(used.state).toBe("used")
				expect(used.target).toBe(2)
				expect(used.taken).toBe(Abilities.Tuning.Drain.amount)
				expect(m.gauge[2]).toBe(6 - Abilities.Tuning.Drain.amount)
				expect(used.targetGauge).toBe(m.gauge[2])
				expect(m.gauge[1]).toBe(2 + Abilities.Tuning.Drain.amount - 2)
				-- automatic: not while the opponent is low, then as soon as they have enough
				local auto = Match.new(0, 1, { { "Drain" }, {} }, { auto = true })
				auto:serve(auto.nextServeAt, 0, 0)
				auto.gauge = { 5, Abilities.Tuning.Drain.minimum - 1 }
				expect(#auto:autoUse(1, auto.shot.startTime + 0.1, 0)).toBe(0)
				auto.gauge[2] = Abilities.Tuning.Drain.minimum
				expect(find(auto:autoUse(1, auto.shot.startTime + 0.1, 0), "Ability").id).toBe("Drain")
				expect(auto.gauge[2]).toBe(0)
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
				-- a 0.12s late swing is Good on a normal ball but Weak on a Smash
				local m = rallyWith({}, { "Smash" })
				m.shot = smash
				m.receiver = 2
				local events = m:swing(2, Trajectory.arrivalTime(smash) + 0.12, 0, smash.to.Z)
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
				-- 2.3 times wider, a little less as the rally has sped up
				local back = find(events, "Shot").shot
				expect(Trajectory.windowScale(back)).toBeNear(2.3 * (1 - (back.pace or 0) * Config.Pace.window), 1e-9)
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
				expect(m:useAbility(1, 1, 100)[1].reason).toBe("notRally") -- Blink is instant
			end,
		},
		{
			"a shot ability can be armed between points and fires on the next return",
			function()
				-- player 2 has Curve and full gauge; the match has not started yet (waiting to serve)
				local m = Match.new(0, 1, { {}, { "Curve", "Blink" } })
				m.gauge = { Config.Gauge.max, Config.Gauge.max }
				expect(m.phase).toBe("Paused")
				local armed = m:useAbility(2, 1, 0.5)
				expect(armed[1].state).toBe("armed")
				-- an instant ability still needs a rally
				expect(m:useAbility(2, 2, 0.5)[1].reason).toBe("notRally")
				m:serve(m.nextServeAt, 0, 0)
				local events = returnBall(m, 0, 3)
				expect(find(events, "Ability").state).toBe("fired")
				expect(find(events, "Shot").shot.effects.ability).toBe("Curve")
			end,
		},
		{
			"Zigzag swings left and right in flight but still arrives where it was aimed, bouncing on the table",
			function()
				local from = Vector3.new(Config.HitX, Config.HitY, 0)
				local plain = Trajectory.plan(from, 1, 2, "Good", 0)
				local zig = Trajectory.plan(from, 1, 2, "Good", 0, "Zigzag")
				expect(zig.effects.zigzag ~= nil).toBeTruthy()
				expect(math.abs(Trajectory.positionAtProgress(zig, 1).Z - plain.to.Z) < 1e-6).toBeTruthy()
				local swung = 0
				for k = 1, 9 do
					local s = k / 10
					swung = math.max(
						swung,
						math.abs(Trajectory.positionAtProgress(zig, s).Z - Trajectory.positionAtProgress(plain, s).Z)
					)
				end
				expect(swung > 0.5).toBeTruthy()
				expect(math.abs(Trajectory.bouncePoint(zig).Z) <= Config.Table.halfWidth).toBeTruthy()
				expect(Trajectory.arrivalTime(zig)).toBe(Trajectory.arrivalTime(plain))
			end,
		},
		{
			"Quantum Stop holds the ball over the net, then it flies on and arrives later by the stop",
			function()
				local from = Vector3.new(Config.HitX, Config.HitY, 0)
				local plain = Trajectory.plan(from, 1, 0, "Good", 0)
				local stop = Trajectory.plan(from, 1, 0, "Good", 0, "QuantumStop")
				local t = Abilities.Tuning.QuantumStop
				local a, b = stop.effects.stallStart :: number, stop.effects.stallEnd :: number
				expect(b - a).toBeNear(t.length, 1e-9)
				-- almost still during the stop, near the net
				local p1, p2 = Trajectory.positionAt(stop, a + 0.01), Trajectory.positionAt(stop, b - 0.01)
				expect((p2 - p1).Magnitude < 0.6).toBeTruthy()
				expect(math.abs(p1.X) < 1.5).toBeTruthy()
				local late = Trajectory.arrivalTime(stop) - Trajectory.arrivalTime(plain)
				expect(math.abs(late - t.length * (1 - t.factor)) < 1e-6).toBeTruthy()
				-- a Time Slow on it starts after the stop, never on top of it
				local slowed = Trajectory.withSlow(stop, a, 2, 0.5)
				expect(slowed.effects.slowStart).toBe(b)
				expect(Trajectory.arrivalTime(slowed) > Trajectory.arrivalTime(stop)).toBeTruthy()
				expect(math.abs(Trajectory.progressAt(slowed, Trajectory.arrivalTime(slowed)) - 1) < 1e-6).toBeTruthy()
			end,
		},
		{
			"Meteor Drop goes much higher, still clears the net, and narrows the timing window",
			function()
				local from = Vector3.new(Config.HitX, Config.HitY, 0)
				local plain = Trajectory.plan(from, 1, 0, "Good", 0)
				local met = Trajectory.plan(from, 1, 0, "Good", 0, "Meteor")
				expect(met.arc1 > plain.arc1 * 2).toBeTruthy()
				expect(Trajectory.heightOverNet(met) > Trajectory.heightOverNet(plain)).toBeTruthy()
				expect(Trajectory.windowScale(met)).toBe(Abilities.Tuning.Meteor.window)
			end,
		},
		{
			"EMP jams the opponent for a while and costs 3 gauge; a jammed bot times balls worse",
			function()
				local m = rallyWith({}, { "EMP" })
				local t = m.shot.startTime + 0.1
				local events = m:useAbility(2, 1, t)
				local used = find(events, "Ability")
				expect(used.state).toBe("used")
				expect(used.target).toBe(1)
				expect(used.untilTime).toBe(t + Abilities.Tuning.EMP.length)
				expect(m.gauge[2]).toBe(Config.Gauge.max - 3)
				-- the same ball, read by a calm bot and a jammed one: the jammed one is further off
				local Bot = Rally.Bot
				local shot = Trajectory.plan(Vector3.new(Config.HitX, Config.HitY, 0), 1, 0, "Good", 10)
				local function spread(jam)
					local total, n = 0, 0
					for seed = 1, 200 do
						local r = Sim.rng(seed * 7919 + 104729) -- small seeds start with tiny numbers
						local b = Bot.new("Normal", -1, r, {})
						if jam then
							b:jam(100)
						end
						b:watch(shot)
						if b.swingAt then
							total += math.abs(b.swingAt - Trajectory.arrivalTime(shot))
							n += 1
						end
					end
					return total / math.max(n, 1)
				end
				expect(spread(true) > spread(false)).toBeTruthy()
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
			"with auto on, a shot ability fires by itself once the gauge covers it, and the other is next",
			function()
				local m = Match.new(0, 1, { {}, { "Curve", "GravityWell" } }, { auto = true })
				m:serve(m.nextServeAt, 0, 0)
				m.gauge[2] = 0
				expect(find(returnBall(m, 0), "Ability")).toBe(nil) -- 2 of 3
				returnBall(m, 0)
				local fired = find(returnBall(m, 0), "Ability")
				expect(fired.id).toBe("Curve")
				expect(fired.state).toBe("fired")
				expect(fired.nextSlot).toBe(2)
				-- one per rally: Gravity Well waits for the next one even with a full gauge
				m.gauge[2] = 10
				expect(#m:autoUse(2, m.shot.startTime + 0.1, 0)).toBe(0)
				m.usedThisRally[2] = false
				expect(m:autoUse(2, m.shot.startTime + 0.1, 0)[1].id).toBe("GravityWell")
				expect(m.nextSlot[2]).toBe(1)
			end,
		},
		{
			"with auto on, Blink jumps just far enough, only for a ball out of reach, and is not player activity",
			function()
				local m = Match.new(0, 1, { {}, { "Blink" } }, { auto = true })
				m:serve(m.nextServeAt, 0, 0)
				m.gauge[2] = 10
				m.idle[2] = 1
				local t = Trajectory.arrivalTime(m.shot) - 0.1
				expect(#m:autoUse(2, t, m.shot.to.Z)).toBe(0)
				local e = m:autoUse(2, t, m.shot.to.Z - 4)[1]
				expect(e.id).toBe("Blink")
				expect(e.dirZ).toBe(1)
				expect(e.distance).toBeNear(4, 1e-9)
				expect(m.idle[2]).toBe(1)
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
