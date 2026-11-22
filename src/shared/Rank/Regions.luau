--!strict
-- The five matchmaking regions, worked out from the country Roblox reports for a player.

local Regions = {}

Regions.List = { "NA", "SA", "EU", "ASIA", "OCE" }

Regions.Names = {
	NA = "北米",
	SA = "南米",
	EU = "ヨーロッパ",
	ASIA = "アジア",
	OCE = "オセアニア",
}

-- Regions close enough to share a match after 30 seconds of waiting.
Regions.Neighbors = {
	NA = { "SA", "EU" },
	SA = { "NA" },
	EU = { "NA", "ASIA" },
	ASIA = { "OCE", "EU" },
	OCE = { "ASIA" },
} :: { [string]: { string } }

local BY_COUNTRY: { [string]: string } = {}
local function add(region: string, codes: string)
	for code in string.gmatch(codes, "%a%a") do
		BY_COUNTRY[code] = region
	end
end
add("NA", "US CA MX GT CU DO HT HN NI SV CR PA JM PR BS TT")
add("SA", "BR AR CL CO PE VE EC BO PY UY GY SR")
add(
	"EU",
	"GB IE FR DE NL BE LU CH AT IT ES PT DK NO SE FI IS PL CZ SK HU RO BG GR HR SI RS BA ME MK AL "
		.. "EE LV LT UA BY MD RU TR CY MT IL AE SA QA KW BH OM JO LB EG MA DZ TN ZA NG KE GH"
)
add("ASIA", "JP KR KP CN TW HK MO MN SG MY TH VN PH ID KH LA MM BN IN PK BD LK NP KZ UZ")
add("OCE", "AU NZ FJ PG NC PF WS TO")

-- ISO 3166 country code (e.g. "JP") -> region. Unknown countries go to NA, the largest pool.
function Regions.fromCountry(code: string?): string
	if code == nil then
		return "NA"
	end
	return BY_COUNTRY[string.upper(code)] or "NA"
end

function Regions.areNeighbors(a: string, b: string): boolean
	if a == b then
		return true
	end
	return table.find(Regions.Neighbors[a] or {}, b) ~= nil
end

return Regions
