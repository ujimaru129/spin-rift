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
					p.DisplayName = name
					nextUserId += 1
					p.UserId = nextUserId
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
					humanoid.MoveDirection = Vector3.new(0, 0, 0)
					p.Character = character
					p.Parent = Players
					return p, root
				end

				local me, myRoot = makePlayer("Tester")
				Players.LocalPlayer = me
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
			"two players are paired online, and leaving hands the win to the other",
			function()
				local Players = globals.game:GetService("Players")
				local RunService = globals.game:GetService("RunService")
				local replicated = globals.game:GetService("ReplicatedStorage")
				local remotes = replicated:FindFirstChild("SpinRiftRemotes")
				local me = Fake.localPlayer
				local other = globals.Instance.new("Player")
				other.Name = "Rival"
				other.DisplayName = "Rival"
				other.UserId = 2
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
				rival.DisplayName = "Rookie"
				rival.UserId = 3
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
				remotes.LeaveMatch:FireServer()
				Players.PlayerRemoving:Fire(rival)
				rival.Parent = nil
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
				guest.UserId = 50
				guest.DisplayName = "Guest"
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
			"every text has Japanese and English, and the HUD redraws in English",
			function()
				local S = loader.require("src/shared/Strings")
				expect(#S.missing()).toBe(0)
				expect(S.fromLocaleId("ja-jp")).toBe("ja")
				expect(S.fromLocaleId("en-us")).toBe("en")
				expect(S.fromLocaleId("pt-br")).toBe("en")
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
									UserInputService.InputBegan:Fire(
										{
											UserInputType = roblox.Enum.UserInputType.Keyboard,
											KeyCode = roblox.Enum.KeyCode.Q,
										},
										false
									)
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
				tester.__groups = { [777] = 1 }
				expect(ClosedTest.admit(tester)).toBe(true)
				Fake.studio = true
				expect(ClosedTest.admit(outsider)).toBe(true) -- Studio is never blocked
				ClosedTest.ENABLED = false
			end,
		},
	}
end
