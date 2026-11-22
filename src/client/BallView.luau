--!strict
-- Draws the ball on this client from the shot the server sent, using the shared server clock.
-- The ball is a local Part: it never replicates, so it moves every frame without network jitter.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RallyFolder = Shared:WaitForChild("Rally")
local Config = require(RallyFolder:WaitForChild("Config"))
local Trajectory = require(RallyFolder:WaitForChild("Trajectory"))
local Palette = require(Shared:WaitForChild("Palette"))

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
	},
	BallView
))

local function sound(parent: Instance, speed: number, volume: number)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.Parent = parent
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

function BallView.new(): BallView
	local folder = Instance.new("Folder")
	folder.Name = "SpinRiftLocal"
	folder.Parent = workspace

	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.Ball.radius * 2
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.new(1, 1, 1)
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
	local color = Palette.Shot[shot.kind] or Color3.new(1, 1, 1)
	self.trail.Color = ColorSequence.new(color)
	self.light.Color = color
	self.ball.Color = color:Lerp(Color3.new(1, 1, 1), 0.6)
	self.ball.Transparency = 0
	self.trail.Enabled = true
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

function BallView.hitEffect(self: BallView, grade: string)
	local color = Palette.Grade[grade] or Color3.new(1, 1, 1)
	local pos = self.ball.Position
	self:ring(pos, color, if grade == "Perfect" then 6 else 3.5, Vector3.xAxis)
	sound(self.ball, if grade == "Perfect" then 1.35 else 1.1, if grade == "Perfect" then 0.9 else 0.6)
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
		if not self.bounced and now - behind >= Trajectory.bounceTime(shot) then
			self.bounced = true
			local b = self.origin + shot.bounce - Vector3.new(0, Config.Ball.radius - 0.05, 0)
			self:ring(b, Palette.Shot[shot.kind] or Color3.new(1, 1, 1), 2.2, Vector3.yAxis)
			sound(self.ball, 0.75, 0.35)
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
