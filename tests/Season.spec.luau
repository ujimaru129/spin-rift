local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

return function(loader, expect)
	local Season = loader.require("src/shared/Season")
	local Rally = loader.require("src/shared/Rally")
	local Arenas, Cosmetics, BattlePass = Season.Arenas, Season.Cosmetics, Season.BattlePass
	local Config, Trajectory, Match = Rally.Config, Rally.Trajectory, Rally.Match

	return {
		{
			"the pass has 30 levels of 400 XP",
			function()
				expect(BattlePass.level(0)).toBe(0)
				expect(BattlePass.level(399)).toBe(0)
				expect(BattlePass.level(400)).toBe(1)
				expect(BattlePass.level(999999)).toBe(30)
				local into, need = BattlePass.progress(1000)
				expect(into).toBe(200)
				expect(need).toBe(400)
				local _, atMax = BattlePass.progress(12000)
				expect(atMax).toBe(0)
			end,
		},
		{
			"XP: win 120, loss 60, first win of the day +200, nothing from the wall or tutorial",
			function()
				local day = 20000 * 86400 + 3600
				expect((BattlePass.xpFor("Ranked", true, day, 19999))).toBe(320)
				expect((BattlePass.xpFor("Ranked", true, day, 20000))).toBe(120)
				expect((BattlePass.xpFor("Online", false, day, 0))).toBe(60)
				expect((BattlePass.xpFor("Wall", true, day, 0))).toBe(0)
				expect((BattlePass.xpFor("Tutorial", true, day, 0))).toBe(0)
			end,
		},
		{
			"rewards: 6 free, 15 premium, all real cosmetics, none twice",
			function()
				local seen = {}
				local free, premium = 0, 0
				for lv, id in BattlePass.Free do
					free += 1
					expect(Cosmetics.get(id) ~= nil).toBeTruthy()
					expect(seen[id]).toBe(nil)
					seen[id] = true
				end
				for lv, id in BattlePass.Premium do
					premium += 1
					expect(Cosmetics.get(id) ~= nil).toBeTruthy()
					expect(seen[id]).toBe(nil)
					seen[id] = true
				end
				expect(free).toBe(6)
				expect(premium).toBe(15)
				expect(#BattlePass.rewardsUpTo(30, true)).toBe(21)
				expect(#BattlePass.unclaimed(10, false, { title_rookie = true })).toBe(1)
			end,
		},
		{
			"you can only equip what you own, in the right slot",
			function()
				local owned = { paddle_cyan = true, trail_fire = true }
				expect(Cosmetics.canEquip(owned, "trail", "trail_fire")).toBe(true)
				expect(Cosmetics.canEquip(owned, "paddle", "trail_fire")).toBe(false)
				expect(Cosmetics.canEquip(owned, "trail", "trail_gold")).toBe(false)
				expect(Cosmetics.canEquip(owned, "trail", "")).toBe(true)
				expect(Cosmetics.canEquip(owned, "paddle", "")).toBe(false)
			end,
		},
		{
			"Sakura Float unlocks at Bronze I, and ranked uses an arena both players have",
			function()
				expect(Arenas.unlocked("Rooftop", 0)).toBe(true)
				expect(Arenas.unlocked("Sakura", 1033)).toBe(false)
				expect(Arenas.unlocked("Sakura", 1034)).toBe(true)
				local Rating = loader.require("src/shared/Rank").Rating
				local sakura = Arenas.get("Sakura") :: any
				expect(Rating.tier(sakura.unlockRating).label).toBe("ブロンズ I")
				expect(Rating.tier(sakura.unlockRating - 1).label).toBe("ブロンズ II")
				expect(table.concat(Arenas.shared(1200, 1000), ",")).toBe("Rooftop")
				expect(table.concat(Arenas.shared(1200, 1300), ",")).toBe("Rooftop,Sakura")
			end,
		},
		{
			"wind pushes the ball sideways but it still lands on the table and ends where it says",
			function()
				for t = 0, 60, 0.7 do
					local w = Arenas.windAt(t)
					expect(math.abs(w) <= Arenas.WIND_MAX).toBeTruthy()
					for _, aim in { -4, 0, 4 } do
						local shot =
							Trajectory.plan(Vector3.new(-Config.HitX, Config.HitY, 0), -1, aim, "Good", t, nil, w)
						local b = Trajectory.bouncePoint(shot)
						if math.abs(b.Z) > Config.Table.halfWidth then
							error(`wind {w} aim {aim}: bounce off the table at {b.Z}`)
						end
						expect(Trajectory.positionAt(shot, Trajectory.arrivalTime(shot)).Z).toBeNear(shot.to.Z, 1e-6)
					end
				end
				local still = Trajectory.plan(Vector3.new(-Config.HitX, Config.HitY, 0), -1, 2, "Good", 0, nil, 0.8)
				expect(still.to.Z).toBeNear(2.8, 1e-6)
			end,
		},
		{
			"a match with wind uses it for every shot; without wind none",
			function()
				local m = Match.new(0, 1, nil, {
					windAt = function()
						return 0.5
					end,
				})
				local events = m:serve(m.nextServeAt, 0, 0)
				expect(events[1].shot.effects.wind).toBe(0.5)
				local calm = Match.new(0, 1)
				expect(calm:serve(calm.nextServeAt, 0, 0)[1].shot.effects.wind).toBe(nil)
			end,
		},
	}
end
