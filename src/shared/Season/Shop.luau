--!strict
-- The shop: single items sold for Robux, each as its own game pass. Owning the pass is the
-- purchase, so it survives anything that happens to our saved data; the server copies it into
-- the player's items when they join (see server/Shop).
--
-- passId = 0 until the pass is created on the Creator Dashboard (Monetization > Passes). Until
-- then, and always in Studio, the buy button grants the item for free so the flow can be tested.

local Shop = {}

export type Kind = "paddle" | "trail" | "ability" | "arena"
export type Item = {
	id: string, -- the item id put in the player's items ("ability_Feint", "arena_Aquarium", ...)
	kind: Kind,
	price: number, -- Robux, for the store text (the pass's own price is what is charged)
	passId: number,
}

Shop.Items = {
	{ id = "paddle_coral", kind = "paddle", price = 49, passId = 0 },
	{ id = "paddle_aqua", kind = "paddle", price = 79, passId = 0 },
	{ id = "paddle_obsidian", kind = "paddle", price = 99, passId = 0 },
	{ id = "trail_mint", kind = "trail", price = 49, passId = 0 },
	{ id = "trail_sunset", kind = "trail", price = 79, passId = 0 },
	{ id = "trail_crimson", kind = "trail", price = 99, passId = 0 },
	{ id = "ability_Feint", kind = "ability", price = 149, passId = 0 },
	{ id = "ability_SpinKick", kind = "ability", price = 149, passId = 0 },
	{ id = "ability_Drain", kind = "ability", price = 149, passId = 0 },
	{ id = "arena_Aquarium", kind = "arena", price = 199, passId = 0 },
} :: { Item }

local BY_ID: { [string]: Item } = {}
for _, item in Shop.Items do
	BY_ID[item.id] = item
end

function Shop.get(id: string): Item?
	return BY_ID[id]
end

function Shop.byPass(passId: number): Item?
	if passId == 0 then
		return nil
	end
	for _, item in Shop.Items do
		if item.passId == passId then
			return item
		end
	end
	return nil
end

return Shop
