--!strict
-- Colours of the Neon Rooftop arena and the two teams, taken from the concept art.

return {
	TeamA = Color3.fromRGB(0, 229, 255), -- cyan, the player
	TeamB = Color3.fromRGB(255, 43, 214), -- magenta, the opponent
	TableTop = Color3.fromRGB(8, 20, 38),
	Line = Color3.fromRGB(235, 245, 255),
	Platform = Color3.fromRGB(24, 26, 44),
	Metal = Color3.fromRGB(26, 31, 46),
	Shell = Color3.fromRGB(196, 206, 224),
	Night = Color3.fromRGB(11, 13, 36),
	WindowWarm = Color3.fromRGB(255, 210, 154),
	WindowCool = Color3.fromRGB(127, 243, 255),
	-- The ball itself: orange, so it stands out against the white and cyan neon of the table.
	Ball = Color3.fromRGB(255, 140, 30),

	-- Ball trail by shot kind: faster shots move from white to blue to purple.
	Shot = {
		Serve = Color3.fromRGB(235, 245, 255),
		Weak = Color3.fromRGB(235, 245, 255),
		Good = Color3.fromRGB(79, 195, 255),
		Perfect = Color3.fromRGB(180, 77, 255),
	} :: { [string]: Color3 },

	Grade = {
		Perfect = Color3.fromRGB(255, 210, 63),
		Good = Color3.fromRGB(0, 229, 255),
		Weak = Color3.fromRGB(200, 210, 230),
		Miss = Color3.fromRGB(255, 80, 96),
	} :: { [string]: Color3 },
}
