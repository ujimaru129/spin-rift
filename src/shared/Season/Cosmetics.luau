--!strict
-- Cosmetic items: paddles, ball trails and titles. They only change how things look; nothing here
-- affects play. Names are in Strings (Strings.item(id)).

local Cosmetics = {}

export type Kind = "paddle" | "trail" | "title"
export type Item = {
	id: string,
	kind: Kind,
	rgb: { number }?, -- paddles and trails
	material: string?, -- paddles: "Neon" | "ForceField" | "Glass"
}

local LIST: { Item } = {
	-- paddles
	{ id = "paddle_cyan", kind = "paddle", rgb = { 0, 229, 255 }, material = "Neon" },
	{ id = "paddle_magenta", kind = "paddle", rgb = { 255, 43, 214 }, material = "Neon" },
	{ id = "paddle_emerald", kind = "paddle", rgb = { 60, 230, 140 }, material = "Neon" },
	{ id = "paddle_gold", kind = "paddle", rgb = { 255, 205, 70 }, material = "Neon" },
	{ id = "paddle_sakura", kind = "paddle", rgb = { 255, 150, 200 }, material = "Neon" },
	{ id = "paddle_ice", kind = "paddle", rgb = { 170, 235, 255 }, material = "Glass" },
	{ id = "paddle_lava", kind = "paddle", rgb = { 255, 100, 30 }, material = "Neon" },
	{ id = "paddle_void", kind = "paddle", rgb = { 110, 60, 200 }, material = "ForceField" },
	{ id = "paddle_prism", kind = "paddle", rgb = { 240, 245, 255 }, material = "ForceField" },
	-- ball trails (used for your normal shots; ability shots keep their ability colour)
	{ id = "trail_fire", kind = "trail", rgb = { 255, 110, 40 } },
	{ id = "trail_ice", kind = "trail", rgb = { 150, 230, 255 } },
	{ id = "trail_sakura", kind = "trail", rgb = { 255, 160, 205 } },
	{ id = "trail_gold", kind = "trail", rgb = { 255, 215, 90 } },
	{ id = "trail_toxic", kind = "trail", rgb = { 140, 255, 60 } },
	{ id = "trail_galaxy", kind = "trail", rgb = { 150, 100, 255 } },
	-- titles
	{ id = "title_rookie", kind = "title" },
	{ id = "title_rallyer", kind = "title" },
	{ id = "title_perfect", kind = "title" },
	{ id = "title_smash", kind = "title" },
	{ id = "title_phantom", kind = "title" },
	{ id = "title_riftborn", kind = "title" },
	{ id = "title_s1", kind = "title" },
	{ id = "title_tester", kind = "title" },
}

local BY_ID: { [string]: Item } = {}
for _, item in LIST do
	BY_ID[item.id] = item
end

Cosmetics.List = LIST
Cosmetics.KINDS = { "paddle", "trail", "title" } :: { Kind }

-- Everyone owns these from the start.
Cosmetics.STARTER = { "paddle_cyan" }
Cosmetics.DEFAULT_EQUIPPED = { paddle = "paddle_cyan", trail = "", title = "" }

function Cosmetics.get(id: string): Item?
	return BY_ID[id]
end

function Cosmetics.ofKind(kind: Kind): { Item }
	local out = {}
	for _, item in LIST do
		if item.kind == kind then
			table.insert(out, item)
		end
	end
	return out
end

-- Can a player with these items equip `id` in slot `kind`? "" (nothing) is always allowed,
-- except for the paddle, which always has one.
function Cosmetics.canEquip(owned: { [string]: boolean }, kind: string, id: string): boolean
	if id == "" then
		return kind ~= "paddle"
	end
	local item = BY_ID[id]
	return item ~= nil and item.kind == kind and owned[id] == true
end

return Cosmetics
