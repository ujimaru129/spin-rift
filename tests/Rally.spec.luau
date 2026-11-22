local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

return function(loader, expect)
	local Rally = loader.require("src/shared/Rally")
	local Config, Trajectory, Judge, Match, Bot = Rally.Config, Rally.Trajectory, Rally.Judge, Rally.Match, Rally.Bot

	-- Small deterministic RNG (Lune has no Roblox `Random`).
	local function rng(seed: number)
		local state = seed
		return function(lo: number, hi: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return lo + (hi - lo) * state / 2147483648
		end
	end

	local netTop = Config.Table.surfaceY + Config.Table.netHeight + Config.Ball.radius

	local function serveAndGetShot(m, now)
		local events = m:serve(now, 0, 0)
		return events[1].shot
	end

	-- Plays the receiver's swing at arrival + offset, standing exactly where the ball comes.
	local function returnBall(m, offset, aimZ)
		local shot = m.shot
		return m:swing(m.receiver, Trajectory.arrivalTime(shot) + offset, aimZ or 0, shot.to.Z)
	end

	-- Lets the receiver miss so the hitter wins the point; returns the events.
	local function letPass(m)
		return m:update(Trajectory.arrivalTime(m.shot) + Config.Timing.weak + Config.MissGrace + 0.01)
	end

	local function winPoint(m, winner, now)
		now = math.max(now, m.nextServeAt)
		serveAndGetShot(m, now)
		if m.receiver == winner then
			returnBall(m, 0)
		end
		-- now the ball is heading to the loser
		letPass(m)
		return m.nextServeAt
	end

	return {
		{
			"a shot starts at the paddle, bounces on the far half and ends at the other paddle",
			function()
				local from = Vector3.new(-Config.HitX, Config.HitY, 1)
				local shot = Trajectory.plan(from, -1, 2, "Good", 10)
				expect(Trajectory.positionAt(shot, 10).X).toBeNear(-Config.HitX, 1e-6)
				local b = Trajectory.positionAt(shot, Trajectory.bounceTime(shot))
				expect(b.Y).toBeNear(Config.Table.surfaceY + Config.Ball.radius, 1e-6)
				expect(b.X > 0).toBeTruthy()
				expect(b.X < Config.Table.halfLength).toBeTruthy()
				local e = Trajectory.positionAt(shot, Trajectory.arrivalTime(shot))
				expect(e.X).toBeNear(Config.HitX, 1e-6)
				expect(e.Z).toBeNear(2, 1e-6)
			end,
		},
		{
			"every shot kind clears the net, even aimed at a far corner",
			function()
				for _, kind in { "Serve", "Perfect", "Good", "Weak" } do
					for _, side in { -1, 1 } do
						for _, z in { -5, 0, 5 } do
							local from = Vector3.new(side * Config.HitX, Config.HitY, -z)
							local shot = Trajectory.plan(from, side, z, kind, 0)
							if Trajectory.heightOverNet(shot) < netTop then
								error(`{kind} from side {side} to z={z} hits the net`)
							end
						end
					end
				end
			end,
		},
		{
			"aim is clamped inside the side lines",
			function()
				local shot = Trajectory.plan(Vector3.new(-Config.HitX, Config.HitY, 0), -1, 99, "Good", 0)
				expect(shot.to.Z).toBe(Config.Table.halfWidth - Config.AimMargin)
				expect(math.abs(shot.bounce.Z) <= Config.Table.halfWidth).toBeTruthy()
			end,
		},
		{
			"a perfect return is faster than a weak one",
			function()
				local from = Vector3.new(-Config.HitX, Config.HitY, 0)
				local fast = Trajectory.plan(from, -1, 0, "Perfect", 0)
				local slow = Trajectory.plan(from, -1, 0, "Weak", 0)
				expect(Trajectory.speed(fast) > Trajectory.speed(slow)).toBeTruthy()
			end,
		},
		{
			"timing windows grade swings",
			function()
				expect(Judge.grade(0)).toBe("Perfect")
				expect(Judge.grade(-0.05)).toBe("Perfect")
				expect(Judge.grade(0.1)).toBe("Good")
				expect(Judge.grade(-0.2)).toBe("Weak")
				expect(Judge.grade(0.3)).toBe("Miss")
			end,
		},
		{
			"reported swing times are clamped to what the server could have received",
			function()
				expect(Judge.trustedSwingTime(100.2, 100)).toBe(100) -- from the future
				expect(Judge.trustedSwingTime(99.9, 100)).toBeNear(99.9, 1e-9)
				expect(Judge.trustedSwingTime(90, 100)).toBeNear(100 - Config.MaxReportedLag, 1e-9)
			end,
		},
		{
			"cannot serve before the pause ends",
			function()
				local m = Match.new(0)
				expect(#m:serve(0.5, 0, 0)).toBe(0)
				expect(#m:serve(m.nextServeAt, 0, 0)).toBe(1)
				expect(m.phase).toBe("Rally")
			end,
		},
		{
			"a perfect return sends a Perfect shot back and adds 2 gauge",
			function()
				local m = Match.new(0)
				serveAndGetShot(m, m.nextServeAt)
				local events = returnBall(m, 0.02, 3)
				expect(events[1].grade).toBe("Perfect")
				expect(events[2].shot.kind).toBe("Perfect")
				expect(events[2].shot.hitterSide).toBe(1)
				expect(m.gauge[2]).toBe(2)
				expect(m.receiver).toBe(1)
			end,
		},
		{
			"only the receiver can swing, and very early swings are ignored",
			function()
				local m = Match.new(0)
				local shot = serveAndGetShot(m, m.nextServeAt)
				expect(#m:swing(1, Trajectory.arrivalTime(shot), 0, 0)).toBe(0)
				expect(#m:swing(2, Trajectory.arrivalTime(shot) - 0.8, 0, 0)).toBe(0)
				expect(m.phase).toBe("Rally")
			end,
		},
		{
			"a whiff inside the window loses the point",
			function()
				local m = Match.new(0)
				serveAndGetShot(m, m.nextServeAt)
				local events = returnBall(m, -0.3)
				expect(events[1].grade).toBe("Miss")
				expect(events[2].kind).toBe("Point")
				expect(events[2].winner).toBe(1)
				expect(events[2].reason).toBe("whiff")
			end,
		},
		{
			"standing too far away loses the point even with perfect timing",
			function()
				local m = Match.new(0)
				local shot = serveAndGetShot(m, m.nextServeAt)
				local events = m:swing(2, Trajectory.arrivalTime(shot), 0, shot.to.Z + Config.Reach + 1)
				expect(events[2].reason).toBe("reach")
				expect(m.points[1]).toBe(1)
			end,
		},
		{
			"letting the ball pass gives the point to the hitter",
			function()
				local m = Match.new(0)
				serveAndGetShot(m, m.nextServeAt)
				returnBall(m, 0) -- player 2 returns
				local events = letPass(m) -- player 1 misses
				expect(events[1].winner).toBe(2)
				expect(events[1].reason).toBe("miss")
				expect(m.phase).toBe("Paused")
			end,
		},
		{
			"serve changes every 2 points",
			function()
				local m = Match.new(0)
				local now = 0
				local servers = {}
				for _ = 1, 5 do
					table.insert(servers, m.server)
					now = winPoint(m, 1, now)
				end
				expect(table.concat(servers, ",")).toBe("1,1,2,2,1")
			end,
		},
		{
			"7 points wins a game, and from 6-6 a 2-point lead is needed with serve alternating every point",
			function()
				local m = Match.new(0)
				local now = 0
				for _ = 1, 6 do
					now = winPoint(m, 1, now)
					now = winPoint(m, 2, now)
				end
				expect(m.points[1]).toBe(6)
				expect(m.points[2]).toBe(6)
				local s1 = m.server
				now = winPoint(m, 1, now) -- 7-6, not a game yet
				expect(m.games[1]).toBe(0)
				expect(m.server ~= s1).toBeTruthy()
				now = winPoint(m, 1, now) -- 8-6
				expect(m.games[1]).toBe(1)
				expect(m.points[1]).toBe(0)
				expect(m.server).toBe(2) -- the other player serves first in game 2
			end,
		},
		{
			"two games win the match",
			function()
				local m = Match.new(0)
				local now = 0
				local last
				for _ = 1, 14 do
					if m.phase == "Over" then
						break
					end
					now = winPoint(m, 2, now)
				end
				expect(m.phase).toBe("Over")
				expect(m.winner).toBe(2)
				expect(m.games[2]).toBe(2)
				expect(#m:serve(now + 100, 0, 0)).toBe(0)
				last = m:snapshot()
				expect(last.games[2]).toBe(2)
			end,
		},
		{
			"gauge is capped at the maximum",
			function()
				local m = Match.new(0)
				serveAndGetShot(m, m.nextServeAt)
				for _ = 1, 20 do
					returnBall(m, 0)
				end
				expect(m.gauge[1]).toBe(Config.Gauge.max)
				expect(m.gauge[2]).toBe(Config.Gauge.max)
			end,
		},
		{
			"the practice wall never misses and returns Good balls",
			function()
				local m = Match.new(0, 2)
				local wall = Bot.new("Wall", 1, rng(1))
				local now = m.nextServeAt
				for _, e in m:serve(now, 0, 0) do
					if e.kind == "Shot" then
						wall:watch(e.shot)
					end
				end
				-- the wall served; the player returns every ball perfectly for a long rally
				for _ = 1, 30 do
					local shot = m.shot
					if shot.hitterSide == 1 then
						for _, e in returnBall(m, 0) do
							if e.kind == "Shot" then
								wall:watch(e.shot)
							end
						end
					else
						local t = now
						local swingAt
						while not swingAt do
							t += 1 / 60
							swingAt = wall:step(1 / 60, t)
						end
						local events = m:swing(2, swingAt, wall.aimZ, wall.z)
						expect(events[1].grade).toBe("Good")
						wall:watch(events[2].shot)
						now = swingAt
					end
				end
				expect(m.phase).toBe("Rally")
				expect(m.points[1] + m.points[2]).toBe(0)
			end,
		},
		{
			"bot vs bot matches always finish with a legal score",
			function()
				for seed = 1, 20 do
					local random = rng(seed)
					local m = Match.new(0)
					local bots = { Bot.new("Normal", -1, random), Bot.new("Hard", 1, random) }
					local now = 0
					local dt = 1 / 60
					local steps = 0
					while m.phase ~= "Over" do
						steps += 1
						if steps > 60 * 60 * 30 then
							error("match did not finish")
						end
						now += dt
						local events = {}
						if m:canServe(now) then
							local b = bots[m.server]
							events = m:serve(now, b.z, b:pickAim())
						end
						for i, b in bots do
							local at = b:step(dt, now)
							if at then
								for _, e in m:swing(i, at, b.aimZ, b.z) do
									table.insert(events, e)
								end
							end
						end
						for _, e in m:update(now) do
							table.insert(events, e)
						end
						for _, e in events do
							if e.kind == "Shot" then
								bots[1]:watch(e.shot)
								bots[2]:watch(e.shot)
							elseif e.kind == "Point" then
								bots[1]:watch(nil)
								bots[2]:watch(nil)
							end
						end
					end
					local w = m.winner
					local l = Match.other(w)
					expect(m.games[w]).toBe(2)
					expect(m.games[l] <= 1).toBeTruthy()
				end
			end,
		},
		{
			"a swing that arrives late over the network still counts if it was on time",
			function()
				local m = Match.new(0)
				local shot = serveAndGetShot(m, m.nextServeAt)
				local arrival = Trajectory.arrivalTime(shot)
				-- the server ticks while the swing is still in flight
				expect(#m:update(arrival + Config.Timing.weak + 0.05)).toBe(0)
				local received = arrival + 0.3
				local t = Judge.trustedSwingTime(arrival + 0.02, received)
				local events = m:swing(2, t, 0, shot.to.Z)
				expect(events[1].grade).toBe("Perfect")
			end,
		},
		{
			"the reported position is used when it is within walking distance of the server's view",
			function()
				expect(Judge.trustedPlayerZ(2, 0.5, 0.1)).toBe(2)
				expect(Judge.trustedPlayerZ(8, 0.5, 0.1)).toBe(0.5)
				expect(Judge.trustedPlayerZ(nil, 0.5, 0.1)).toBe(0.5)
				expect(Judge.trustedPlayerZ(0 / 0, 0.5, 0.1)).toBe(0.5)
			end,
		},
		{
			"leaving the match gives the win to the other player",
			function()
				local m = Match.new(0)
				local events = m:forfeit(1)
				expect(events[1].kind).toBe("MatchOver")
				expect(events[1].winner).toBe(2)
				expect(events[1].reason).toBe("forfeit")
				expect(m.phase).toBe("Over")
				expect(#m:forfeit(2)).toBe(0)
			end,
		},
		{
			"with 200ms round trip, swings that were on time on the player's screen are never lost",
			function()
				-- Each player sees a shot one-way-delay after the server sent it and swings at the
				-- moment the ball reaches them on their own screen (server clock). The swing then
				-- takes one-way-delay to reach the server.
				local oneWay = 0.1
				local random = rng(7)
				local m = Match.new(0, 1)
				local dt = 1 / 60
				local now = m.nextServeAt
				local pending = {} -- { at = server receive time, player, time, aimZ, z }
				local function onShot(shot)
					local receiver = if shot.hitterSide == -1 then 2 else 1
					-- anywhere from a little early to late-but-legal (the Weak window)
					local swingAt = Trajectory.arrivalTime(shot) + random(-0.05, 0.22)
					table.insert(pending, {
						at = swingAt + oneWay,
						player = receiver,
						time = swingAt,
						aimZ = random(-3, 3),
						z = shot.to.Z,
					})
				end
				for _, e in m:serve(now, 0, 0) do
					if e.kind == "Shot" then
						onShot(e.shot)
					end
				end
				local hits = 0
				while hits < 60 do
					now += dt
					for i = #pending, 1, -1 do
						local p = pending[i]
						if now >= p.at then
							table.remove(pending, i)
							local t = Judge.trustedSwingTime(p.time, now)
							for _, e in m:swing(p.player, t, p.aimZ, p.z) do
								if e.kind == "Shot" then
									hits += 1
									onShot(e.shot)
								elseif e.kind == "Swing" and e.grade == "Miss" then
									error(`swing judged Miss at offset {e.offset}`)
								end
							end
						end
					end
					for _, e in m:update(now) do
						if e.kind == "Point" then
							error(`point lost ({e.reason}) after {hits} hits`)
						end
					end
				end
			end,
		},
	}
end
