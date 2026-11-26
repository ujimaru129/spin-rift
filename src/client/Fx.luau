--!strict
-- Big, sci-fi effects for special moves and PERFECT hits. Everything here is local and only for
-- looks: it never changes where the ball goes or when it can be hit.
--
-- Building blocks: shockwave (a growing glowing sphere and rings), burst (a spray of sparks),
-- lightning (a jagged bolt), pillar (a column of light), vortex (a spinning black hole), and a
-- screen tint (colour correction on the camera).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function tween(obj: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t =
		TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function later(seconds: number, fn: () -> ())
	task.delay(seconds, fn)
end

local function part(parent: Instance, shape: Enum.PartType, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- A glowing sphere that grows and fades, with two flat rings racing out around it.
function Fx.shockwave(parent: Instance, pos: Vector3, color: Color3, size: number, seconds: number?)
	local t = seconds or 0.45
	local sphere = part(parent, Enum.PartType.Ball, color, Enum.Material.ForceField)
	sphere.Size = Vector3.one * 0.6
	sphere.CFrame = CFrame.new(pos)
	sphere.Transparency = 0.55
	tween(sphere, t, { Size = Vector3.one * size, Transparency = 1 })
	for i, axis in { Vector3.yAxis, Vector3.xAxis } do
		local ring = part(parent, Enum.PartType.Cylinder, color)
		ring.Size = Vector3.new(0.08, 0.6, 0.6)
		ring.CFrame = CFrame.lookAt(pos, pos + axis) * CFrame.Angles(0, math.rad(90), 0)
		tween(ring, t * (0.8 + 0.3 * i), { Size = Vector3.new(0.08, size * 1.3, size * 1.3), Transparency = 1 })
		later(t * 1.5, function()
			ring:Destroy()
		end)
	end
	later(t + 0.05, function()
		sphere:Destroy()
	end)
end

-- A spray of sparks flying out from a point.
function Fx.burst(parent: Instance, pos: Vector3, color: Color3, count: number, speed: number?)
	local holder = part(parent, Enum.PartType.Block, color)
	holder.Size = Vector3.one * 0.1
	holder.Transparency = 1
	holder.CFrame = CFrame.new(pos)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK_TEXTURE
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.4, 0)
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Speed = NumberRange.new((speed or 30) * 0.5, speed or 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Enabled = false
	e.Parent = holder
	e:Emit(count)
	later(1.2, function()
		holder:Destroy()
	end)
end

-- A jagged bolt of light between two points that flickers and fades.
function Fx.lightning(parent: Instance, from: Vector3, to: Vector3, color: Color3, segments: number?)
	local n = segments or 8
	local points = { from }
	for i = 1, n - 1 do
		local p = from:Lerp(to, i / n)
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.2
		table.insert(points, p + jitter)
	end
	table.insert(points, to)
	local bits: { Part } = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local len = (b - a).Magnitude
		local bit = part(parent, Enum.PartType.Block, color)
		bit.Size = Vector3.new(0.18, 0.18, len)
		bit.CFrame = CFrame.lookAt((a + b) / 2, b)
		table.insert(bits, bit)
	end
	for k = 1, 3 do
		later(0.05 * k, function()
			for _, bit in bits do
				bit.Transparency = if k % 2 == 1 then 0.6 else 0
			end
		end)
	end
	later(0.2, function()
		for _, bit in bits do
			tween(bit, 0.25, { Transparency = 1, Size = Vector3.new(0.02, 0.02, bit.Size.Z) })
		end
	end)
	later(0.5, function()
		for _, bit in bits do
			bit:Destroy()
		end
	end)
end

-- A column of light rising from the floor (teleports).
function Fx.pillar(parent: Instance, pos: Vector3, color: Color3)
	local p = part(parent, Enum.PartType.Cylinder, color)
	p.Size = Vector3.new(14, 2.6, 2.6)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.2
	tween(p, 0.45, { Size = Vector3.new(16, 0.1, 0.1), Transparency = 1 })
	later(0.5, function()
		p:Destroy()
	end)
	Fx.burst(parent, pos + Vector3.new(0, 1, 0), color, 25, 18)
end

-- A spinning black hole with glowing rings, for as long as an effect lasts.
function Fx.vortex(parent: Instance, pos: Vector3, color: Color3, seconds: number)
	local core = part(parent, Enum.PartType.Ball, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	core.Size = Vector3.one * 0.2
	core.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
	tween(core, 0.3, { Size = Vector3.one * 2.4 }, Enum.EasingStyle.Back)
	local rings: { Part } = {}
	for i = 1, 3 do
		local r = part(parent, Enum.PartType.Cylinder, color)
		r.Transparency = 0.3
		r.Size = Vector3.new(0.06, 3 + i * 1.6, 3 + i * 1.6)
		r.CFrame = CFrame.new(pos + Vector3.new(0, 0.6 + i * 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(rings, r)
	end
	local started = os.clock()
	local alive = true
	local conn = RunService.Heartbeat:Connect(function()
		if not alive then
			return
		end
		local t = os.clock() - started
		for i, r in rings do
			local spin = t * (2 + i) * (if i % 2 == 0 then -1 else 1)
			r.CFrame = CFrame.new(pos + Vector3.new(0, 0.6 + i * 0.25, 0))
				* CFrame.Angles(0, spin, 0)
				* CFrame.Angles(0, 0, math.rad(90))
		end
	end)
	later(seconds, function()
		alive = false
		conn:Disconnect()
		tween(core, 0.25, { Size = Vector3.one * 0.1 })
		for _, r in rings do
			tween(r, 0.25, { Transparency = 1 })
		end
		later(0.3, function()
			core:Destroy()
			for _, r in rings do
				r:Destroy()
			end
		end)
	end)
end

-- Tints the whole screen for a moment: a light wash of the effect's colour, then back.
-- `hold` keeps a softer tint on (Time Slow keeps the picture drained of colour while it lasts).
local tint: ColorCorrectionEffect? = nil
function Fx.screenTint(camera: Camera, color: Color3, hold: number?, drain: boolean?)
	if not tint or tint.Parent == nil then
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "SpinRiftFxTint"
		c.Parent = camera
		tint = c
	end
	local c = tint :: ColorCorrectionEffect
	c.TintColor = Color3.new(1, 1, 1):Lerp(color, 0.3)
	c.Brightness = 0
	c.Contrast = 0.1
	c.Saturation = if drain then -0.7 else 0.2
	local back = { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 }
	if hold and hold > 0 then
		tween(c, 0.2, { Brightness = 0, Contrast = 0.15, TintColor = Color3.new(1, 1, 1):Lerp(color, 0.25) })
		later(hold, function()
			tween(c, 0.3, back)
		end)
	else
		tween(c, 0.35, back)
	end
end

-- The big moment when a special move fires. `at` = where it happens (the ball, or the player),
-- `towards` = where the shot is heading (for bolts), `seconds` = how long a lasting effect runs.
function Fx.special(
	parent: Instance,
	camera: Camera,
	id: string,
	color: Color3,
	at: Vector3,
	towards: Vector3?,
	seconds: number?
)
	Fx.screenTint(camera, color, if id == "TimeSlow" then seconds else nil, id == "TimeSlow")
	Fx.shockwave(parent, at, color, 6)
	Fx.burst(parent, at, color, 24)
	if id == "Smash" and towards then
		Fx.lightning(parent, at, towards, color)
		Fx.lightning(parent, at, towards, Color3.new(1, 1, 1), 6)
	elseif id == "Curve" and towards then
		Fx.lightning(parent, at, towards, color, 5)
	elseif id == "Phantom" then
		for k = 1, 3 do
			later(0.06 * k, function()
				Fx.shockwave(parent, at + Vector3.new(0, 0, (k - 2) * 2.5), color, 4, 0.3)
			end)
		end
	elseif id == "Blind" then
		Fx.burst(parent, at, Color3.fromRGB(40, 0, 60), 60, 15)
	elseif id == "TimeSlow" then
		for k = 1, 3 do
			later(0.12 * k, function()
				Fx.shockwave(parent, at, color, 6 + 4 * k, 0.6)
			end)
		end
	elseif id == "Blink" then
		Fx.pillar(parent, at, color)
	elseif id == "Zigzag" and towards then
		Fx.lightning(parent, at, towards, color, 12)
		Fx.lightning(parent, at, towards, Color3.new(1, 1, 1), 12)
	elseif id == "QuantumStop" then
		Fx.screenTint(camera, color, 0.35, true)
		for k = 1, 2 do
			later(0.1 * k, function()
				Fx.shockwave(parent, at, color, 5 + 5 * k, 0.5)
			end)
		end
	elseif id == "Meteor" then
		Fx.burst(parent, at, Color3.fromRGB(255, 160, 40), 50, 40)
		Fx.pillar(parent, at - Vector3.new(0, 3, 0), color)
	elseif id == "EMP" then
		for k = 1, 3 do
			later(0.08 * k, function()
				Fx.shockwave(parent, at, color, 6 + 6 * k, 0.35)
			end)
		end
	elseif id == "Feint" and towards then
		-- a bolt that heads one way and a ghost bolt the other
		local mirror = Vector3.new(towards.X, towards.Y, at.Z - (towards.Z - at.Z))
		Fx.lightning(parent, at, mirror, color, 4)
		later(0.12, function()
			Fx.lightning(parent, at, towards, Color3.new(1, 1, 1), 4)
		end)
	elseif id == "SpinKick" then
		for k = 1, 4 do
			later(0.07 * k, function()
				Fx.shockwave(parent, at, color, 3 + 2.5 * k, 0.3)
			end)
		end
		Fx.burst(parent, at, Color3.new(1, 1, 1), 30, 30)
	elseif id == "Drain" then
		-- a pull from the opponent's side back to the user
		if towards then
			Fx.lightning(parent, towards, at, color, 6)
		end
		Fx.pillar(parent, at, color)
	end
end

-- A PERFECT return: a small shockwave and sparks at the ball (only special moves change the screen).
function Fx.perfect(parent: Instance, at: Vector3, color: Color3)
	Fx.shockwave(parent, at, color, 3, 0.25)
	Fx.burst(parent, at, color, 12, 18)
end

return Fx
