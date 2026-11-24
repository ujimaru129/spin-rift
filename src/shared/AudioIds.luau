--!strict
-- The game's uploaded sounds. They are made by tools/audio/make.py; after uploading a file, put its
-- asset id here ("rbxassetid://..."). An empty id plays nothing, so the game runs without them.

local AudioIds = {}

AudioIds.Music = {
	menu = "rbxassetid://124393392092962",
	Rooftop = "rbxassetid://91638357276707",
	Sakura = "rbxassetid://70830084292749",
	ranked = "rbxassetid://111298671390613",
	final = "rbxassetid://128486904618584",
} :: { [string]: string }

-- One sheet holds every special-move sound: one each SLOT seconds, in this order.
AudioIds.Sheet = "rbxassetid://128938304580471"
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

-- A second sheet for the ball itself: one sound every HIT_SLOT seconds.
AudioIds.HitSheet = ""
AudioIds.HIT_SLOT = 0.5
AudioIds.Hits = { "Hit", "PerfectHit", "Bounce" }

function AudioIds.hitRegion(name: string): (number?, number?)
	local i = table.find(AudioIds.Hits, name)
	if not i then
		return nil, nil
	end
	local from = (i - 1) * AudioIds.HIT_SLOT
	return from, from + AudioIds.HIT_SLOT - 0.05
end

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
