--!strict
-- Client entry point: input, camera, ball drawing and HUD for practice matches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Rally"):WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local BallView = require(script.BallView)
local Hud = require(script.Hud)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ME = 1 -- the player is always player 1 (side -1) in practice

local startRemote = Net.get(Net.START_PRACTICE)
local leaveRemote = Net.get(Net.LEAVE_PRACTICE)
local swingRemote = Net.get(Net.SWING)
local matchEvent = Net.get(Net.MATCH_EVENT)

local ball = BallView.new()
local origin: Vector3? = nil
local currentMode = "Wall"
local stickAim = 0
local shake = 0
local cameraZ = 0
local lastSwingSent = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Aim across the table, -1..1. Screen-right is +Z with our camera, so map directly.
local function currentAim(): number
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local m = UserInputService:GetMouseLocation()
		local w = camera.ViewportSize.X
		return math.clamp((m.X / w) * 2 - 1, -1, 1) * 1.4
	end
	if math.abs(stickAim) > 0.15 then
		return stickAim
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return math.clamp(humanoid.MoveDirection:Dot(camera.CFrame.RightVector) * 1.5, -1, 1)
	end
	return 0
end

local function swing()
	if not origin then
		return
	end
	local t = now()
	if t - lastSwingSent < 0.12 then
		return
	end
	lastSwingSent = t
	swingRemote:FireServer(t, math.clamp(currentAim(), -1, 1))
end

local hud = Hud.new(player:WaitForChild("PlayerGui") :: PlayerGui, {
	onMode = function(mode: string)
		currentMode = mode
		startRemote:FireServer(mode)
	end,
	onLeave = function()
		leaveRemote:FireServer()
	end,
	onRetry = function()
		startRemote:FireServer(currentMode)
	end,
	onSwingButton = swing,
})
hud:showMenu()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local t = input.UserInputType
	if
		t == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonR2
	then
		swing()
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stickAim = input.Position.X
	end
end)

-- Space is our swing key during a match, so stop it from jumping.
local function setJump(enabled: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.JumpPower = if enabled then 50 else 0
		humanoid.UseJumpPower = true
	end
end

local function flashFov(amount: number)
	camera.FieldOfView = 52 + amount
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { FieldOfView = 52 }):Play()
end

local function serveHint(server: number)
	if server == ME then
		hud:setHint(
			if UserInputService.TouchEnabled
				then "あなたのサーブ：「打つ」をタップ"
				else "あなたのサーブ：クリックかスペース"
		)
	else
		hud:setHint("相手のサーブ")
	end
end

local REASON = { miss = "取れなかった", whiff = "空振り", reach = "届かなかった" }

local function onEvent(e: { [string]: any })
	local kind = e.kind
	if kind == "Start" then
		origin = e.origin
		ball:setOrigin(e.origin)
		ball:hide()
		hud:showMatch(e.label)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 52
		setJump(false)
	elseif kind == "Score" then
		hud:setScore(e, ME)
	elseif kind == "ServeWait" then
		serveHint(e.server)
	elseif kind == "Shot" then
		ball:setShot(e.shot)
		hud:setHint("")
	elseif kind == "Swing" then
		if e.player == ME then
			hud:popupGrade(e.grade, e.offset)
			if e.grade ~= "Miss" then
				ball:hitEffect(e.grade)
				hud:setGauge(e.gauge)
				if e.grade == "Perfect" then
					shake = 0.35
					flashFov(6)
				end
			end
		elseif e.grade ~= "Miss" then
			ball:hitEffect(e.grade)
		end
		if e.rally then
			hud:setRally(e.rally)
		end
	elseif kind == "Point" then
		ball:lose(now())
		local mine = e.winner == ME
		hud:popupText(
			if mine then "POINT!" else (REASON[e.reason] or "失点"),
			if mine then Palette.TeamA else Palette.Grade.Miss
		)
		hud:setRally(0)
	elseif kind == "Game" then
		hud:popupText(
			if e.winner == ME then "ゲーム獲得！" else "ゲームを落とした",
			Palette.Grade.Perfect
		)
	elseif kind == "MatchOver" then
		hud:showResult(e.winner == ME, e.games[ME], e.games[if ME == 1 then 2 else 1])
	elseif kind == "Left" then
		origin = nil
		ball:hide()
		hud:showMenu()
		camera.CameraType = Enum.CameraType.Custom
		setJump(true)
	end
end
matchEvent.OnClientEvent:Connect(onEvent)

player.CharacterAdded:Connect(function()
	if origin then
		task.defer(setJump, false)
	end
end)

-- Broadcast-style camera behind the player, following them a little across the table.
RunService.RenderStepped:Connect(function(dt)
	local t = now()
	ball:update(t, dt)
	local o = origin
	if not o then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local z = if root and root:IsA("BasePart") then root.Position.Z - o.Z else 0
	cameraZ += (z - cameraZ) * math.min(dt * 4, 1)
	local eye = o + Vector3.new(-Config.HitX - 17, 11, cameraZ * 0.55)
	local focus = o + Vector3.new(2, Config.Table.surfaceY, cameraZ * 0.25)
	local cf = CFrame.lookAt(eye, focus)
	if shake > 0 then
		shake = math.max(0, shake - dt)
		local k = shake * 0.6
		cf *= CFrame.new(math.random() * k - k / 2, math.random() * k - k / 2, 0)
	end
	camera.CFrame = cf
end)
