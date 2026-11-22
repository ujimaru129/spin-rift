--!strict
-- Battle Pass, season 1: 30 levels. Everyone gets the free rewards; Premium (a game pass, 400 Robux)
-- adds the premium rewards, including ones for levels already reached. Rewards are cosmetic only.
--
-- XP: win 120, loss 60, plus 200 for the first win of each day (UTC). Ranked and casual matches and
-- Bot matches count; the practice wall and the tutorial do not.

local BattlePass = {}

BattlePass.SEASON = 1
BattlePass.MAX_LEVEL = 30
BattlePass.XP_PER_LEVEL = 400
BattlePass.PRICE = 400 -- Robux, for the store text
BattlePass.XP = { win = 120, loss = 60, dailyWin = 200 }

-- level -> item id
BattlePass.Free = {
	[5] = "title_rookie",
	[10] = "paddle_magenta",
	[15] = "trail_ice",
	[20] = "title_rallyer",
	[25] = "paddle_emerald",
	[30] = "title_s1",
} :: { [number]: string }

BattlePass.Premium = {
	[2] = "trail_fire",
	[4] = "paddle_gold",
	[6] = "title_perfect",
	[8] = "trail_sakura",
	[10] = "paddle_sakura",
	[12] = "trail_gold",
	[14] = "paddle_ice",
	[16] = "title_smash",
	[18] = "trail_toxic",
	[20] = "paddle_lava",
	[22] = "title_phantom",
	[24] = "trail_galaxy",
	[26] = "paddle_void",
	[28] = "title_riftborn",
	[30] = "paddle_prism",
} :: { [number]: string }

-- Modes that give XP.
BattlePass.XP_MODES = { Easy = true, Normal = true, Hard = true, Online = true, Ranked = true }

function BattlePass.level(xp: number): number
	return math.clamp(math.floor(xp / BattlePass.XP_PER_LEVEL), 0, BattlePass.MAX_LEVEL)
end

-- XP into the current level, and XP needed for the next one (0 needed at max level).
function BattlePass.progress(xp: number): (number, number)
	local lv = BattlePass.level(xp)
	if lv >= BattlePass.MAX_LEVEL then
		return 0, 0
	end
	return xp - lv * BattlePass.XP_PER_LEVEL, BattlePass.XP_PER_LEVEL
end

-- Day number (UTC) used for the first-win-of-the-day bonus.
function BattlePass.day(unixTime: number): number
	return math.floor(unixTime / 86400)
end

-- XP for one finished match. lastWinDay = the day of this player's last bonus.
-- Returns the XP and whether the daily bonus was given.
function BattlePass.xpFor(mode: string, won: boolean, unixTime: number, lastWinDay: number): (number, boolean)
	if not BattlePass.XP_MODES[mode] then
		return 0, false
	end
	local xp = if won then BattlePass.XP.win else BattlePass.XP.loss
	local daily = won and BattlePass.day(unixTime) > lastWinDay
	if daily then
		xp += BattlePass.XP.dailyWin
	end
	return xp, daily
end

-- Every reward a player is owed at this level, free and (if premium) premium.
function BattlePass.rewardsUpTo(level: number, premium: boolean): { string }
	local out = {}
	for lv = 1, math.min(level, BattlePass.MAX_LEVEL) do
		if BattlePass.Free[lv] then
			table.insert(out, BattlePass.Free[lv])
		end
		if premium and BattlePass.Premium[lv] then
			table.insert(out, BattlePass.Premium[lv])
		end
	end
	return out
end

-- Items in `rewardsUpTo` that the player does not own yet.
function BattlePass.unclaimed(level: number, premium: boolean, owned: { [string]: boolean }): { string }
	local out = {}
	for _, id in BattlePass.rewardsUpTo(level, premium) do
		if not owned[id] then
			table.insert(out, id)
		end
	end
	return out
end

return BattlePass
