--!strict
-- Client entry point: input, camera, ball drawing and HUD for practice and online matches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Rally"):WaitForChild("Config"))
local Abilities = require(Shared:WaitForChild("Rally"):WaitForChild("Abilities"))
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local BallView = require(script.BallView)
local Hud = require(script.Hud)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local requestRemote = Net.get(Net.REQUEST_MATCH)
local leaveRemote = Net.get(Net.LEAVE_MATCH)
local swingRemote = Net.get(Net.SWING)
local abilityRemote = Net.get(Net.USE_ABILITY)
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

-- what the ability buttons need to know
local myLoadout: { string } = {}
local myGauge = 0
local usedThisRally = false
local armedId: string? = nil
local inRally = false
local barrierWalls: { [number]: Part } = {}

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

-- Direction for Blink: where the player is walking, or where they aim if standing still.
local function blinkDirection(): number
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local z = if humanoid then humanoid.MoveDirection.Z else 0
	if math.abs(z) < 0.2 then
		z = currentAim()
	end
	return z
end

local function useAbility(slot: number)
	if origin and myLoadout[slot] then
		abilityRemote:FireServer(slot, blinkDirection())
	end
end

local hud
hud = Hud.new(player:WaitForChild("PlayerGui") :: PlayerGui, {
	onMode = function(mode: string)
		currentMode = mode
		requestRemote:FireServer(mode, hud:getLoadout())
	end,
	onLeave = function()
		leaveRemote:FireServer()
	end,
	onRetry = function()
		requestRemote:FireServer(currentMode, hud:getLoadout())
	end,
	onSwingButton = swing,
	onAbility = useAbility,
})
hud:showMenu()

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local t = input.UserInputType
	local key = input.KeyCode
	if t == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonR2 then
		swing()
	elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then
		useAbility(1)
	elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonL2 then
		useAbility(2)
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

local DENIED = {
	gauge = "ゲージが足りない",
	used = "このラリーではもう能力を使った",
	notRally = "ラリー中に使える",
	noBall = "自分に向かってくる球があるときに使える",
	active = "もう発動している",
}

local function refreshSlots()
	local states = {}
	for i, id in myLoadout do
		local def = Abilities.get(id)
		if armedId == id then
			states[i] = "armed"
		elseif def and inRally and not usedThisRally and myGauge >= def.cost then
			states[i] = "ready"
		else
			states[i] = "waiting"
		end
	end
	hud:setSlotStates(states)
end

local function clearBarrier(index: number)
	local wall = barrierWalls[index]
	if wall then
		wall:Destroy()
		barrierWalls[index] = nil
	end
end

local function abilityName(id: string): string
	local def = Abilities.get(id)
	return if def then def.name else id
end

local function onAbilityEvent(e: { [string]: any })
	local mine = e.player == me
	local color = Hud.abilityColor(e.id)
	local who = if mine then "" else "相手："
	if e.state == "armed" then
		if mine then
			armedId = e.id
			hud:setHint(`{abilityName(e.id)}：次の返球で発動`)
		end
	elseif e.state == "disarmed" then
		if mine then
			armedId = nil
			hud:setHint("")
		end
	elseif e.state == "fizzled" then
		if mine then
			armedId = nil
			hud:setHint("ゲージが足りず、能力は発動しなかった")
		end
	elseif e.state == "fired" or e.state == "used" then
		hud:announceAbility(`{who}{abilityName(e.id)}！`, color)
		if mine then
			armedId = nil
			usedThisRally = true
			myGauge = e.gauge or myGauge
			hud:setGauge(myGauge)
			hud:setHint("")
		end
		local o = origin
		if e.state == "used" and o then
			local side = if e.player == 1 then -1 else 1
			if e.id == "Barrier" then
				clearBarrier(e.player)
				barrierWalls[e.player] = ball:barrierWall(side, color)
			elseif e.id == "GravityWell" then
				local targetSide = if e.target == 1 then -1 else 1
				ball:floorRing(targetSide, color, math.max(e.untilTime - now(), 0.5))
			elseif e.id == "Blink" then
				local root = if mine then myRoot() else nil
				local at = if root then root.Position else o + Vector3.new(side * 14, 0.2, 0)
				ball:flashAt(Vector3.new(at.X, o.Y + 0.2, at.Z), color)
			end
		end
	elseif e.state == "triggered" then
		hud:announceAbility(`{who}リフトバリア発動！`, color)
		clearBarrier(e.player)
	elseif e.state == "expired" then
		clearBarrier(e.player)
	end
	refreshSlots()
end

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
		myLoadout = e.loadout or {}
		myGauge, usedThisRally, armedId, inRally = 0, false, nil, false
		clearBarrier(1)
		clearBarrier(2)
		ball:setOrigin(e.origin)
		ball:hide()
		hud:showMatch(e.opponent)
		hud:setSlots(myLoadout)
		refreshSlots()
		local theirs = e.opponentLoadout or {}
		if #theirs > 0 then
			local names = {}
			for _, id in theirs do
				table.insert(names, abilityName(id))
			end
			hud:announceAbility("相手の能力：" .. table.concat(names, "・"), Palette.TeamB)
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 52
		setJump(false)
	elseif kind == "Score" then
		hud:setScore(e, me)
		myGauge = e.gauge[me]
		refreshSlots()
	elseif kind == "ServeWait" then
		serveHint(e.server)
	elseif kind == "Shot" then
		if e.update then
			ball:updateShot(e.shot)
		else
			ball:setShot(e.shot, now())
			if not armedId then
				hud:setHint("")
			end
		end
		inRally = true
		refreshSlots()
	elseif kind == "Ability" then
		onAbilityEvent(e)
	elseif kind == "AbilityDenied" then
		if e.player == me then
			hud:setHint(DENIED[e.reason] or "今は使えない")
		end
	elseif kind == "Swing" then
		if e.player == me then
			hud:popupGrade(e.grade, e.offset)
			if e.protected then
				hud:setHint("バリアが守ってくれる！")
			end
			if e.grade ~= "Miss" then
				ball:hitEffect(e.grade)
				myGauge = e.gauge
				hud:setGauge(e.gauge)
				refreshSlots()
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
		inRally, usedThisRally, armedId = false, false, nil
		clearBarrier(1)
		clearBarrier(2)
		refreshSlots()
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
		clearBarrier(1)
		clearBarrier(2)
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
