local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

return function(loader, expect)
	local Rally = loader.require("src/shared/Rally")
	local Config, Trajectory, Judge, Match, Bot = Rally.Config, Rally.Trajectory, Rally.Judge, Rally.Match, Rally.Bot

	-- Small deterministic RNG (Lune has no Roblox `Random`).
	local function rng(seed: number)
		local state = (seed % 2147483646) + 1
		return function(lo: number, hi: number): number
			-- Park-Miller: stays below 2^53, so the arithmetic is exact in doubles
			state = (state * 16807) % 2147483647
			return lo + (hi - lo) * state / 2147483647
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
		local events = letPass(m)
		return m.nextServeAt, events
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
				expect(shot.to.Z).toBe(Config.Shots.Good.aim)
				expect(math.abs(shot.bounce.Z) <= Config.Table.halfWidth).toBeTruthy()
			end,
		},
		{
			"full aim reaches the side line: Perfect in the corner, Good near it",
			function()
				local from = Vector3.new(-Config.HitX, Config.HitY, 0)
				local edge = Config.Table.halfWidth
				local perfect = Trajectory.plan(from, -1, Config.MaxAim, "Perfect", 0)
				local good = Trajectory.plan(from, -1, -Config.MaxAim, "Good", 0)
				expect(perfect.bounce.Z >= edge - Config.BounceMargin - 0.01).toBeTruthy()
				expect(good.bounce.Z <= -(edge - 1.2)).toBeTruthy()
				expect(math.abs(good.bounce.Z) <= edge).toBeTruthy()
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
			"an early whiff is let off once per ball; a second one, or a late one, loses the point",
			function()
				local m = Match.new(0)
				serveAndGetShot(m, m.nextServeAt)
				-- too early: shown as a miss, but the point goes on and you can swing again
				local first = returnBall(m, -0.3)
				expect(#first).toBe(1)
				expect(first[1].grade).toBe("Miss")
				expect(first[1].retry).toBe(true)
				expect(m.phase).toBe("Rally")
				-- the second try hits
				expect(returnBall(m, 0)[1].grade).toBe("Perfect")
				-- next ball (player 1 receives): two early whiffs, the second loses the point
				expect(returnBall(m, -0.3)[1].retry).toBe(true)
				local events = returnBall(m, -0.28)
				expect(events[1].grade).toBe("Miss")
				expect(events[1].retry).toBe(nil)
				expect(events[2].kind).toBe("Point")
				expect(events[2].winner).toBe(2)
				expect(events[2].reason).toBe("whiff")
				-- a late whiff is never let off
				local m2 = Match.new(0)
				serveAndGetShot(m2, m2.nextServeAt)
				local late = returnBall(m2, 0.3)
				expect(late[2].kind).toBe("Point")
				expect(late[2].reason).toBe("whiff")
			end,
		},
		{
			"an early swing from out of reach is let off once too, so you can still get across",
			function()
				local m = Match.new(0)
				local shot = serveAndGetShot(m, m.nextServeAt)
				local far = shot.to.Z + Config.Reach + 1
				local first = m:swing(2, Trajectory.arrivalTime(shot) - 0.3, 0, far)
				expect(first[1].retry).toBe(true)
				expect(first[1].reached).toBe(false)
				expect(m:swing(2, Trajectory.arrivalTime(shot), 0, shot.to.Z)[1].grade).toBe("Perfect")
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
			"a game goes to the set number of points, and from deuce a 2-point lead is needed with serve alternating",
			function()
				local m = Match.new(0)
				local now = 0
				local d = Config.Score.deuceAt
				for _ = 1, d do
					now = winPoint(m, 1, now)
					now = winPoint(m, 2, now)
				end
				expect(m.points[1]).toBe(d)
				expect(m.points[2]).toBe(d)
				local s1 = m.server
				now = winPoint(m, 1, now) -- one ahead: not a game yet
				expect(m.games[1]).toBe(0)
				expect(m.server ~= s1).toBeTruthy()
				now = winPoint(m, 1, now) -- two ahead
				expect(m.games[1]).toBe(1)
				if Config.Score.gamesToWinMatch > 1 then
					expect(m.points[1]).toBe(0)
					expect(m.server).toBe(2) -- the other player serves first in the next game
				else
					expect(m.phase).toBe("Over")
					expect(m.winner).toBe(1)
				end
			end,
		},
		{
			"a match is 5 points; winning the set number of games ends it",
			function()
				expect(Config.Score.pointsToWinGame).toBe(5)
				expect(Config.Score.gamesToWinMatch).toBe(1)
				local m = Match.new(0)
				local now = 0
				local overEvent
				for _ = 1, 40 do
					if m.phase == "Over" then
						break
					end
					local events
					now, events = winPoint(m, 2, now)
					for _, e in events or {} do
						if e.kind == "MatchOver" then
							overEvent = e
						end
					end
				end
				expect(m.phase).toBe("Over")
				expect(m.winner).toBe(2)
				expect(m.games[2]).toBe(Config.Score.gamesToWinMatch)
				expect(#m:serve(now + 100, 0, 0)).toBe(0)
				expect(m:snapshot().games[2]).toBe(Config.Score.gamesToWinMatch)
				if overEvent then
					expect(overEvent.points[2]).toBe(Config.Score.pointsToWinGame)
				end
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
					expect(m.games[w]).toBe(Config.Score.gamesToWinMatch)
					expect(m.games[l] < Config.Score.gamesToWinMatch).toBeTruthy()
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
			"two idle players cannot keep a deuce going forever",
			function()
				local limit = 8
				local m = Match.new(0, 1, nil, { idleLimit = limit })
				local over = nil
				for _ = 1, 100 do
					m:serve(m.nextServeAt, 0, 0, true) -- auto-serves only
					for _, e in m:update(Trajectory.arrivalTime(m.shot) + 1) do
						if e.kind == "MatchOver" then
							over = e
						end
					end
					if over then
						break
					end
				end
				expect(over ~= nil).toBe(true)
				expect(over.reason).toBe("idle")
				expect(m.phase).toBe("Over")
			end,
		},
		{
			"a player who swings, serves or uses an ability is not idle",
			function()
				local m = Match.new(0, 1, nil, { idleLimit = 3 })
				for _ = 1, 10 do
					if m.phase == "Over" then
						break
					end
					if m.server == 1 then
						m:serve(m.nextServeAt, 0, 0) -- player 1 serves by hand
					else
						m:serve(m.nextServeAt, 0, 0, true)
						-- player 1 swings (and misses): still playing
						m:swing(1, Trajectory.arrivalTime(m.shot) + 0.4, 0, 0)
					end
					if m.phase == "Rally" then
						m:update(Trajectory.arrivalTime(m.shot) + 1)
					end
					expect(m.phase ~= "Over" or m.winner == 1).toBe(true)
				end
				expect(m.idle[1]).toBe(0)
			end,
		},
		{
			"without an idle limit (practice, Bot) idle points never end the match early",
			function()
				local m = Match.new(0, 1)
				for _ = 1, 20 do
					m:serve(m.nextServeAt, 0, 0, true)
					m:update(Trajectory.arrivalTime(m.shot) + 1)
				end
				expect(m.phase).toBe("Paused")
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
					-- anywhere from a little early to late-but-legal (the Weak window, which narrows
					-- as the rally speeds up)
					local swingAt = Trajectory.arrivalTime(shot) + random(-0.05, 0.22 * Trajectory.windowScale(shot))
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
