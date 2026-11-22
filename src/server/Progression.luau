--!strict
-- Battle Pass progress, cosmetic items and Premium.
--
-- Premium is a game pass. Put its id in PREMIUM_PASS_ID after creating it on the Creator Dashboard
-- (Monetization > Passes, 400 Robux). Until then, and always in Studio, the Premium button grants it
-- for free so the flow can be tested.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Season = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Season")
local BattlePass = require(Season:WaitForChild("BattlePass"))
local Cosmetics = require(Season:WaitForChild("Cosmetics"))
local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)

local Progression = {}

Progression.PREMIUM_PASS_ID = 0

export type Fire = (player: Player, event: { [string]: any }) -> ()

local fire: Fire = function(_player, _event) end

-- What the client needs to draw the pass and the customize screen.
function Progression.state(data: PlayerData.Data): { [string]: any }
	local owned = {}
	for id in data.items do
		table.insert(owned, id)
	end
	table.sort(owned)
	return {
		passXp = data.passXp,
		premium = data.premium,
		items = owned,
		equipped = table.clone(data.equipped),
	}
end

-- Gives every reward owed at the player's level (free, and premium if owned). Returns new items.
local function grantOwed(d: PlayerData.Data): { string }
	local new = BattlePass.unclaimed(BattlePass.level(d.passXp), d.premium, d.items)
	for _, id in new do
		d.items[id] = true
	end
	return new
end

-- XP and rewards for one finished match. Sends a PassUpdate to the player.
function Progression.awardMatch(player: Player, mode: string, won: boolean)
	local gained, daily, levelBefore, levelAfter = 0, false, 0, 0
	local newItems: { string } = {}
	local data = PlayerData.update(player.UserId, function(d)
		local xp, isDaily = BattlePass.xpFor(mode, won, os.time(), d.lastWinDay)
		gained, daily = xp, isDaily
		if xp == 0 then
			return
		end
		levelBefore = BattlePass.level(d.passXp)
		d.passXp += xp
		levelAfter = BattlePass.level(d.passXp)
		if isDaily then
			d.lastWinDay = BattlePass.day(os.time())
		end
		newItems = grantOwed(d)
	end)
	if gained == 0 then
		return
	end
	if levelAfter > levelBefore then
		Analytics.event(player, "PassLevel", levelAfter, { tostring(data.premium) })
	end
	fire(player, {
		kind = "PassUpdate",
		gained = gained,
		daily = daily,
		levelBefore = levelBefore,
		levelAfter = levelAfter,
		newItems = newItems,
		state = Progression.state(data),
	})
end

function Progression.grantItem(userId: number, id: string)
	if Cosmetics.get(id) then
		PlayerData.update(userId, function(d)
			d.items[id] = true
		end)
	end
end

-- Premium bought (or found already owned): grant it and every premium reward already reached.
function Progression.setPremium(player: Player)
	local newItems: { string } = {}
	local data = PlayerData.update(player.UserId, function(d)
		if not d.premium then
			d.premium = true
			newItems = grantOwed(d)
		end
	end)
	fire(player, {
		kind = "PassUpdate",
		gained = 0,
		levelBefore = BattlePass.level(data.passXp),
		levelAfter = BattlePass.level(data.passXp),
		newItems = newItems,
		premiumNow = true,
		state = Progression.state(data),
	})
end

-- Checks the game pass when a player joins.
function Progression.checkPremium(player: Player)
	if Progression.PREMIUM_PASS_ID == 0 or PlayerData.get(player.UserId).premium then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Progression.PREMIUM_PASS_ID)
	end)
	if ok and owns then
		Progression.setPremium(player)
	end
end

function Progression.buyPremium(player: Player)
	if PlayerData.get(player.UserId).premium then
		return
	end
	if Progression.PREMIUM_PASS_ID == 0 or RunService:IsStudio() then
		-- no pass set up yet, or testing in Studio: grant it so the flow can be tried
		Progression.setPremium(player)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, Progression.PREMIUM_PASS_ID)
end

-- Equip a cosmetic. kind = "paddle" | "trail" | "title"; id = "" for none.
function Progression.equip(player: Player, kind: unknown, id: unknown): boolean
	if type(kind) ~= "string" or type(id) ~= "string" then
		return false
	end
	local data = PlayerData.get(player.UserId)
	if not Cosmetics.canEquip(data.items, kind, id) then
		return false
	end
	data = PlayerData.update(player.UserId, function(d)
		(d.equipped :: any)[kind] = id
	end)
	fire(player, { kind = "PassUpdate", gained = 0, newItems = {}, state = Progression.state(data) })
	return true
end

function Progression.start(f: Fire)
	fire = f
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Progression.PREMIUM_PASS_ID then
			Analytics.event(player, "PremiumBought", BattlePass.PRICE)
			Progression.setPremium(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(Progression.checkPremium, player)
	end)
end

return Progression
