--!strict
-- Client entry point: input, camera, ball drawing and HUD for practice and online matches.

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

local requestRemote = Net.get(Net.REQUEST_MATCH)
local leaveRemote = Net.get(Net.LEAVE_MATCH)
local swingRemote = Net.get(Net.SWING)
local matchEvent = Net.get(Net.MATCH_EVENT)

local ball = BallView.new()
local origin: Vector3? = nil
local me = 1 -- our player index in the current match (1 stands on side -1)
local mySide = -1
local currentMode = "Wall"
local stickAim = 0
local shake = 0
local cameraZ = 0
local lastSwingSent = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function them(): number
	return if me == 1 then 2 else 1
end

local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Aim across the table as a world Z direction, -1..1.
-- Mouse and right stick aim left/right on screen; the screen's right is +Z or -Z depending on side.
local function currentAim(): number
	local screenRightIsPlusZ = camera.CFrame.RightVector:Dot(Vector3.zAxis) >= 0
	local flip = if screenRightIsPlusZ then 1 else -1
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local m = UserInputService:GetMouseLocation()
		local w = camera.ViewportSize.X
		return math.clamp((m.X / w) * 2 - 1, -1, 1) * 1.4 * flip
	end
	if math.abs(stickAim) > 0.15 then
		return stickAim * flip
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return math.clamp(humanoid.MoveDirection.Z * 1.5, -1, 1)
	end
	return 0
end

local function swing()
	local o = origin
	if not o then
		return
	end
	local t = now()
	if t - lastSwingSent < 0.12 then
		return
	end
	lastSwingSent = t
	local root = myRoot()
	local z = if root then root.Position.Z - o.Z else 0
	swingRemote:FireServer(t, math.clamp(currentAim(), -1, 1), z)
end

local hud = Hud.new(player:WaitForChild("PlayerGui") :: PlayerGui, {
	onMode = function(mode: string)
		currentMode = mode
		requestRemote:FireServer(mode)
	end,
	onLeave = function()
		leaveRemote:FireServer()
	end,
	onRetry = function()
		requestRemote:FireServer(currentMode)
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
		humanoid.UseJumpPower = true
		humanoid.JumpPower = if enabled then 50 else 0
	end
end

local function flashFov(amount: number)
	camera.FieldOfView = 52 + amount
	TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { FieldOfView = 52 }):Play()
end

local function serveHint(server: number)
	if server == me then
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

local function endMatchView()
	origin = nil
	ball:hide()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	setJump(true)
end

local function onEvent(e: { [string]: any })
	local kind = e.kind
	if kind == "Queued" then
		hud:showWaiting()
	elseif kind == "Start" then
		me = e.you
		mySide = e.side
		origin = e.origin
		cameraZ = 0
		ball:setOrigin(e.origin)
		ball:hide()
		hud:showMatch(e.opponent)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 52
		setJump(false)
	elseif kind == "Score" then
		hud:setScore(e, me)
	elseif kind == "ServeWait" then
		serveHint(e.server)
	elseif kind == "Shot" then
		ball:setShot(e.shot, now())
		hud:setHint("")
	elseif kind == "Swing" then
		if e.player == me then
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
		local mine = e.winner == me
		hud:popupText(
			if mine then "POINT!" else (REASON[e.reason] or "失点"),
			if mine then Palette.TeamA else Palette.Grade.Miss
		)
		hud:setRally(0)
	elseif kind == "Game" then
		hud:popupText(
			if e.winner == me then "ゲーム獲得！" else "ゲームを落とした",
			Palette.Grade.Perfect
		)
	elseif kind == "MatchOver" then
		local note = if e.reason == "forfeit" and e.winner == me then "相手が退出しました" else nil
		ball:hide()
		hud:showResult(e.winner == me, e.games[me], e.games[them()], note)
	elseif kind == "Left" then
		endMatchView()
		hud:showMenu()
	end
end
matchEvent.OnClientEvent:Connect(onEvent)

player.CharacterAdded:Connect(function()
	if origin then
		task.defer(setJump, false)
	end
end)

-- Round-trip time shown in the corner, including any debug delay set in Studio.
task.spawn(function()
	while true do
		if origin then
			local debugMs = ReplicatedStorage:GetAttribute(Net.DEBUG_LAG_ATTRIBUTE)
			local extra = if type(debugMs) == "number" then debugMs else 0
			hud:setPing(player:GetNetworkPing() * 1000 + extra)
		end
		task.wait(1)
	end
end)

-- Broadcast-style camera behind our own side, following us a little across the table.
RunService.RenderStepped:Connect(function(dt)
	ball:update(now(), dt)
	local o = origin
	if not o then
		return
	end
	local root = myRoot()
	local z = if root then root.Position.Z - o.Z else 0
	cameraZ += (z - cameraZ) * math.min(dt * 4, 1)
	local eye = o + Vector3.new(mySide * (Config.HitX + 17), 11, cameraZ * 0.55)
	local focus = o + Vector3.new(-mySide * 2, Config.Table.surfaceY, cameraZ * 0.25)
	local cf = CFrame.lookAt(eye, focus)
	if shake > 0 then
		shake = math.max(0, shake - dt)
		local k = shake * 0.6
		cf *= CFrame.new(math.random() * k - k / 2, math.random() * k - k / 2, 0)
	end
	camera.CFrame = cf
end)
