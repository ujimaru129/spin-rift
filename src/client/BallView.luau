--!strict
-- Draws the ball on this client from the shot the server sent, using the shared server clock.
-- The ball is a local Part: it never replicates, so it moves every frame without network jitter.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RallyFolder = Shared:WaitForChild("Rally")
local Config = require(RallyFolder:WaitForChild("Config"))
local Trajectory = require(RallyFolder:WaitForChild("Trajectory"))
local Abilities = require(RallyFolder:WaitForChild("Abilities"))
local Palette = require(Shared:WaitForChild("Palette"))

local Audio = require(script.Parent:WaitForChild("Audio"))

local BallView = {}
BallView.__index = BallView

export type BallView = typeof(setmetatable(
	{} :: {
		folder: Folder,
		ball: Part,
		trail: Trail,
		light: PointLight,
		shadow: Part,
		origin: Vector3,
		shot: Trajectory.Shot?,
		bounced: boolean,
		lostAt: number?, -- set when the point ended: the ball flies on and fades
		lastPos: Vector3,
		velocity: Vector3,
		receivedAt: number,
		lateBy: number,
		ghosts: { Part },
		baseColor: Color3,
		trails: { [number]: Color3? }, -- cosmetic trail colour by hitter side
		flickerUntil: number?, -- EMP: the ball flickers on this screen until then
		stallShown: Trajectory.Shot?, -- Quantum Stop: the shot whose stop was already marked
		outline: Highlight, -- keeps the ball visible through special-move effects
		revealUntil: number,
	},
	BallView
))

function BallView.new(): BallView
	local folder = Instance.new("Folder")
	folder.Name = "SpinRiftLocal"
	folder.Parent = workspace

	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.Ball.radius * 2
	ball.Material = Enum.Material.Neon
	ball.Color = Palette.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Transparency = 1
	ball.Parent = folder

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.22, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.22, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.22
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Parent = ball

	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 2.5
	light.Parent = ball

	local shadow = Instance.new("Part")
	shadow.Name = "BallShadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Size = Vector3.new(0.02, 0.8, 0.8)
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Transparency = 1
	shadow.Anchored = true
	shadow.CanCollide = false
	shadow.CanQuery = false
	shadow.CastShadow = false
	shadow.Parent = folder

	-- Drawn on top of everything for a moment after a special move, so the effects never hide
	-- the ball (never used while a trick is meant to hide it: Blind, Phantom, EMP)
	local outline = Instance.new("Highlight")
	outline.Adornee = ball
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.FillColor = Palette.Ball
	outline.FillTransparency = 0.2
	outline.OutlineColor = Color3.new(1, 1, 1)
	outline.OutlineTransparency = 0
	outline.Enabled = false
	outline.Parent = folder

	-- Phantom copies: same look as the ball, no light and no shadow on the table
	local ghosts: { Part } = {}
	for i = 1, 2 do
		local g = ball:Clone()
		g.Name = "Phantom" .. i
		local pl = g:FindFirstChildOfClass("PointLight")
		if pl then
			pl:Destroy()
		end
		g.Transparency = 1
		local gt = g:FindFirstChildOfClass("Trail")
		if gt then
			gt.Enabled = false
		end
		g.Parent = folder
		ghosts[i] = g
	end

	return setmetatable({
		folder = folder,
		ball = ball,
		trail = trail,
		light = light,
		shadow = shadow,
		origin = Vector3.zero,
		shot = nil :: Trajectory.Shot?,
		bounced = false,
		lostAt = nil :: number?,
		lastPos = Vector3.zero,
		velocity = Vector3.zero,
		receivedAt = 0,
		lateBy = 0,
		ghosts = ghosts,
		baseColor = Color3.new(1, 1, 1),
		trails = {},
		outline = outline,
		revealUntil = 0,
	}, BallView)
end

function BallView.setOrigin(self: BallView, origin: Vector3)
	self.origin = origin
end

-- A shot reaches this client a little after it started on the server. Instead of jumping the
-- ball ahead, it starts from the paddle and catches up with the real path over this many seconds.
local CATCH_UP = 0.2

function BallView.setShot(self: BallView, shot: Trajectory.Shot, now: number)
	self.shot = shot
	self.receivedAt = now
	self.lateBy = math.clamp(now - shot.startTime, 0, 0.35)
	self.bounced = false
	self.lostAt = nil
	self:_style(shot)
end

-- Time Slow changed the shot in flight: keep drawing it smoothly from where it is.
function BallView.updateShot(self: BallView, shot: Trajectory.Shot)
	self.shot = shot
	self:_style(shot)
end

local function abilityColor(id: string?): Color3?
	local def = if id then Abilities.get(id) else nil
	return if def then Color3.fromRGB(def.rgb[1], def.rgb[2], def.rgb[3]) else nil
end

-- Cosmetic trail colours for the two sides (side -1 = player 1). nil = the normal colours.
function BallView.setTrails(self: BallView, left: Color3?, right: Color3?)
	self.trails = { [-1] = left, [1] = right }
end

function BallView._style(self: BallView, shot: Trajectory.Shot)
	local fx = shot.effects
	-- ability shots always keep their ability colour so both players can read them
	local cosmetic = if fx.ability then nil else self.trails[shot.hitterSide]
	local color = abilityColor(fx.ability) or cosmetic or Palette.Shot[shot.kind] or Color3.new(1, 1, 1)
	self.baseColor = color
	self.trail.Color = ColorSequence.new(color)
	self.trail.Lifetime = if fx.smash then 0.35 elseif fx.meteor then 0.5 else 0.22
	-- the trail tells the shot; the ball stays orange (and lights the table orange) unless a
	-- special move is on it
	self.light.Color = if fx.ability then color else Palette.Ball
	self.light.Brightness = if fx.ability then 5 else 2.5
	self.ball.Color = Palette.Ball
	self.ball.Transparency = 0
	self.trail.Enabled = true
	for _, g in self.ghosts do
		g.Color = self.ball.Color
		g.Transparency = if fx.phantom then 0 else 1
		local gt = g:FindFirstChildOfClass("Trail")
		if gt then
			gt.Color = self.trail.Color
			gt.Enabled = fx.phantom == true
		end
	end
end

-- A special move just went off: keep the ball drawn on top of its effects until then.
function BallView.reveal(self: BallView, untilTime: number)
	self.revealUntil = untilTime
end

-- EMP hit this player: the ball flickers until then (its shadow on the table stays).
function BallView.flicker(self: BallView, untilTime: number)
	self.flickerUntil = untilTime
end

-- The point ended: let the ball fly on along its last direction and fade out.
function BallView.lose(self: BallView, now: number)
	if self.shot then
		self.lostAt = now
	end
end

function BallView.hide(self: BallView)
	self.shot = nil
	self.lostAt = nil
	self.ball.Transparency = 1
	self.shadow.Transparency = 1
	self.trail.Enabled = false
	self.outline.Enabled = false
	for _, g in self.ghosts do
		g.Transparency = 1
		local gt = g:FindFirstChildOfClass("Trail")
		if gt then
			gt.Enabled = false
		end
	end
end

-- A translucent neon wall in front of a player's paddle while their Rift Barrier is up.
function BallView.barrierWall(self: BallView, side: number, color: Color3): Part
	local wall = Instance.new("Part")
	wall.Name = "RiftBarrier"
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.CastShadow = false
	wall.Material = Enum.Material.ForceField
	wall.Color = color
	wall.Size = Vector3.new(0.3, 6, Config.Table.halfWidth * 2 + 4)
	wall.CFrame = CFrame.new(self.origin + Vector3.new(side * (Config.HitX + 1.2), Config.Table.surfaceY + 2, 0))
	wall.Parent = self.folder
	return wall
end

-- A glowing ring on the floor of one side, for Gravity Well.
function BallView.floorRing(self: BallView, side: number, color: Color3, seconds: number)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Transparency = 0.4
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CastShadow = false
	r.Size = Vector3.new(0.1, 12, 12)
	r.CFrame = CFrame.new(self.origin + Vector3.new(side * 14, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	r.Parent = self.folder
	TweenService:Create(r, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	task.delay(seconds, function()
		r:Destroy()
	end)
end

function BallView.flashAt(self: BallView, worldPos: Vector3, color: Color3)
	self:ring(worldPos, color, 6, Vector3.yAxis)
end

-- An expanding neon ring, used for hits and bounces.
function BallView.ring(self: BallView, worldPos: Vector3, color: Color3, size: number, facing: Vector3)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Material = Enum.Material.Neon
	r.Color = color
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CastShadow = false
	r.Size = Vector3.new(0.05, 0.4, 0.4)
	r.CFrame = CFrame.lookAt(worldPos, worldPos + facing) * CFrame.Angles(0, math.rad(90), 0)
	r.Parent = self.folder
	local tween = TweenService:Create(
		r,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, size, size), Transparency = 1 }
	)
	tween:Play()
	tween.Completed:Once(function()
		r:Destroy()
	end)
end

-- Where the ball bounced: a spot in the ball's colour with a ring round it, lying on the table and
-- fading out, so a ball that bounces right at the edge is clearly seen to land in.
BallView.BOUNCE_MARK_SECONDS = 0.9
function BallView.bounceMark(self: BallView, worldPos: Vector3)
	local seconds = BallView.BOUNCE_MARK_SECONDS
	local flat = CFrame.new(worldPos) * CFrame.Angles(0, 0, math.rad(90))
	for _, spec in { { 0.9, 0.15, 0.02 }, { 1.7, 0.35, 0.01 } } do
		local d = Instance.new("Part")
		d.Name = "BounceMark"
		d.Shape = Enum.PartType.Cylinder
		d.Material = Enum.Material.Neon
		d.Color = Palette.Ball
		d.Transparency = spec[2]
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Size = Vector3.new(spec[3], spec[1], spec[1])
		d.CFrame = flat
		d.Parent = self.folder
		TweenService
			:Create(d, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
			:Play()
		task.delay(seconds, function()
			d:Destroy()
		end)
	end
end

function BallView.hitEffect(self: BallView, grade: string)
	local color = Palette.Grade[grade] or Color3.new(1, 1, 1)
	local pos = self.ball.Position
	self:ring(pos, color, if grade == "Perfect" then 6 else 3.5, Vector3.xAxis)
	Audio.ball(if grade == "Perfect" then "PerfectHit" else "Hit")
end

function BallView.update(self: BallView, now: number, dt: number)
	local shot = self.shot
	if not shot then
		return
	end
	local pos: Vector3
	if self.lostAt then
		local since = now - self.lostAt
		self.velocity += Vector3.new(0, -60 * dt, 0)
		pos = self.lastPos + self.velocity * dt
		local fade = math.clamp(since / 0.6, 0, 1)
		self.ball.Transparency = fade
		self.outline.Enabled = false
		if fade >= 1 then
			self:hide()
			return
		end
	else
		-- while catching up, draw the ball slightly behind the true time
		local behind = self.lateBy * math.max(0, 1 - (now - self.receivedAt) / CATCH_UP)
		local s = Trajectory.progressAt(shot, now - behind)
		if s > 1 then
			-- past the paddle and nobody hit it yet: keep flying along the end direction
			local tail = Trajectory.positionAtProgress(shot, 1)
			local before = Trajectory.positionAtProgress(shot, 0.98)
			local v = (tail - before) / (shot.duration * 0.02)
			pos = self.origin + tail + v * ((s - 1) * shot.duration)
		else
			pos = self.origin + Trajectory.positionAtProgress(shot, s)
		end
		if dt > 0 then
			self.velocity = (pos - self.lastPos) / dt
		end
		-- Phantom copies drift apart and come back together at the paddle
		if shot.effects.phantom then
			local sp = math.clamp(s, 0, 1)
			local spread = Abilities.Tuning.Phantom.spread * math.sin(math.pi * sp)
			for i, g in self.ghosts do
				local sign = if i == 1 then -1 else 1
				g.CFrame = CFrame.new(pos + Vector3.new(0, 0, sign * spread))
				g.Transparency = 0.15 + 0.15 * math.sin(now * 30 + i)
			end
		end
		-- Blind Bound: invisible until it bounces (the shadow on the table still shows)
		local hidden = shot.effects.blind == true and not self.bounced
		self.ball.Transparency = if hidden then 1 else 0
		self.trail.Enabled = not hidden
		-- EMP: the ball flickers on a jammed screen
		local jammed = self.flickerUntil ~= nil and now < (self.flickerUntil :: number)
		if jammed and not hidden and math.random() < 0.35 then
			self.ball.Transparency = 0.85
			self.trail.Enabled = false
		end
		self.outline.Enabled = now < self.revealUntil and self.ball.Transparency < 0.5 and not shot.effects.phantom
		-- Quantum Stop: a burst of light where it stops, and a bright pulse while it hangs there
		local st, se = shot.effects.stallStart, shot.effects.stallEnd
		if st and se and now >= st and now < se then
			self.light.Brightness = 6 + 4 * math.sin(now * 40)
			if self.stallShown ~= shot then
				self.stallShown = shot
				self:ring(pos, self.baseColor, 5, Vector3.xAxis)
				self:ring(pos, self.baseColor, 3, Vector3.yAxis)
			end
		elseif st and se and now >= se then
			self.light.Brightness = 5
		end
		-- Time Slow: the ball turns blue while it is slowed
		local fx = shot.effects
		local slowed = fx.slowStart ~= nil and now >= (fx.slowStart :: number) and now < (fx.slowEnd :: number)
		local tint = if slowed then abilityColor("TimeSlow") :: Color3 else self.baseColor
		self.trail.Color = ColorSequence.new(tint)
		self.light.Color = tint
		if not self.bounced and now - behind >= Trajectory.bounceTime(shot) then
			self.bounced = true
			local b = self.origin + Trajectory.bouncePoint(shot) - Vector3.new(0, Config.Ball.radius - 0.05, 0)
			self:ring(b, Palette.Shot[shot.kind] or Color3.new(1, 1, 1), 3, Vector3.yAxis)
			self:bounceMark(b)
			Audio.ball("Bounce")
		end
	end
	self.lastPos = pos
	self.ball.CFrame = CFrame.new(pos)

	-- a soft dark spot on the table under the ball
	local localPos = pos - self.origin
	local T = Config.Table
	local over = math.abs(localPos.X) < T.halfLength and math.abs(localPos.Z) < T.halfWidth
	if over and not self.lostAt then
		local height = math.max(localPos.Y - T.surfaceY, 0)
		self.shadow.Transparency = math.clamp(0.45 + height * 0.12, 0.45, 0.9)
		local size = 0.7 + height * 0.15
		self.shadow.Size = Vector3.new(0.02, size, size)
		self.shadow.CFrame = CFrame.new(self.origin + Vector3.new(localPos.X, T.surfaceY + 0.03, localPos.Z))
			* CFrame.Angles(0, 0, math.rad(90))
	else
		self.shadow.Transparency = 1
	end
end

return BallView
