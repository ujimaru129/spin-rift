-- Runs the Roblox-side modules (screen UI, ball drawing, arena building) against a fake engine,
-- so mistakes that would only show up as errors in Studio are caught here first.

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

return function(loader, expect)
	local Fake = require("./FakeRoblox")
	local globals = Fake.globals(loader.node("src/shared"))
	loader.setGlobals(globals)

	local Rally = loader.require("src/shared/Rally")
	local Config, Trajectory, Abilities = Rally.Config, Rally.Trajectory, Rally.Abilities
	local Hud = loader.require("src/client/Hud")
	local BallView = loader.require("src/client/BallView")
	local Arena = loader.require("src/server/Arena")

	local function newHud()
		local calls = {}
		local gui = globals.Instance.new("PlayerGui")
		local hud = Hud.new(gui, {
			onMode = function(mode)
				table.insert(calls, "mode:" .. mode)
			end,
			onLeave = function()
				table.insert(calls, "leave")
			end,
			onRetry = function()
				table.insert(calls, "retry")
			end,
			onSwingButton = function()
				table.insert(calls, "swing")
			end,
			onAbility = function(slot)
				table.insert(calls, "ability:" .. slot)
			end,
			onLanguage = function() end,
			onFeedback = function() end,
			onArena = function() end,
			onBuyPremium = function() end,
			onEquip = function(kind, id)
				table.insert(calls, "equip:" .. kind .. ":" .. id)
			end,
		})
		return hud, calls
	end

	return {
		{
			"the HUD builds and every screen can be shown",
			function()
				local hud, calls = newHud()
				hud:showMenu()
				hud:showWaiting()
				hud:showMatch("BOT（ふつう）")
				hud:setSlots({ "Curve", "Barrier" })
				hud:setSlotStates({ "armed", "ready" })
				hud:setSlotStates({ "waiting", "waiting" })
				hud:setScore({ points = { 3, 2 }, games = { 1, 0 }, gauge = { 4, 7 }, server = 2 }, 1)
				for _, g in { "Perfect", "Good", "Weak", "Miss", "Barrier" } do
					hud:popupGrade(g, 0.08)
				end
				hud:popupText("POINT!", Color3 and Color3.new(1, 1, 1) or roblox.Color3.new(1, 1, 1))
				hud:announceAbility("相手：カーブショット！", Hud.abilityColor("Curve"))
				hud:setPing(180)
				hud:setRally(5)
				hud:setHint("あなたのサーブ")
				hud:showResult(true, 2, 1, "相手が退出しました")
				hud:showResult(false, 0, 2)
				hud.slots[2].frame.Activated:Fire()
				expect(calls[#calls]).toBe("ability:2")
			end,
		},
		{
			"picking abilities keeps the 2 most recent, and never empties the loadout",
			function()
				local hud = newHud()
				expect(table.concat(hud:getLoadout(), ",")).toBe("Curve,Barrier")
				hud.pickChips.Smash.Activated:Fire()
				expect(table.concat(hud:getLoadout(), ",")).toBe("Barrier,Smash")
				hud.pickChips.Smash.Activated:Fire()
				expect(table.concat(hud:getLoadout(), ",")).toBe("Barrier")
				hud.pickChips.Barrier.Activated:Fire()
				expect(table.concat(hud:getLoadout(), ",")).toBe("Barrier")
				expect(string.find(hud.pickInfo.Text, "リフトバリア") ~= nil).toBeTruthy()
			end,
		},
		{
			"the ball draws every kind of shot from start to past the paddle",
			function()
				local view = BallView.new()
				local origin = Vector3.new(400, 200, 0)
				view:setOrigin(origin)
				local from = Vector3.new(-Config.HitX, Config.HitY, 1)
				local kinds = { "Serve", "Perfect", "Good", "Weak" }
				for _, def in Abilities.List do
					table.insert(kinds, def.id)
				end
				for _, k in kinds do
					local shot
					if Config.Shots[k] then
						shot = Trajectory.plan(from, -1, 2, k, 10)
					elseif k == "TimeSlow" then
						shot = Trajectory.withSlow(Trajectory.plan(from, -1, 2, "Good", 10), 10.3, 2, 0.5)
					else
						shot = Trajectory.plan(from, -1, 2, "Good", 10, k)
					end
					view:setShot(shot, 10.05)
					local t = 10.05
					local seenHidden, seenGhost = false, false
					while t < Trajectory.arrivalTime(shot) + 0.5 do
						t += 1 / 60
						view:update(t, 1 / 60)
						if view.ball.Transparency == 1 then
							seenHidden = true
						end
						if view.ghosts[1].Transparency < 1 then
							seenGhost = true
						end
					end
					expect(seenHidden).toBe(k == "Blind")
					expect(seenGhost).toBe(k == "Phantom")
					view:hitEffect("Perfect")
					view:lose(t)
					for _ = 1, 60 do
						t += 1 / 60
						view:update(t, 1 / 60)
					end
					expect(view.shot).toBe(nil)
				end
				view:updateShot(Trajectory.plan(from, -1, 0, "Good", 20))
				view:barrierWall(1, roblox.Color3.new(0, 1, 1))
				view:floorRing(-1, roblox.Color3.new(1, 0, 1), 4)
				view:flashAt(origin, roblox.Color3.new(1, 1, 1))
				view:hide()
			end,
		},
		{
			"the arena, the bot avatar and the paddle build",
			function()
				local origin = Vector3.new(400, 200, 0)
				local model = Arena.build(origin, 1)
				expect(#model:GetChildren() > 50).toBeTruthy()
				local bot = Arena.buildOpponent(origin)
				bot:PivotTo(roblox.CFrame.new(origin))
				for _, side in { -1, 1 } do
					local cf = Arena.playerSpawn(origin, side)
					-- faces the table
					expect(cf.LookVector.X * side < 0).toBeTruthy()
				end
				local character = globals.Instance.new("Model")
				local hand = globals.Instance.new("Part", character)
				hand.Name = "RightHand"
				hand.CFrame = roblox.CFrame.new(origin)
				Arena.attachPaddle(character, roblox.Color3.new(0, 1, 1))
				expect(character:FindFirstChild("SpinRiftPaddle") ~= nil).toBeTruthy()
			end,
		},
		{
			"server and client play a whole practice match against a Bot",
			function()
				local Players = globals.game:GetService("Players")
				local RunService = globals.game:GetService("RunService")
				local UserInputService = globals.game:GetService("UserInputService")
				local replicated = globals.game:GetService("ReplicatedStorage")
				Fake.clock.now = 1000

				local nextUserId = 0
				local function makePlayer(name: string)
					local p = globals.Instance.new("Player")
					p.Name = name
					Fake.set(p, { DisplayName = name })
					nextUserId += 1
					Fake.set(p, { UserId = nextUserId })
					globals.Instance.new("PlayerGui", p)
					local character = globals.Instance.new("Model")
					local root = globals.Instance.new("Part", character)
					root.Name = "HumanoidRootPart"
					root.CFrame = roblox.CFrame.new(0, 3, 0)
					local hand = globals.Instance.new("Part", character)
					hand.Name = "RightHand"
					hand.CFrame = roblox.CFrame.new(1, 3, 0)
					local humanoid = globals.Instance.new("Humanoid", character)
					humanoid.WalkSpeed = 16
					Fake.set(humanoid, { MoveDirection = Vector3.new(0, 0, 0) })
					p.Character = character
					p.Parent = Players
					return p, root
				end

				local me, myRoot = makePlayer("Tester")
				Fake.set(Players, { LocalPlayer = me })
				Fake.localPlayer = me
				loader.runScript("src/server/init.server.luau")
				loader.runScript("src/client/init.client.luau")

				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				remotes.RequestMatch:FireServer("Normal", { "Smash", "Blink" })

				local origin
				local incoming = nil -- a shot coming to us
				local serveAt = nil
				local over = nil
				local grades = {}
				local myAbilities = 0
				local function click()
					UserInputService.InputBegan:Fire(
						{ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.F },
						false
					)
				end
				local read = 0
				local dt = 1 / 60
				for _ = 1, 60 * 60 * 15 do
					Fake.clock.now += dt
					RunService.Heartbeat:Fire(dt)
					RunService.RenderStepped:Fire(dt)
					for i = read + 1, #seen do
						local e = seen[i]
						if e.kind == "Start" then
							origin = e.origin
						elseif e.kind == "Shot" then
							incoming = if e.shot.hitterSide == 1 then e.shot else nil
							if incoming then
								-- stand where the ball is going
								myRoot.CFrame = roblox.CFrame.new(origin + Vector3.new(-14, 3.5, incoming.to.Z))
								-- arm Lightning Smash for this return now and then
								if math.random() < 0.3 then
									UserInputService.InputBegan:Fire({
										UserInputType = roblox.Enum.UserInputType.Keyboard,
										KeyCode = roblox.Enum.KeyCode.Q,
									}, false)
								end
							end
						elseif e.kind == "ServeWait" then
							serveAt = if e.server == 1 then e.at else nil
						elseif e.kind == "Swing" and e.player == 1 then
							grades[e.grade] = (grades[e.grade] or 0) + 1
						elseif e.kind == "Ability" and e.player == 1 and e.state == "fired" then
							myAbilities += 1
						elseif e.kind == "MatchOver" then
							over = e
						end
					end
					read = #seen
					if incoming and Fake.clock.now >= Trajectory.arrivalTime(incoming) - 0.005 then
						incoming = nil
						click()
					end
					if serveAt and Fake.clock.now >= serveAt + 0.1 then
						serveAt = nil
						click()
					end
					if over then
						break
					end
				end
				expect(over ~= nil).toBeTruthy()
				expect((grades.Perfect or 0) > 10).toBeTruthy()
				expect(myAbilities > 0).toBeTruthy()
				-- the player swings on time every ball, so they should win against "ふつう"
				expect(over.winner).toBe(1)
				remotes.LeaveMatch:FireServer()
				expect(seen[#seen].kind).toBe("Left")
			end,
		},
		{
			"in a match, the arrow keys move across the table and the controls box shows the keys",
			function()
				local RunService = globals.game:GetService("RunService")
				local UserInputService = globals.game:GetService("UserInputService")
				local remotes = globals.game:GetService("ReplicatedStorage"):FindFirstChild("SpinRiftRemotes")
				local me = Fake.localPlayer
				local humanoid = me.Character:FindFirstChildOfClass("Humanoid")
				local moves = {}
				rawget(humanoid, "__props").Move = function(_, v, relative)
					table.insert(moves, { v = v, relative = relative })
				end
				local started = false
				local conn = remotes.MatchEvent.OnClientEvent:Connect(function(e)
					if e.kind == "Start" then
						started = true
					end
				end)
				remotes.RequestMatch:FireServer("Normal", { "Curve", "Blink" })
				for _ = 1, 10 do
					Fake.clock.now += 1 / 60
					RunService.Heartbeat:Fire(1 / 60)
					RunService.RenderStepped:Fire(1 / 60)
				end
				expect(started).toBe(true)
				-- the arrow key counts even though Roblox's camera marked it as processed
				local right =
					{ KeyCode = roblox.Enum.KeyCode.Right, UserInputType = roblox.Enum.UserInputType.Keyboard }
				UserInputService.InputBegan:Fire(right, true)
				RunService.RenderStepped:Fire(1 / 60)
				expect(#moves > 0).toBeTruthy()
				local v = moves[#moves].v
				expect(math.abs(v.Z) > 0.99 and math.abs(v.X) < 0.01).toBeTruthy()
				expect(moves[#moves].relative).toBe(false)
				-- left goes the other way
				UserInputService.InputEnded:Fire(right, false)
				local left = { KeyCode = roblox.Enum.KeyCode.Left, UserInputType = roblox.Enum.UserInputType.Keyboard }
				UserInputService.InputBegan:Fire(left, true)
				RunService.RenderStepped:Fire(1 / 60)
				expect(math.abs(moves[#moves].v.Z + v.Z) < 0.01).toBeTruthy()
				-- let go: no more arrow moves
				UserInputService.InputEnded:Fire(left, false)
				local count = #moves
				RunService.RenderStepped:Fire(1 / 60)
				expect(#moves).toBe(count)
				-- the how-to-play box is filled in for keyboard players
				local box
				local function find(node)
					for _, d in node:GetChildren() do
						if d.Name == "Controls" then
							box = d
						end
						find(d)
					end
				end
				find(me:FindFirstChildOfClass("PlayerGui"))
				expect(box ~= nil).toBeTruthy()
				expect(string.find(box.Text, "←", 1, true) ~= nil).toBeTruthy()

				-- aiming: the direction held as you hit sets the side; nothing held = straight
				local swings, abilities = {}, {}
				local sConn = remotes.Swing.OnServerEvent:Connect(function(_, _t, aim)
					table.insert(swings, aim)
				end)
				local aConn = remotes.UseAbility.OnServerEvent:Connect(function(_, slot)
					table.insert(abilities, slot)
				end)
				local function press(code)
					local input = { KeyCode = code, UserInputType = roblox.Enum.UserInputType.Keyboard }
					UserInputService.InputBegan:Fire(input, false)
					UserInputService.InputEnded:Fire(input, false)
				end
				local function waitSwingGap()
					Fake.clock.now += 0.2
				end
				-- J hits, with nothing held: straight
				press(roblox.Enum.KeyCode.J)
				expect(swings[#swings]).toBe(0)
				-- holding → while hitting aims to screen-right, the same world side as moving right
				waitSwingGap()
				UserInputService.InputBegan:Fire(right, false)
				press(roblox.Enum.KeyCode.Space)
				UserInputService.InputEnded:Fire(right, false)
				expect(math.abs(swings[#swings]) == 1).toBeTruthy()
				expect(swings[#swings] * v.Z > 0).toBeTruthy()
				-- holding A (Roblox moves us; we only note it) aims the other way
				waitSwingGap()
				local a = { KeyCode = roblox.Enum.KeyCode.A, UserInputType = roblox.Enum.UserInputType.Keyboard }
				UserInputService.InputBegan:Fire(a, false)
				press(roblox.Enum.KeyCode.J)
				UserInputService.InputEnded:Fire(a, false)
				expect(swings[#swings] * v.Z < 0).toBeTruthy()
				-- K and L use abilities 1 and 2, like Q and E
				press(roblox.Enum.KeyCode.K)
				press(roblox.Enum.KeyCode.L)
				expect(abilities[#abilities - 1]).toBe(1)
				expect(abilities[#abilities]).toBe(2)
				sConn:Disconnect()
				aConn:Disconnect()
				conn:Disconnect()
				remotes.LeaveMatch:FireServer()
			end,
		},
		{
			"two players are paired online, and leaving hands the win to the other",
			function()
				local Players = globals.game:GetService("Players")
				local RunService = globals.game:GetService("RunService")
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local me = Fake.localPlayer
				local other = globals.Instance.new("Player")
				other.Name = "Rival"
				Fake.set(other, { DisplayName = "Rival" })
				Fake.set(other, { UserId = 2 })
				local character = globals.Instance.new("Model")
				local root = globals.Instance.new("Part", character)
				root.Name = "HumanoidRootPart"
				root.CFrame = roblox.CFrame.new(0, 3, 0)
				globals.Instance.new("Humanoid", character)
				other.Character = character
				other.Parent = Players

				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				remotes.RequestMatch:FireServer("Online", { "Phantom", "TimeSlow" })
				expect(seen[#seen].kind).toBe("Queued")
				remotes.RequestMatch.OnServerEvent:Fire(other, "Online", { "Curve", "GravityWell" })
				local start
				for _, e in seen do
					if e.kind == "Start" then
						start = e
					end
				end
				expect(start ~= nil).toBeTruthy()
				expect(start.opponent).toBe("Rival")
				expect(table.concat(start.opponentLoadout, ",")).toBe("Curve,GravityWell")
				for _ = 1, 60 * 5 do
					Fake.clock.now += 1 / 60
					RunService.Heartbeat:Fire(1 / 60)
					RunService.RenderStepped:Fire(1 / 60)
				end
				Players.PlayerRemoving:Fire(other)
				local last
				for _, e in seen do
					if e.kind == "MatchOver" then
						last = e
					end
				end
				expect(last ~= nil).toBeTruthy()
				expect(last.reason).toBe("forfeit")
				expect(last.winner).toBe(start.you)
			end,
		},
		{
			"two players in Studio are paired for ranked, play, and both ratings are saved",
			function()
				local Players = globals.game:GetService("Players")
				local RunService = globals.game:GetService("RunService")
				local UserInputService = globals.game:GetService("UserInputService")
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local me = Fake.localPlayer
				local myRoot = me.Character:FindFirstChild("HumanoidRootPart")
				-- "Rival" from the previous test left; bring in a fresh opponent
				local rival = globals.Instance.new("Player")
				rival.Name = "Rookie"
				Fake.set(rival, { DisplayName = "Rookie" })
				Fake.set(rival, { UserId = 3 })
				local character = globals.Instance.new("Model")
				local root = globals.Instance.new("Part", character)
				root.Name = "HumanoidRootPart"
				root.CFrame = roblox.CFrame.new(0, 3, 0)
				globals.Instance.new("Humanoid", character)
				rival.Character = character
				rival.Parent = Players

				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				remotes.Hello:FireServer()
				local profile
				for _, e in seen do
					if e.kind == "Profile" then
						profile = e
					end
				end
				expect(profile.rating).toBe(1000)
				expect(profile.tier).toBe("ブロンズ II")

				remotes.RequestMatch:FireServer("Ranked", { "Curve", "Blink" })
				remotes.RequestMatch.OnServerEvent:Fire(rival, "Ranked", { "Smash", "Barrier" })
				local start, over, result
				local incoming, serveAt
				local read = 0
				for _ = 1, 60 * 60 * 15 do
					Fake.clock.now += 1 / 60
					RunService.Heartbeat:Fire(1 / 60)
					RunService.RenderStepped:Fire(1 / 60)
					for i = read + 1, #seen do
						local e = seen[i]
						if e.kind == "Start" then
							start = e
						elseif e.kind == "Shot" and start then
							incoming = if e.shot.hitterSide ~= start.side then e.shot else nil
							if incoming then
								myRoot.CFrame =
									roblox.CFrame.new(start.origin + Vector3.new(start.side * 14, 3.5, incoming.to.Z))
							end
						elseif e.kind == "ServeWait" and start then
							serveAt = if e.server == start.you then e.at else nil
						elseif e.kind == "MatchOver" then
							over = e
						elseif e.kind == "RankResult" then
							result = e
						end
					end
					read = #seen
					local click =
						{ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.F }
					if incoming and Fake.clock.now >= Trajectory.arrivalTime(incoming) - 0.005 then
						incoming = nil
						UserInputService.InputBegan:Fire(click, false)
					end
					if serveAt and Fake.clock.now >= serveAt + 0.1 then
						serveAt = nil
						UserInputService.InputBegan:Fire(click, false)
					end
					if result then
						break
					end
				end
				expect(start.ranked).toBe(true)
				expect(start.opponent).toBe("Rookie")
				expect(over.winner).toBe(start.you)
				-- first ranked game: placement, so a win against an equal player is worth +40
				expect(result.delta).toBe(40)
				expect(result.after).toBe(1040)
				local saved = Fake.dataStores.PlayerData_v1
				expect(saved["u_" .. me.UserId].rating).toBe(1040)
				expect(saved["u_" .. me.UserId].wins).toBe(1)
				expect(saved.u_3.rating).toBe(960)
				expect(saved.u_3.losses).toBe(1)
				-- the world leaderboard has both
				local board = Fake.dataStores["ordered:Rating_S1_GLOBAL"]
				expect(board[tostring(me.UserId)]).toBe(1040)
				remotes.RequestLeaderboard:FireServer("GLOBAL")
				expect(seen[#seen].kind).toBe("Leaderboard")
				expect(seen[#seen].rows[1].rating).toBe(1040)
				-- both players' waits were logged as matched
				local Analytics = loader.require("src/server/Analytics")
				local matched = 0
				for _, l in Analytics.log do
					if l.name == "RankedWait" and l.fields and l.fields[1] == "matched" then
						matched += 1
						expect(l.fields[2]).toBe("00-10s")
					end
				end
				expect(matched).toBe(2)
				remotes.LeaveMatch:FireServer()
				Players.PlayerRemoving:Fire(rival)
				rival.Parent = nil
			end,
		},
		{
			"a ranked wait is logged with how long it was and how it ended",
			function()
				local Analytics = loader.require("src/server/Analytics")
				local RunService = globals.game:GetService("RunService")
				local remotes = globals.game:GetService("ReplicatedStorage"):FindFirstChild("SpinRiftRemotes")
				local function lastWait()
					for i = #Analytics.log, 1, -1 do
						local l = Analytics.log[i]
						if l.name == "RankedWait" then
							return l
						end
					end
					return nil
				end
				local before = #Analytics.log
				-- nobody else is queued: wait past the bot offer, then take it
				remotes.RequestMatch:FireServer("Ranked", { "Curve", "Blink" })
				for _ = 1, 95 do
					Fake.clock.now += 1
					RunService.Heartbeat:Fire(1)
				end
				remotes.RequestMatch:FireServer("Normal", { "Curve", "Blink" })
				local bot = lastWait()
				expect(bot ~= nil and #Analytics.log > before).toBeTruthy()
				expect(bot.fields[1]).toBe("bot")
				expect(bot.fields[2]).toBe("90s+")
				expect(bot.value).toBe(95)
				remotes.LeaveMatch:FireServer()
				-- queue again and cancel after a short wait
				remotes.RequestMatch:FireServer("Ranked", { "Curve", "Blink" })
				for _ = 1, 12 do
					Fake.clock.now += 1
					RunService.Heartbeat:Fire(1)
				end
				remotes.LeaveMatch:FireServer()
				local cancel = lastWait()
				expect(cancel.fields[1]).toBe("cancel")
				expect(cancel.fields[2]).toBe("10-30s")
				expect(cancel.value).toBe(12)
				-- leaving without being queued logs nothing more
				local count = #Analytics.log
				remotes.LeaveMatch:FireServer()
				expect(#Analytics.log).toBe(count)
			end,
		},
		{
			"in a published game, players in different servers are paired through MemoryStore and teleported",
			function()
				local RankedQueue = loader.require("src/server/RankedQueue")
				local RunService = globals.game:GetService("RunService")
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				RankedQueue.setMode("global")
				globals.game.PlaceId = 123
				-- someone in another server is already waiting
				local queue = globals.game:GetService("MemoryStoreService"):GetSortedMap("RankedQueue_v1")
				queue:SetAsync("99", {
					id = "99",
					userId = 99,
					name = "Faraway",
					rating = 1030,
					games = 4,
					region = "ASIA",
					joinedAt = Fake.clock.now - 5,
					loadout = { "Phantom", "Blink" },
					jobId = "job-other",
				}, 120, 1030)
				remotes.RequestMatch:FireServer("Ranked", { "Curve", "Blink" })
				for _ = 1, 60 * 4 do
					Fake.clock.now += 1 / 60
					RunService.Heartbeat:Fire(1 / 60)
				end
				local teleport = Fake.teleports[#Fake.teleports]
				expect(teleport ~= nil).toBeTruthy()
				expect(teleport.players[1]).toBe(Fake.localPlayer)
				expect(teleport.options.ReservedServerAccessCode).toBe("code" .. Fake.reserved)
				local teleporting = false
				for _, e in seen do
					if e.kind == "Teleporting" then
						teleporting = true
					end
				end
				expect(teleporting).toBe(true)
				-- the reserved server can read who is coming
				local info = RankedQueue.readMatch("private" .. Fake.reserved)
				expect(#info.players).toBe(2)
				-- the other server's player still has an assignment waiting for them
				local assign = globals.game:GetService("MemoryStoreService"):GetSortedMap("RankedAssign_v1")
				expect(assign:GetAsync("99").code).toBe("code" .. Fake.reserved)
				expect(queue:GetAsync("99")).toBe(nil)
				RankedQueue.setMode("local")
				globals.game.PlaceId = 0
			end,
		},
		{
			"a reserved ranked server starts the match when both players arrive",
			function()
				local RankedRoom = loader.require("src/server/RankedRoom")
				local Players = globals.game:GetService("Players")
				local memory = globals.game:GetService("MemoryStoreService"):GetSortedMap("RankedMatch_v1")
				memory:SetAsync("room-1", {
					players = {
						{ id = "1", userId = 1, rating = 1040, games = 1, region = "ASIA", loadout = { "Curve" } },
						{ id = "50", userId = 50, rating = 1000, games = 0, region = "ASIA", loadout = { "Blink" } },
					},
				}, 900)
				globals.game.PrivateServerId = "room-1"
				expect(RankedRoom.isRoom()).toBe(true)
				local started, fired = nil, {}
				RankedRoom.start({
					fire = function(p, e)
						table.insert(fired, e.kind)
					end,
					startRanked = function(players, loadouts, onOver)
						started = { players = players, loadouts = loadouts, onOver = onOver }
					end,
				})
				expect(started).toBe(nil) -- only player 1 is here so far
				local guest = globals.Instance.new("Player")
				Fake.set(guest, { UserId = 50 })
				Fake.set(guest, { DisplayName = "Guest" })
				guest.Parent = Players
				Players.PlayerAdded:Fire(guest)
				expect(started ~= nil).toBeTruthy()
				expect(started.loadouts[2][1]).toBe("Blink")
				-- the guest leaves mid-match: player 1 wins, the guest loses and gets an abandon mark
				started.onOver(1, "forfeit")
				local saved = Fake.dataStores.PlayerData_v1
				expect(saved.u_50.leaves).toBe(1)
				expect(saved.u_50.rating < 1000).toBeTruthy()
				globals.game.PrivateServerId = ""
				guest.Parent = nil
			end,
		},
		{
			"every text has all six languages, and the HUD redraws in English",
			function()
				local S = loader.require("src/shared/Strings")
				local Cosmetics = loader.require("src/shared/Season/Cosmetics")
				local ids = {}
				for _, item in Cosmetics.List do
					table.insert(ids, item.id)
				end
				local missing = S.missing(ids)
				if #missing > 0 then
					error("missing translations: " .. table.concat(missing, ", "))
				end
				expect(S.fromLocaleId("ja-jp")).toBe("ja")
				expect(S.fromLocaleId("en-us")).toBe("en")
				expect(S.fromLocaleId("pt-br")).toBe("pt")
				expect(S.fromLocaleId("fr-fr")).toBe("en")
				S.setLocale("en")
				expect(S.t("hud.rally", { n = 5 })).toBe("Rally 5")
				expect(S.rank("Gold", "II")).toBe("Gold II")
				local hud = newHud()
				expect(string.find(hud.pickInfo.Text, "Curve Shot") ~= nil).toBeTruthy()
				expect(hud.pickChips.Barrier.Text).toBe("Rift Barrier  8")
				S.setLocale("ja")
				hud:relabel()
				expect(hud.pickChips.Barrier.Text).toBe("リフトバリア  8")
				expect(string.find(hud.pickInfo.Text, "カーブショット") ~= nil).toBeTruthy()
			end,
		},
		{
			"the tutorial walks a new player through returns, a PERFECT and an ability",
			function()
				local Analytics = loader.require("src/server/Analytics")
				local RunService = globals.game:GetService("RunService")
				local UserInputService = globals.game:GetService("UserInputService")
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local me = Fake.localPlayer
				local myRoot = me.Character:FindFirstChild("HumanoidRootPart")
				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				remotes.RequestMatch:FireServer("Tutorial", {})
				local start, incoming, serveAt
				local steps = {}
				local read = 0
				local pressedQ = false
				local click =
					{ UserInputType = roblox.Enum.UserInputType.MouseButton1, KeyCode = roblox.Enum.KeyCode.F }
				for _ = 1, 60 * 120 do
					Fake.clock.now += 1 / 60
					RunService.Heartbeat:Fire(1 / 60)
					RunService.RenderStepped:Fire(1 / 60)
					for i = read + 1, #seen do
						local e = seen[i]
						if e.kind == "Start" then
							start = e
						elseif e.kind == "Tutorial" then
							table.insert(steps, e.step)
						elseif e.kind == "Shot" and start then
							incoming = if e.shot.hitterSide ~= start.side then e.shot else nil
							if incoming then
								myRoot.CFrame =
									roblox.CFrame.new(start.origin + Vector3.new(start.side * 14, 3.5, incoming.to.Z))
								if steps[#steps] == "ability" and not pressedQ then
									pressedQ = true
									UserInputService.InputBegan:Fire({
										UserInputType = roblox.Enum.UserInputType.Keyboard,
										KeyCode = roblox.Enum.KeyCode.Q,
									}, false)
								end
							end
						elseif e.kind == "ServeWait" and start then
							serveAt = if e.server == start.you then e.at else nil
						end
					end
					read = #seen
					if incoming and Fake.clock.now >= Trajectory.arrivalTime(incoming) - 0.005 then
						incoming = nil
						UserInputService.InputBegan:Fire(click, false)
					end
					if serveAt and Fake.clock.now >= serveAt + 0.1 then
						serveAt = nil
						UserInputService.InputBegan:Fire(click, false)
					end
					if steps[#steps] == "done" then
						break
					end
				end
				expect(start.opponentMode).toBe("Wall")
				expect(table.concat(steps, ",")).toBe("hit,hit,hit,perfect,ability,done")
				expect(Fake.dataStores.PlayerData_v1["u_" .. me.UserId].tutorialDone).toBe(true)
				local funnel = {}
				for _, l in Analytics.log do
					if l.kind == "funnel" then
						funnel[l.name] = true
					end
				end
				for _, step in
					{ "Joined", "TutorialStarted", "FirstReturn", "FirstPerfect", "FirstAbility", "TutorialDone" }
				do
					if not funnel[step] then
						error("funnel step not logged: " .. step)
					end
				end
				remotes.LeaveMatch:FireServer()
			end,
		},
		{
			"feedback is saved for the developers, at most once a minute per player",
			function()
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				remotes.SendFeedback:FireServer("bug", "サーブのあとにボールが消えた", "ja")
				expect(seen[#seen].kind).toBe("FeedbackResult")
				expect(seen[#seen].status).toBe("ok")
				local stored = nil
				for _, v in Fake.dataStores.Feedback_v1 do
					stored = v
				end
				expect(stored.category).toBe("bug")
				expect(stored.text).toBe("サーブのあとにボールが消えた")
				remotes.SendFeedback:FireServer("fun", "楽しい", "ja")
				expect(seen[#seen].status).toBe("tooSoon")
				remotes.SendFeedback:FireServer("hack", "x", "ja")
				expect(seen[#seen].status).toBe("invalid")
			end,
		},
		{
			"during the closed test only members of the tester group can stay",
			function()
				local ClosedTest = loader.require("src/server/ClosedTest")
				ClosedTest.ENABLED = true
				ClosedTest.GROUP_ID = 777
				Fake.studio = false
				local outsider = globals.Instance.new("Player")
				expect(ClosedTest.admit(outsider)).toBe(false)
				expect(string.find(outsider.__kicked, "クローズドテスト") ~= nil).toBeTruthy()
				expect(string.find(outsider.__kicked, "closed test") ~= nil).toBeTruthy()
				local tester = globals.Instance.new("Player")
				Fake.set(tester, { UserId = 900 })
				tester.__groups = { [777] = 1 }
				expect(ClosedTest.admit(tester)).toBe(true)
				-- testers get a thank-you title
				expect(Fake.dataStores.PlayerData_v1.u_900.items.title_tester).toBe(true)
				Fake.studio = true
				expect(ClosedTest.admit(outsider)).toBe(true) -- Studio is never blocked
				ClosedTest.ENABLED = false
			end,
		},
		{
			"the Battle Pass, Premium and cosmetics work end to end",
			function()
				local Progression = loader.require("src/server/Progression")
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local me = Fake.localPlayer
				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				local function last(kind)
					for i = #seen, 1, -1 do
						if seen[i].kind == kind then
							return seen[i]
						end
					end
					return nil
				end
				-- a win: 120 XP plus the first-win-of-the-day bonus of 200
				local saved = Fake.dataStores.PlayerData_v1["u_" .. me.UserId]
				saved.lastWinDay = 0 -- earlier tests already won today
				local before = saved.passXp
				Progression.awardMatch(me, "Normal", true)
				local up = last("PassUpdate")
				expect(up.gained).toBe(320)
				expect(up.daily).toBe(true)
				Progression.awardMatch(me, "Normal", true)
				expect(last("PassUpdate").gained).toBe(120) -- the bonus is once a day
				Progression.awardMatch(me, "Wall", true)
				expect(last("PassUpdate").gained).toBe(120) -- the wall gives nothing: no new update
				expect(Fake.dataStores.PlayerData_v1["u_" .. me.UserId].passXp).toBe(before + 440)
				-- reach level 10: free rewards at 5 and 10 arrive
				while Fake.dataStores.PlayerData_v1["u_" .. me.UserId].passXp < 4000 do
					Progression.awardMatch(me, "Ranked", false)
				end
				local data = Fake.dataStores.PlayerData_v1["u_" .. me.UserId]
				expect(data.passXp >= 4000).toBeTruthy()
				expect(data.items.title_rookie).toBe(true)
				expect(data.items.paddle_magenta).toBe(true)
				expect(data.items.trail_fire).toBe(nil) -- premium only
				-- Premium in Studio is granted for testing, with every premium reward already reached
				remotes.BuyPremium:FireServer()
				up = last("PassUpdate")
				expect(up.premiumNow).toBe(true)
				expect(table.find(up.newItems, "trail_fire") ~= nil).toBeTruthy()
				expect(table.find(up.newItems, "paddle_sakura") ~= nil).toBeTruthy()
				-- equip what you own; refuse what you do not
				remotes.Equip:FireServer("trail", "trail_fire")
				expect(last("PassUpdate").state.equipped.trail).toBe("trail_fire")
				local count = #seen
				remotes.Equip:FireServer("trail", "trail_galaxy")
				expect(#seen).toBe(count)
				remotes.Equip:FireServer("paddle", "")
				expect(#seen).toBe(count)
			end,
		},
		{
			"Sakura Float unlocks at Silver; casual play there has wind, and players show their cosmetics",
			function()
				local RunService = globals.game:GetService("RunService")
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local PlayerData = loader.require("src/server/PlayerData")
				local me = Fake.localPlayer
				local seen = {}
				remotes.MatchEvent.OnClientEvent:Connect(function(e)
					table.insert(seen, e)
				end)
				local function lastStart()
					for i = #seen, 1, -1 do
						if seen[i].kind == "Start" then
							return seen[i]
						end
					end
					return nil
				end
				PlayerData.get(me.UserId).best = 1000
				remotes.RequestMatch:FireServer("Easy", { "Curve", "Blink" }, "Sakura")
				expect(lastStart().arena).toBe("Rooftop") -- still Bronze: not unlocked
				remotes.LeaveMatch:FireServer()
				PlayerData.get(me.UserId).best = 1150
				remotes.RequestMatch:FireServer("Easy", { "Curve", "Blink" }, "Sakura")
				local start = lastStart()
				expect(start.arena).toBe("Sakura")
				expect(start.wind).toBe(true)
				expect(start.looks[1].trail).toBe("trail_fire")
				expect(start.looks[2]).toBe(false)
				local arena = globals.workspace:FindFirstChild("SakuraFloat")
				expect(arena ~= nil).toBeTruthy()
				-- play a few seconds so the client draws windy shots
				for _ = 1, 60 * 6 do
					Fake.clock.now += 1 / 60
					RunService.Heartbeat:Fire(1 / 60)
					RunService.RenderStepped:Fire(1 / 60)
				end
				local windy = false
				for _, e in seen do
					if e.kind == "Shot" and e.shot.effects.wind then
						windy = true
					end
				end
				expect(windy).toBe(true)
				remotes.LeaveMatch:FireServer()
			end,
		},
		{
			"every text key the client asks for exists",
			function()
				local fs = require("@lune/fs")
				local S = loader.require("src/shared/Strings")
				local keys = S.keys()
				local missing = {}
				for _, file in { "src/client/Hud.luau", "src/client/init.client.luau", "src/client/BallView.luau" } do
					local src = fs.readFile(file)
					for key in string.gmatch(src, '"([%a]+%.[%w%.]+)"') do
						local prefix = string.match(key, "^(%a+)%.")
						local known = {
							menu = 1,
							board = 1,
							common = 1,
							wait = 1,
							search = 1,
							hud = 1,
							opponent = 1,
							level = 1,
							grade = 1,
							hint = 1,
							denied = 1,
							point = 1,
							game = 1,
							ability = 1,
							result = 1,
							tut = 1,
							fb = 1,
							access = 1,
							arena = 1,
							pass = 1,
							cos = 1,
						}
						if known[prefix] and not string.match(key, "%.$") and not keys[key] then
							table.insert(missing, file .. ": " .. key)
						end
					end
				end
				if #missing > 0 then
					error("unknown text keys: " .. table.concat(missing, ", "))
				end
			end,
		},
		{
			"the pass and customize screens draw in all six languages, and equipping calls back",
			function()
				local S = loader.require("src/shared/Strings")
				local hud, calls = newHud()
				hud:setPassState({
					passXp = 4100,
					premium = false,
					items = { "paddle_cyan", "title_rookie", "paddle_magenta", "trail_fire" },
					equipped = { paddle = "paddle_cyan", trail = "", title = "title_rookie" },
				})
				hud:showPass()
				hud:showCustomize()
				hud:setWind("風 ▶▶")
				hud:setTitles("title_rookie", "", "Rival")
				hud:setArenaButton("アリーナ：サクラ・フロート")
				for _, locale in S.LOCALES do
					S.setLocale(locale)
					hud:relabel()
					if string.find(hud.passLevel.Text, "10") == nil then
						error(locale .. ": pass level text " .. hud.passLevel.Text)
					end
				end
				S.setLocale("ja")
				hud:relabel()
				expect(hud.myName.Text).toBe("あなた · ルーキー")
				-- click the owned fire trail, then a locked one
				local fire, galaxy
				for _, b in hud.cosGrids.trail:GetChildren() do
					if b:GetAttribute("ItemId") == "trail_fire" then
						fire = b
					elseif b:GetAttribute("ItemId") == "trail_galaxy" then
						galaxy = b
					end
				end
				fire.Activated:Fire()
				expect(calls[#calls]).toBe("equip:trail:trail_fire")
				local n = #calls
				galaxy.Activated:Fire()
				expect(#calls).toBe(n)
			end,
		},
	}
end
