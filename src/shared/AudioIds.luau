--!strict
-- The game's uploaded sounds. They are made by tools/audio/make.py; after uploading a file, put its
-- asset id here ("rbxassetid://..."). An empty id plays nothing, so the game runs without them.

local AudioIds = {}

AudioIds.Music = {
	menu = "",
	Rooftop = "",
	Sakura = "",
	ranked = "",
	final = "",
} :: { [string]: string }

-- One sheet holds every special-move sound: one each SLOT seconds, in this order.
AudioIds.Sheet = ""
AudioIds.SLOT = 3
AudioIds.Sfx = {
	"Curve",
	"Smash",
	"Phantom",
	"Blind",
	"TimeSlow",
	"Barrier",
	"GravityWell",
	"Blink",
	"Zigzag",
	"QuantumStop",
	"Meteor",
	"EMP",
	"BarrierHit", -- the barrier returns a ball
	"Win",
	"Lose",
}

-- Where a sound sits in the sheet, in seconds (nil when there is none by that name).
function AudioIds.region(name: string): (number?, number?)
	local i = table.find(AudioIds.Sfx, name)
	if not i then
		return nil, nil
	end
	local from = (i - 1) * AudioIds.SLOT
	return from, from + AudioIds.SLOT - 0.1
end

return AudioIds
