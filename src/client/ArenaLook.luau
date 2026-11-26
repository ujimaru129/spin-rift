--!strict
-- Lighting for each arena. Changes made from a LocalScript only affect this player's screen, so
-- players in different arenas on the same server each see their own sky.

local Lighting = game:GetService("Lighting")

local ArenaLook = {}

type Look = {
	clock: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	atmosphere: Color3,
	decay: Color3,
	haze: number,
	density: number,
	tint: Color3,
	-- plain distance fog instead of the Atmosphere, which turns black at night
	fog: { color: Color3, from: number, to: number }?,
}

local LOOKS: { [string]: Look } = {
	-- night city (same as the server's defaults)
	Rooftop = {
		clock = 0,
		brightness = 1.2,
		ambient = Color3.fromRGB(62, 58, 100),
		outdoor = Color3.fromRGB(62, 58, 100),
		fog = { color = Color3.fromRGB(46, 22, 84), from = 70, to = 850 },
		atmosphere = Color3.fromRGB(11, 13, 36),
		decay = Color3.fromRGB(60, 20, 90),
		haze = 1.6,
		density = 0.32,
		tint = Color3.fromRGB(235, 240, 255),
	},
	-- sunset over floating gardens (the sky itself is painted by Garden; pink distance fog)
	Sakura = {
		clock = 17.8,
		brightness = 2,
		ambient = Color3.fromRGB(125, 90, 130),
		outdoor = Color3.fromRGB(170, 125, 160),
		fog = { color = Color3.fromRGB(235, 160, 180), from = 220, to = 1900 },
		atmosphere = Color3.fromRGB(233, 160, 190),
		decay = Color3.fromRGB(110, 70, 140),
		haze = 2.2,
		density = 0.36,
		tint = Color3.fromRGB(255, 238, 242),
	},
}

local atmosphere: Atmosphere? = nil

function ArenaLook.apply(arenaId: string?)
	local look = LOOKS[arenaId or "Rooftop"] or LOOKS.Rooftop
	Lighting.ClockTime = look.clock
	Lighting.Brightness = look.brightness
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	local fog = look.fog
	Lighting.FogColor = if fog then fog.color else Color3.new(0, 0, 0)
	Lighting.FogStart = if fog then fog.from else 0
	Lighting.FogEnd = if fog then fog.to else 100000
	local air = atmosphere or Lighting:FindFirstChildOfClass("Atmosphere")
	atmosphere = air
	if air then
		air.Parent = if fog then nil else Lighting
		air.Color = look.atmosphere
		air.Decay = look.decay
		air.Haze = look.haze
		air.Density = look.density
	end
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if color then
		color.TintColor = look.tint
	end
end

return ArenaLook
