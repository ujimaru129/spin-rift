--!strict
-- Sends play data to Roblox's built-in analytics (Creator Dashboard > Analytics).
-- Retention (how many players come back the next day) is measured by Roblox automatically;
-- these events show where new players drop off and what they play.
--
-- Onboarding funnel steps (each counted once per player by Roblox):
--   1 Joined, 2 TutorialStarted, 3 FirstReturn, 4 FirstPerfect, 5 FirstAbility,
--   6 TutorialDone, 7 FirstMatchFinished, 8 FirstRankedFinished

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

Analytics.Funnel = {
	Joined = 1,
	TutorialStarted = 2,
	FirstReturn = 3,
	FirstPerfect = 4,
	FirstAbility = 5,
	TutorialDone = 6,
	FirstMatchFinished = 7,
	FirstRankedFinished = 8,
}

-- What this module sent, for tests: { kind, name, value? }
Analytics.log = {} :: { { kind: string, name: string, value: any, fields: { string }? } }

function Analytics.funnel(player: Player, step: string)
	local n = Analytics.Funnel[step]
	if not n then
		return
	end
	table.insert(Analytics.log, { kind = "funnel", name = step, value = n })
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, n, step)
	end)
end

-- A custom event. `fields` are up to three short strings shown as breakdowns in the dashboard.
function Analytics.event(player: Player, name: string, value: number?, fields: { string }?)
	table.insert(Analytics.log, { kind = "event", name = name, value = value, fields = fields })
	pcall(function()
		local custom = {}
		for i, f in fields or {} do
			if i <= 3 then
				custom[`CustomField0{i}`] = f
			end
		end
		AnalyticsService:LogCustomEvent(player, name, value or 1, custom)
	end)
end

return Analytics
