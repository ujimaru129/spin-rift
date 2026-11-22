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
}

local LOOKS: { [string]: Look } = {
	-- night city (same as the server's defaults)
	Rooftop = {
		clock = 0,
		brightness = 1.2,
		ambient = Color3.fromRGB(30, 34, 70),
		outdoor = Color3.fromRGB(40, 40, 90),
		atmosphere = Color3.fromRGB(11, 13, 36),
		decay = Color3.fromRGB(60, 20, 90),
		haze = 1.6,
		density = 0.32,
		tint = Color3.fromRGB(235, 240, 255),
	},
	-- sunset over floating gardens
	Sakura = {
		clock = 17.6,
		brightness = 2,
		ambient = Color3.fromRGB(120, 80, 110),
		outdoor = Color3.fromRGB(170, 120, 150),
		atmosphere = Color3.fromRGB(233, 160, 190),
		decay = Color3.fromRGB(110, 70, 140),
		haze = 2.2,
		density = 0.36,
		tint = Color3.fromRGB(255, 236, 244),
	},
}

function ArenaLook.apply(arenaId: string?)
	local look = LOOKS[arenaId or "Rooftop"] or LOOKS.Rooftop
	Lighting.ClockTime = look.clock
	Lighting.Brightness = look.brightness
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = look.atmosphere
		atmosphere.Decay = look.decay
		atmosphere.Haze = look.haze
		atmosphere.Density = look.density
	end
	local color = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if color then
		color.TintColor = look.tint
	end
end

return ArenaLook
