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

				local function makePlayer(name: string)
					local p = globals.Instance.new("Player")
					p.Name = name
					p.DisplayName = name
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
									UserInputService.InputBegan:Fire(
										{
											UserInputType = roblox.Enum.UserInputType.Keyboard,
											KeyCode = roblox.Enum.KeyCode.Q,
										},
										false
									)
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
	}
end
