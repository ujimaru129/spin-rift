return function(loader, expect)
	local Rank = loader.require("src/shared/Rank")
	local Rating, Regions, Matchmaker = Rank.Rating, Rank.Regions, Rank.Matchmaker

	local function entry(id, rating, region, joinedAt)
		return { id = id, rating = rating, region = region or "ASIA", joinedAt = joinedAt or 0 }
	end

	local function ids(pairs)
		local out = {}
		for _, p in pairs do
			local a, b = p[1].id, p[2].id
			if a > b then
				a, b = b, a
			end
			table.insert(out, a .. "+" .. b)
		end
		table.sort(out)
		return table.concat(out, ",")
	end

	return {
		{
			"beating an equal opponent gains about 20, losing costs the same",
			function()
				expect(Rating.delta(1200, 1200, true, 50)).toBe(20)
				expect(Rating.delta(1200, 1200, false, 50)).toBe(-20)
			end,
		},
		{
			"an upset moves more than an expected result, within 8..36",
			function()
				local upset = Rating.delta(1000, 1400, true, 50)
				local expected = Rating.delta(1400, 1000, true, 50)
				expect(upset > 30).toBeTruthy()
				expect(expected).toBe(Rating.MIN_DELTA)
				expect(Rating.delta(800, 2400, true, 50)).toBe(Rating.MAX_DELTA)
			end,
		},
		{
			"the first 10 games move the rating twice as much",
			function()
				expect(Rating.delta(1000, 1000, true, 0)).toBe(40)
				expect(Rating.delta(1000, 1000, true, 9)).toBe(40)
				expect(Rating.delta(1000, 1000, true, 10)).toBe(20)
			end,
		},
		{
			"ranks follow the spec's rating bands, with III, II and I",
			function()
				expect(Rating.tier(1000).label).toBe("ブロンズ II")
				expect(Rating.tier(700).label).toBe("ブロンズ III")
				expect(Rating.tier(1099).label).toBe("ブロンズ I")
				expect(Rating.tier(1100).label).toBe("シルバー III")
				expect(Rating.tier(1299).label).toBe("シルバー I")
				expect(Rating.tier(1300).label).toBe("ゴールド III")
				expect(Rating.tier(1500).label).toBe("ダイヤ III")
				expect(Rating.tier(1749).label).toBe("ダイヤ I")
				expect(Rating.tier(1750).label).toBe("マスター")
				expect(Rating.tier(2600).id).toBe("Master")
				expect(Rating.changedTier(1290, 1310)).toBe(true)
				expect(Rating.changedTier(1310, 1320)).toBe(false)
			end,
		},
		{
			"a new season pulls ratings toward 1000",
			function()
				expect(Rating.seasonReset(1800)).toBe(1560)
				expect(Rating.seasonReset(800)).toBe(860)
				expect(Rating.seasonReset(1000)).toBe(1000)
			end,
		},
		{
			"countries map to the five regions",
			function()
				expect(Regions.fromCountry("JP")).toBe("ASIA")
				expect(Regions.fromCountry("us")).toBe("NA")
				expect(Regions.fromCountry("BR")).toBe("SA")
				expect(Regions.fromCountry("DE")).toBe("EU")
				expect(Regions.fromCountry("AU")).toBe("OCE")
				expect(Regions.fromCountry("ZZ")).toBe("NA")
				expect(Regions.fromCountry(nil)).toBe("NA")
				expect(Regions.areNeighbors("ASIA", "OCE")).toBe(true)
				expect(Regions.areNeighbors("ASIA", "SA")).toBe(false)
			end,
		},
		{
			"the search widens with waiting time as in the spec",
			function()
				expect(Matchmaker.window(0).maxDiff).toBe(50)
				expect(Matchmaker.window(10).maxDiff).toBe(150)
				expect(Matchmaker.window(30).regions).toBe("neighbors")
				expect(Matchmaker.window(60).maxDiff).toBe(math.huge)
				expect(Matchmaker.offerBot(89)).toBe(false)
				expect(Matchmaker.offerBot(90)).toBe(true)
				expect(Matchmaker.describe(12)).toBe("レート差 ±150・同じ地域")
			end,
		},
		{
			"close ratings in one region are paired at once; far ones wait",
			function()
				local q = { entry("a", 1000), entry("b", 1040), entry("c", 1500) }
				local pairs, rest = Matchmaker.pair(q, 1)
				expect(ids(pairs)).toBe("a+b")
				expect(#rest).toBe(1)
				expect(rest[1].id).toBe("c")
			end,
		},
		{
			"each player gets the closest-rated partner",
			function()
				local q = { entry("a", 1000, "ASIA", 0), entry("b", 1140, "ASIA", 5), entry("c", 1010, "ASIA", 6) }
				local pairs = Matchmaker.pair(q, 20)
				expect(ids(pairs)).toBe("a+c")
			end,
		},
		{
			"other regions are only matched after waiting: neighbours at 30 s, everyone at 60 s",
			function()
				local q = { entry("jp", 1000, "ASIA", 0), entry("au", 1000, "OCE", 0), entry("br", 1000, "SA", 0) }
				expect(#Matchmaker.pair(q, 29)).toBe(0)
				local at30 = Matchmaker.pair(q, 31)
				expect(ids(at30)).toBe("au+jp")
				local two = { entry("jp", 1000, "ASIA", 0), entry("br", 1000, "SA", 0) }
				expect(#Matchmaker.pair(two, 59)).toBe(0)
				expect(#Matchmaker.pair(two, 61)).toBe(1)
			end,
		},
		{
			"the longest-waiting player's window decides",
			function()
				-- a waited 15 s (±150); b just arrived (±50). 120 apart: allowed because of a.
				local q = { entry("a", 1000, "ASIA", 0), entry("b", 1120, "ASIA", 15) }
				expect(#Matchmaker.pair(q, 15)).toBe(1)
			end,
		},
	}
end
