--!strict
-- Buying shop items (see shared Season/Shop). Each item is a game pass: a purchase, or a pass
-- found already owned when the player joins, puts the item in the player's items. Items with no
-- pass yet (passId = 0), and every item in Studio, are granted for free so the flow can be tested.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Season")
local ShopItems = require(Season:WaitForChild("Shop"))
local PlayerData = require(script.Parent.PlayerData)
local Progression = require(script.Parent.Progression)
local Analytics = require(script.Parent.Analytics)

local Shop = {}

export type Fire = (player: Player, event: { [string]: any }) -> ()

local fire: Fire = function(_player, _event) end

-- Puts the item in the player's items and tells their client.
function Shop.grant(player: Player, id: string)
	local data = PlayerData.update(player.UserId, function(d)
		d.items[id] = true
	end)
	fire(player, {
		kind = "PassUpdate",
		gained = 0,
		newItems = { id },
		bought = id,
		state = Progression.state(data),
	})
end

-- The buy button. Unknown or already-owned items are ignored.
function Shop.buy(player: Player, id: unknown)
	if type(id) ~= "string" then
		return
	end
	local item = ShopItems.get(id)
	if not item or PlayerData.get(player.UserId).items[id] then
		return
	end
	if item.passId == 0 or RunService:IsStudio() then
		Shop.grant(player, id)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, item.passId)
end

-- On join: any shop pass the player already owns (bought on the website, or in another server
-- before their data was saved) becomes theirs here too.
function Shop.check(player: Player)
	local items = PlayerData.get(player.UserId).items
	for _, item in ShopItems.Items do
		if item.passId ~= 0 and not items[item.id] then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.passId)
			end)
			if ok and owns and player.Parent then
				Shop.grant(player, item.id)
			end
		end
	end
end

function Shop.start(f: Fire)
	fire = f
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local item = ShopItems.byPass(passId)
		if purchased and item then
			Analytics.event(player, "ShopBought", item.price, { item.id })
			Shop.grant(player, item.id)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(Shop.check, player)
	end)
end

return Shop
