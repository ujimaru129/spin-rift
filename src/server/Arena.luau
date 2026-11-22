--!strict
-- Builds the Neon Rooftop arena out of Parts, so the prototype runs without any uploaded assets.
-- Everything is placed relative to `origin`, the centre of the table at floor level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Rally"):WaitForChild("Config"))
local Palette = require(Shared:WaitForChild("Palette"))

local Arena = {}

type PartProps = {
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	collide: boolean?,
	reflectance: number?,
	name: string?,
}

local function part(parent: Instance, p: PartProps): Part
	local x = Instance.new("Part")
	x.Name = p.name or "Part"
	x.Anchored = true
	x.Size = p.size
	x.CFrame = p.cframe
	x.Color = p.color
	x.Material = p.material or Enum.Material.SmoothPlastic
	x.Shape = p.shape or Enum.PartType.Block
	x.Transparency = p.transparency or 0
	x.CanCollide = if p.collide == nil then true else p.collide
	x.Reflectance = p.reflectance or 0
	x.TopSurface = Enum.SurfaceType.Smooth
	x.BottomSurface = Enum.SurfaceType.Smooth
	x.CastShadow = p.material ~= Enum.Material.Neon
	x.Parent = parent
	return x
end

-- A vertical disc (Roblox cylinders run along X, so turn them on end).
local function disc(
	parent: Instance,
	at: Vector3,
	radius: number,
	height: number,
	color: Color3,
	material: Enum.Material?
)
	return part(parent, {
		size = Vector3.new(height, radius * 2, radius * 2),
		cframe = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color = color,
		material = material,
		shape = Enum.PartType.Cylinder,
	})
end

local function buildTable(model: Model, o: Vector3)
	local T = Config.Table
	local top = T.surfaceY
	part(model, {
		name = "TableTop",
		size = Vector3.new(T.halfLength * 2, 0.4, T.halfWidth * 2),
		cframe = CFrame.new(o + Vector3.new(0, top - 0.2, 0)),
		color = Palette.TableTop,
		reflectance = 0.12,
	})
	local function line(sx: number, sz: number, x: number, z: number)
		part(model, {
			name = "Line",
			size = Vector3.new(sx, 0.05, sz),
			cframe = CFrame.new(o + Vector3.new(x, top + 0.01, z)),
			color = Palette.Line,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
	local L, W = T.halfLength, T.halfWidth
	line(L * 2, 0.15, 0, W - 0.075)
	line(L * 2, 0.15, 0, -W + 0.075)
	line(0.15, W * 2, L - 0.075, 0)
	line(0.15, W * 2, -L + 0.075, 0)
	line(L * 2, 0.08, 0, 0)
	-- glowing rim under the top
	part(model, {
		name = "Rim",
		size = Vector3.new(L * 2 + 0.3, 0.12, W * 2 + 0.3),
		cframe = CFrame.new(o + Vector3.new(0, top - 0.45, 0)),
		color = Palette.TeamA,
		material = Enum.Material.Neon,
		collide = false,
	})
	-- net
	part(model, {
		name = "Net",
		size = Vector3.new(0.08, T.netHeight, W * 2 + 0.8),
		cframe = CFrame.new(o + Vector3.new(0, top + T.netHeight / 2, 0)),
		color = Palette.Line,
		material = Enum.Material.ForceField,
		transparency = 0.2,
		collide = false,
	})
	part(model, {
		name = "NetTop",
		size = Vector3.new(0.1, 0.1, W * 2 + 0.8),
		cframe = CFrame.new(o + Vector3.new(0, top + T.netHeight, 0)),
		color = Palette.Line,
		material = Enum.Material.Neon,
		collide = false,
	})
	for _, x in { -L * 0.55, L * 0.55 } do
		part(model, {
			name = "Pedestal",
			size = Vector3.new(2.2, top - 0.4, 3.2),
			cframe = CFrame.new(o + Vector3.new(x, (top - 0.4) / 2, 0)),
			color = Palette.Metal,
			material = Enum.Material.Metal,
		})
		part(model, {
			name = "PedestalBand",
			size = Vector3.new(2.3, 0.12, 3.3),
			cframe = CFrame.new(o + Vector3.new(x, 1, 0)),
			color = Palette.TeamA,
			material = Enum.Material.Neon,
			collide = false,
		})
	end
end

local function buildPlatform(model: Model, o: Vector3)
	disc(model, o + Vector3.new(0, -0.5, 0), 22, 1, Palette.Platform).Reflectance = 0.08
	local rim = disc(model, o + Vector3.new(0, -0.55, 0), 22.4, 0.9, Palette.TeamA, Enum.Material.Neon)
	rim.CanCollide = false
	local under = disc(model, o + Vector3.new(0, -3, 0), 16, 4, Palette.Metal, Enum.Material.Metal)
	under.CanCollide = false
	local core = disc(model, o + Vector3.new(0, -5.2, 0), 5, 0.6, Palette.TeamA, Enum.Material.Neon)
	core.CanCollide = false
	-- floor rings around each player's zone
	for _, side in { -1, 1 } do
		local ring = disc(
			model,
			o + Vector3.new(side * 14, 0.02, 0),
			4.2,
			0.06,
			if side == -1 then Palette.TeamA else Palette.TeamB,
			Enum.Material.Neon
		)
		ring.CanCollide = false
		ring.Transparency = 0.55
	end
end

-- Distant buildings with lit windows, as in the concept art.
local function buildSkyline(model: Model, o: Vector3, seed: number)
	local rng = Random.new(seed)
	for i = 1, 36 do
		local a = (i / 36) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local r = rng:NextNumber(70, 140)
		local w, d = rng:NextNumber(14, 26), rng:NextNumber(14, 26)
		local h = rng:NextNumber(60, 140)
		local topY = rng:NextNumber(-20, 60)
		local at = o + Vector3.new(math.cos(a) * r, topY - h / 2, math.sin(a) * r)
		local b = part(model, {
			name = "Building",
			size = Vector3.new(w, h, d),
			cframe = CFrame.lookAt(at, Vector3.new(o.X, at.Y, o.Z)),
			color = Color3.fromRGB(10, 12, 22),
			collide = false,
		})
		-- window rows on the face that looks at the arena
		local rows = math.floor(h / 5)
		for k = 1, rows do
			if rng:NextNumber() < 0.45 then
				local warm = rng:NextNumber() < 0.65
				local strip = part(model, {
					name = "Windows",
					size = Vector3.new(w * rng:NextNumber(0.3, 0.9), 0.9, 0.2),
					cframe = b.CFrame * CFrame.new(rng:NextNumber(-w * 0.1, w * 0.1), -h / 2 + k * 5, -d / 2 - 0.1),
					color = if warm then Palette.WindowWarm else Palette.WindowCool,
					material = Enum.Material.Neon,
					collide = false,
				})
				strip.Transparency = rng:NextNumber(0, 0.4)
			end
		end
	end
end

-- Invisible walls that keep each player in their own half of the floor.
local function buildZone(model: Model, o: Vector3)
	local near, far = Config.HitX - 0.5, 18.5 -- |X| range a player may stand in
	local halfZ = 8.5
	local w = far - near
	local function wall(size: Vector3, at: Vector3)
		part(model, {
			name = "ZoneWall",
			size = size,
			cframe = CFrame.new(o + at),
			color = Color3.new(1, 1, 1),
			transparency = 1,
		})
	end
	for _, side in { -1, 1 } do
		local cx = side * (near + far) / 2
		wall(Vector3.new(1, 20, halfZ * 2 + 2), Vector3.new(side * (far + 0.5), 10, 0))
		wall(Vector3.new(1, 20, halfZ * 2 + 2), Vector3.new(side * (near - 0.5), 10, 0))
		wall(Vector3.new(w, 20, 1), Vector3.new(cx, 10, halfZ + 0.5))
		wall(Vector3.new(w, 20, 1), Vector3.new(cx, 10, -halfZ - 0.5))
	end
end

local SAKURA_PINK = Color3.fromRGB(255, 166, 201)
local SAKURA_GLOW = Color3.fromRGB(255, 111, 174)
local LANTERN = Color3.fromRGB(255, 179, 107)

local function sakuraTree(model: Model, at: Vector3, scale: number, rng: Random)
	part(model, {
		name = "Trunk",
		size = Vector3.new(1.2, 8, 1.2) * scale,
		cframe = CFrame.new(at + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)),
		color = Color3.fromRGB(74, 49, 56),
		material = Enum.Material.Wood,
		collide = false,
	})
	for _ = 1, 6 do
		local blob = part(model, {
			name = "Blossom",
			size = Vector3.one * rng:NextNumber(4, 6.5) * scale,
			cframe = CFrame.new(
				at + Vector3.new(rng:NextNumber(-3.5, 3.5), rng:NextNumber(8, 11.5), rng:NextNumber(-3.5, 3.5)) * scale
			),
			color = SAKURA_PINK,
			shape = Enum.PartType.Ball,
			collide = false,
		})
		blob.Transparency = 0.05
	end
end

-- Floating garden islands at sunset, cherry trees and lanterns (Sakura Float).
local function buildSakura(model: Model, o: Vector3, seed: number)
	local rng = Random.new(seed)
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = rng:NextNumber(45, 110)
		local s = rng:NextNumber(1, 2.6)
		local at = o + Vector3.new(math.cos(a) * r, rng:NextNumber(-30, 20), math.sin(a) * r)
		part(model, {
			name = "Island",
			size = Vector3.new(16, 3, 16) * s,
			cframe = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			color = Color3.fromRGB(143, 191, 138),
			material = Enum.Material.Grass,
			collide = false,
		})
		part(model, {
			name = "IslandRock",
			size = Vector3.new(13, 10, 13) * s,
			cframe = CFrame.new(at - Vector3.new(0, 6.5 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			color = Color3.fromRGB(107, 90, 115),
			material = Enum.Material.Rock,
			collide = false,
		})
		if rng:NextNumber() < 0.8 then
			sakuraTree(model, at + Vector3.new(0, 1.5 * s, 0), s * 0.8, rng)
		end
	end
	-- the big tree behind the table
	sakuraTree(model, o + Vector3.new(-6, -14, -44), 3, rng)
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(26, 60)
		local lantern = part(model, {
			name = "Lantern",
			size = Vector3.one * 0.9,
			cframe = CFrame.new(o + Vector3.new(math.cos(a) * r, rng:NextNumber(-4, 16), math.sin(a) * r)),
			color = LANTERN,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
			collide = false,
		})
		local light = Instance.new("PointLight")
		light.Color = LANTERN
		light.Range = 8
		light.Brightness = 1
		light.Parent = lantern
	end
	-- falling petals (the default particle is a soft dot, tinted pink)
	local emitterPart = part(model, {
		name = "Petals",
		size = Vector3.new(60, 1, 60),
		cframe = CFrame.new(o + Vector3.new(0, 30, 0)),
		color = SAKURA_PINK,
		transparency = 1,
		collide = false,
	})
	local petals = Instance.new("ParticleEmitter")
	petals.Color = ColorSequence.new(SAKURA_PINK)
	petals.LightEmission = 0.3
	petals.Size = NumberSequence.new(0.25)
	petals.Rate = 40
	petals.Lifetime = NumberRange.new(8, 12)
	petals.Speed = NumberRange.new(2, 4)
	petals.SpreadAngle = Vector2.new(30, 30)
	petals.Acceleration = Vector3.new(1.2, -1.5, 0)
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.Parent = emitterPart
end

-- Recolours the neon parts shared by every arena (rims, rings, bands) for a theme.
local function tint(model: Model, from: Color3, to: Color3)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon and p.Color == from then
			p.Color = to
		end
	end
end

-- arenaId: "Rooftop" (default) or "Sakura".
function Arena.build(origin: Vector3, seed: number, arenaId: string?): Model
	local model = Instance.new("Model")
	model.Name = if arenaId == "Sakura" then "SakuraFloat" else "NeonRooftop"
	buildPlatform(model, origin)
	buildTable(model, origin)
	if arenaId == "Sakura" then
		tint(model, Palette.TeamA, SAKURA_GLOW)
		buildSakura(model, origin, seed)
	else
		buildSkyline(model, origin, seed)
	end
	buildZone(model, origin)
	model.Parent = workspace
	return model
end

-- Where a player on `side` (-1 or 1) stands at the start, facing the table.
function Arena.playerSpawn(origin: Vector3, side: number): CFrame
	local at = origin + Vector3.new(side * 14, 3.5, 0)
	return CFrame.lookAt(at, at - Vector3.xAxis * side)
end

-- The opponent avatar: a shell-and-neon athlete built from Parts, facing the table.
function Arena.buildOpponent(origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "RiftBot"
	local root = part(model, {
		name = "Root",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(origin),
		color = Palette.Metal,
		transparency = 1,
		collide = false,
	})
	model.PrimaryPart = root
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?,
		shape: Enum.PartType?
	)
		part(model, {
			name = name,
			size = size,
			cframe = root.CFrame * offset,
			color = color,
			material = material,
			shape = shape,
			collide = false,
		})
	end
	-- the avatar faces -X (toward the table) when the root is unrotated
	piece("LegL", Vector3.new(0.7, 2.4, 0.7), CFrame.new(0, 1.2, -0.6), Palette.Metal, Enum.Material.Metal)
	piece("LegR", Vector3.new(0.7, 2.4, 0.7), CFrame.new(0, 1.2, 0.6), Palette.Metal, Enum.Material.Metal)
	piece("Torso", Vector3.new(1.3, 2, 2.2), CFrame.new(0, 3.3, 0), Palette.Metal, Enum.Material.Metal)
	piece("Chest", Vector3.new(0.6, 1.5, 1.9), CFrame.new(-0.5, 3.5, 0), Palette.Shell)
	piece("Core", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.85, 3.6, 0), Palette.TeamB, Enum.Material.Neon)
	piece("Belt", Vector3.new(1.4, 0.18, 2.3), CFrame.new(0, 2.35, 0), Palette.TeamB, Enum.Material.Neon)
	piece("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.95, 0), Palette.Shell, nil, Enum.PartType.Ball)
	piece("Visor", Vector3.new(0.3, 0.35, 1.1), CFrame.new(-0.55, 5.0, 0), Palette.TeamB, Enum.Material.Neon)
	piece(
		"ArmL",
		Vector3.new(0.5, 1.8, 0.5),
		CFrame.new(-0.2, 3.3, -1.35) * CFrame.Angles(math.rad(-15), 0, 0),
		Palette.Metal,
		Enum.Material.Metal
	)
	piece("ArmR", Vector3.new(1.8, 0.5, 0.5), CFrame.new(-1.0, 4.2, 1.3), Palette.Metal, Enum.Material.Metal)
	piece(
		"Paddle",
		Vector3.new(0.15, 1.6, 1.6),
		CFrame.new(-2.2, 4.4, 1.3) * CFrame.Angles(math.rad(90), 0, 0),
		Palette.TeamB,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	model.Parent = workspace
	return model
end

-- Gives a character a glowing paddle in the right hand.
function Arena.attachPaddle(character: Model, color: Color3, material: Enum.Material?)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("SpinRiftPaddle")
	if old then
		old:Destroy()
	end
	local paddle = Instance.new("Part")
	paddle.Name = "SpinRiftPaddle"
	paddle.Shape = Enum.PartType.Cylinder
	paddle.Size = Vector3.new(0.15, 1.7, 1.7)
	paddle.Color = color
	paddle.Material = material or Enum.Material.Neon
	paddle.CanCollide = false
	paddle.CanQuery = false
	paddle.Massless = true
	paddle.CFrame = hand.CFrame * CFrame.new(0, -1.1, 0) * CFrame.Angles(0, math.rad(90), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = paddle
	weld.Parent = paddle
	paddle.Parent = character
end

return Arena
