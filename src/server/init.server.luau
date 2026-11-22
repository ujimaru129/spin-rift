--!strict
-- Server entry point.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Palette"))
local MatchService = require(script.MatchService)
local ClosedTest = require(script.ClosedTest)

-- Night-time neon look. Lighting.Technology cannot be set from a script:
-- set it to Future in Studio (Lighting > Technology) for the best result.
local function setupLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(30, 34, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 40, 90)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true

	local function effect(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
		return e
	end

	local bloom = effect("BloomEffect", "SpinRiftBloom") :: BloomEffect
	bloom.Intensity = 0.9
	bloom.Size = 28
	bloom.Threshold = 0.9

	local color = effect("ColorCorrectionEffect", "SpinRiftColor") :: ColorCorrectionEffect
	color.Contrast = 0.12
	color.Saturation = 0.15
	color.TintColor = Color3.fromRGB(235, 240, 255)

	local atmosphere = effect("Atmosphere", "SpinRiftAtmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Palette.Night
	atmosphere.Decay = Color3.fromRGB(60, 20, 90)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.6
end

setupLighting()
ClosedTest.start()
MatchService.start()
