--!strict
-- Client entry point: input, camera, ball drawing and HUD for every mode.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Rally"):WaitForChild("Config"))
local Abilities = require(Shared:WaitForChild("Rally"):WaitForChild("Abilities"))
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local Matchmaker = require(Shared:WaitForChild("Rank"):WaitForChild("Matchmaker"))
local S = require(Shared:WaitForChild("Strings"))
local BallView = require(script.BallView)
local Hud = require(script.Hud)
local ArenaLook = require(script.ArenaLook)
local SeasonFolder = Shared:WaitForChild("Season")
local Arenas = require(SeasonFolder:WaitForChild("Arenas"))
local Cosmetics = require(SeasonFolder:WaitForChild("Cosmetics"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Japanese for Japanese locales, English for everyone else; the menu button switches it.
S.setLocale(S.fromLocaleId(LocalizationService.RobloxLocaleId))

local requestRemote = Net.get(Net.REQUEST_MATCH)
local leaveRemote = Net.get(Net.LEAVE_MATCH)
local swingRemote = Net.get(Net.SWING)
local abilityRemote = Net.get(Net.USE_ABILITY)
local helloRemote = Net.get(Net.HELLO)
local leaderboardRemote = Net.get(Net.REQUEST_LEADERBOARD)
local feedbackRemote = Net.get(Net.SEND_FEEDBACK)
local equipRemote = Net.get(Net.EQUIP)
local premiumRemote = Net.get(Net.BUY_PREMIUM)
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
local selectedArena = Arenas.DEFAULT
local bestRating = 1000
local windActive = false

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

local function arenaButtonText(): string
	local a = Arenas.get(selectedArena) or Arenas.List[1]
	local text = S.t("menu.arena", { name = S.t("arena." .. a.id) })
	if bestRating < a.unlockRating then
		text ..= "  (" .. S.t("arena.locked", { rank = S.rank(a.unlockRank) }) .. ")"
	elseif a.wind then
		text ..= "\n" .. S.t("arena.windNote")
	end
	return text
end

local hud
hud = Hud.new(player:WaitForChild("PlayerGui") :: PlayerGui, {
	onMode = function(mode: string)
		currentMode = mode
		requestRemote:FireServer(mode, hud:getLoadout(), selectedArena)
	end,
	onLeave = function()
		leaveRemote:FireServer()
	end,
	onRetry = function()
		requestRemote:FireServer(currentMode, hud:getLoadout(), selectedArena)
	end,
	onSwingButton = swing,
	onAbility = useAbility,
	onLeaderboard = function(scope: string)
		leaderboardRemote:FireServer(scope)
	end,
	onLanguage = function()
		S.setLocale(S.nextLocale())
		hud:relabel()
		hud:setArenaButton(arenaButtonText())
	end,
	onArena = function()
		local i = 1
		for n, a in Arenas.List do
			if a.id == selectedArena then
				i = n
			end
		end
		selectedArena = Arenas.List[(i % #Arenas.List) + 1].id
		hud:setArenaButton(arenaButtonText())
	end,
	onBuyPremium = function()
		premiumRemote:FireServer()
	end,
	onEquip = function(kind: string, id: string)
		equipRemote:FireServer(kind, id)
	end,
	onFeedback = function(category: string, text: string)
		feedbackRemote:FireServer(category, text, S.locale())
	end,
})
hud:showMenu()
hud:setArenaButton(arenaButtonText())

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
		hud:setHint(S.t(if UserInputService.TouchEnabled then "hint.serveTouch" else "hint.serve"))
	else
		hud:setHint(S.t("hint.theirServe"))
	end
end

-- "23s  rating ±150, your region"
local function searchText(waited: number): string
	local w = Matchmaker.window(waited)
	local diff = if w.maxDiff == math.huge then S.t("search.anyDiff") else S.t("search.diff", { n = w.maxDiff })
	return S.t(
		"wait.rankedStatus",
		{ seconds = math.floor(waited), search = diff .. " / " .. S.t("search." .. w.regions) }
	)
end

local function opponentLabel(e: { [string]: any }): string
	local mode = e.opponentMode
	if mode == "Wall" then
		return S.t("opponent.wall")
	elseif mode then
		return S.t("opponent.bot", { level = S.t("level." .. mode) })
	end
	return e.opponent
end

local tutorialStep: string? = nil
local function showTutorial(step: string, left: number)
	tutorialStep = step
	local key = if step == "hit"
		then "tut.hit"
		elseif step == "perfect" then "tut.perfect"
		elseif step == "ability" then "tut.ability"
		else "tut.done"
	hud:setTutorial(S.t(key, { n = left }))
end

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
	return S.abilityName(id)
end

local function onAbilityEvent(e: { [string]: any })
	local mine = e.player == me
	local color = Hud.abilityColor(e.id)
	local who = if mine then "" else S.t("ability.them")
	if e.state == "armed" then
		if mine then
			armedId = e.id
			hud:setHint(S.t("hint.armed", { ability = abilityName(e.id) }))
		end
	elseif e.state == "disarmed" then
		if mine then
			armedId = nil
			hud:setHint("")
		end
	elseif e.state == "fizzled" then
		if mine then
			armedId = nil
			hud:setHint(S.t("hint.fizzled"))
		end
	elseif e.state == "fired" or e.state == "used" then
		hud:announceAbility(S.t("ability.used", { who = who, ability = abilityName(e.id) }), color)
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
		hud:announceAbility(S.t("ability.barrierFired", { who = who }), color)
		clearBarrier(e.player)
	elseif e.state == "expired" then
		clearBarrier(e.player)
	end
	refreshSlots()
end

local function endMatchView()
	origin = nil
	windActive = false
	hud:setWind(nil)
	ArenaLook.apply(nil)
	ball:hide()
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	setJump(true)
end

local function onEvent(e: { [string]: any })
	local kind = e.kind
	if kind == "Queued" then
		hud:setMenuNote("")
		if e.ranked then
			hud:showWaiting({ title = S.t("wait.ranked"), sub = S.t("wait.rankedSub") })
		else
			hud:showWaiting()
		end
	elseif kind == "RankQueue" then
		hud:showWaiting({ title = S.t("wait.ranked"), sub = searchText(e.waited), bot = e.botOffer })
	elseif kind == "Teleporting" then
		hud:showWaiting({ title = S.t("wait.teleporting"), cancel = false })
	elseif kind == "RoomWaiting" then
		hud:showWaiting({ title = S.t("wait.room"), sub = S.t("wait.roomSub"), cancel = false })
	elseif kind == "RankDenied" then
		hud:showMenu()
		hud:setMenuNote(S.t(if e.reason == "banned" then "menu.banned" else "menu.rankedUnavailable"))
	elseif kind == "RankCancelled" then
		endMatchView()
		hud:showMenu()
		hud:setMenuNote(S.t(if e.reason == "noshow" then "menu.noShow" else "menu.teleportFailed"))
	elseif kind == "Profile" then
		hud:setProfile(e)
		bestRating = e.best or bestRating
		if e.arena and Arenas.get(e.arena) then
			selectedArena = e.arena
		end
		hud:setArenaButton(arenaButtonText())
		if e.pass then
			hud:setPassState(e.pass)
		end
		if not e.tutorialDone and hud.menuNote.Text == "" then
			hud:setMenuNote(S.t("menu.tryTutorial"), true)
		end
	elseif kind == "PassUpdate" then
		hud:setPassState(e.state)
		if e.gained and e.gained > 0 then
			local text = S.t("pass.xpGain", { xp = e.gained })
			if e.daily then
				text = S.t("pass.dailyBonus") .. "  " .. text
			end
			hud:announceAbility(text, Palette.Grade.Perfect)
		end
		if e.levelAfter and e.levelBefore and e.levelAfter > e.levelBefore then
			hud:popupText(S.t("pass.levelUp", { n = e.levelAfter }), Palette.Grade.Perfect)
		end
		local newItems = e.newItems or {}
		if #newItems > 0 then
			hud:setMenuNote(S.t("pass.newItem", { item = S.item(newItems[#newItems]) }), true)
		end
	elseif kind == "FeedbackResult" then
		hud:feedbackResult(e.status)
	elseif kind == "Tutorial" then
		showTutorial(e.step, e.left)
	elseif kind == "Leaderboard" then
		hud:showLeaderboard(e.scope, e.rows)
	elseif kind == "RankResult" then
		hud:setRankResult(e)
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
		tutorialStep = nil
		hud:showMatch(opponentLabel(e))
		-- arena look, wind, and both players' cosmetics
		ArenaLook.apply(e.arena)
		windActive = e.wind == true
		local looks = e.looks or {}
		local function trailOf(look: any): Color3?
			local item = if look and look.trail ~= "" then Cosmetics.get(look.trail) else nil
			return if item and item.rgb then Color3.fromRGB(item.rgb[1], item.rgb[2], item.rgb[3]) else nil
		end
		ball:setTrails(trailOf(looks[1]), trailOf(looks[2]))
		local myLook, theirLook = looks[me], looks[them()]
		hud:setTitles(if myLook then myLook.title else "", if theirLook then theirLook.title else "", opponentLabel(e))
		hud:setSlots(myLoadout)
		refreshSlots()
		local theirs = e.opponentLoadout or {}
		if #theirs > 0 then
			local names = {}
			for _, id in theirs do
				table.insert(names, abilityName(id))
			end
			hud:announceAbility(S.t("ability.theirLoadout", { list = table.concat(names, " / ") }), Palette.TeamB)
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
			local key = "denied." .. tostring(e.reason)
			hud:setHint(S.t(if S.has(key) then key else "denied.other"))
		end
	elseif kind == "Swing" then
		if e.player == me then
			hud:popupGrade(e.grade, e.offset)
			if e.protected then
				hud:setHint(S.t("hint.protected"))
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
		local reasonKey = "point." .. tostring(e.reason)
		hud:popupText(
			S.t(if mine then "point.you" elseif S.has(reasonKey) then reasonKey else "point.lost"),
			if mine then Palette.TeamA else Palette.Grade.Miss
		)
		hud:setRally(0)
	elseif kind == "Game" then
		hud:popupText(S.t(if e.winner == me then "game.won" else "game.lost"), Palette.Grade.Perfect)
	elseif kind == "MatchOver" then
		local note = if e.reason == "forfeit" and e.winner == me then S.t("result.forfeit") else nil
		ball:hide()
		hud:showResult(e.winner == me, e.games[me], e.games[them()], note)
	elseif kind == "Left" then
		clearBarrier(1)
		clearBarrier(2)
		tutorialStep = nil
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
local pingClock = 0
RunService.Heartbeat:Connect(function(dt)
	pingClock += dt
	if pingClock < 1 or not origin then
		return
	end
	pingClock = 0
	local debugMs = ReplicatedStorage:GetAttribute(Net.DEBUG_LAG_ATTRIBUTE)
	local extra = if type(debugMs) == "number" then debugMs else 0
	hud:setPing(player:GetNetworkPing() * 1000 + extra)
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
	if windActive then
		-- arrows in the direction the wind pushes, as seen on screen
		local w = Arenas.windAt(now())
		local onScreen = w * (if camera.CFrame.RightVector:Dot(Vector3.zAxis) >= 0 then 1 else -1)
		local n = math.clamp(math.ceil(math.abs(w) / 0.3), 1, 3)
		local arrow = string.rep(if onScreen >= 0 then "▶" else "◀", n)
		hud:setWind(S.t("hud.wind", { arrow = if math.abs(w) < 0.08 then "・" else arrow }))
	end
end)

-- Ready: ask the server for our rank and anything else it needs to tell us.
helloRemote:FireServer()
