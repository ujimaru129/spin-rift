--!strict
-- The eight abilities from the spec. Players bring two into a match and spend Rift gauge to use them.
--
-- "shot" abilities are armed first and change the player's next return.
-- "instant" abilities take effect as soon as they are used.

export type Def = {
	id: string,
	name: string,
	role: string, -- 攻撃 / かく乱 / 防御 / 妨害 / 移動
	kind: "shot" | "instant",
	cost: number,
	rgb: { number },
	effect: string,
	counter: string,
}

local Abilities = {}

-- Numbers each ability uses. Tuned with tools/balance.luau.
Abilities.Tuning = {
	Curve = { amount = 3.2, revealAt = 0.65 }, -- sideways bend (studs) and when a reader can tell
	Smash = { speed = 1.6, window = 0.65, arc = 0.55 }, -- speed x1.6, timing windows x0.65, flatter arc
	Phantom = { spread = 1.4 },
	TimeSlow = { factor = 0.5, length = 2, window = 1.3 }, -- a slowed ball is easier to time
	Barrier = { returnWindow = 2.3 }, -- the barrier's weak return is very easy to put away
	GravityWell = { factor = 0.5, length = 4 },
	Blink = { distance = 6 },
}

local LIST: { Def } = {
	{
		id = "Curve",
		name = "カーブショット",
		role = "攻撃",
		kind = "shot",
		cost = 3,
		rgb = { 180, 77, 255 },
		effect = "次の返球が、飛んでいる途中で横に曲がる",
		counter = "曲がる先を読んで先に動く",
	},
	{
		id = "Smash",
		name = "ライトニングスマッシュ",
		role = "攻撃",
		kind = "shot",
		cost = 5,
		rgb = { 255, 210, 63 },
		effect = "次の返球が1.6倍速。相手の打てる時間の幅が65%になる",
		counter = "リフトバリア、早めの位置取り",
	},
	{
		id = "Phantom",
		name = "ファントム",
		role = "かく乱",
		kind = "shot",
		cost = 4,
		rgb = { 255, 79, 216 },
		effect = "次の返球が3つに分身する。本物は1つだけ",
		counter = "台に影が落ちるのは本物だけ",
	},
	{
		id = "Blind",
		name = "ブラインドバウンド",
		role = "かく乱",
		kind = "shot",
		cost = 3,
		rgb = { 140, 150, 190 },
		effect = "次の返球が、弾むまで透明になる",
		counter = "音と台の影で読む",
	},
	{
		id = "TimeSlow",
		name = "タイムスロー",
		role = "防御",
		kind = "instant",
		cost = 4,
		rgb = { 79, 195, 255 },
		effect = "自分に向かってくる球が2秒間、半分の速さになり、打つタイミングも取りやすくなる",
		counter = "使わせた後に攻める",
	},
	{
		id = "Barrier",
		name = "リフトバリア",
		role = "防御",
		kind = "instant",
		cost = 8,
		rgb = { 60, 255, 224 },
		effect = "向かってくる球を取り逃したら、1回だけ自動で打ち返す（球はとても甘い）",
		counter = "返ってきた甘い球を決める",
	},
	{
		id = "GravityWell",
		name = "グラビティウェル",
		role = "妨害",
		kind = "instant",
		cost = 3,
		rgb = { 166, 107, 255 },
		effect = "相手の移動速度が4秒間半分になる",
		counter = "動かずにすむ位置で待つ",
	},
	{
		id = "Blink",
		name = "ブリンク",
		role = "移動",
		kind = "instant",
		cost = 2,
		rgb = { 125, 255, 154 },
		effect = "動いている方向へ6スタッド瞬間移動する",
		counter = "―",
	},
}

local BY_ID: { [string]: Def } = {}
for _, def in LIST do
	BY_ID[def.id] = def
end

Abilities.List = LIST
Abilities.DefaultLoadout = { "Curve", "Barrier" }
Abilities.SLOTS = 2

function Abilities.get(id: string): Def?
	return BY_ID[id]
end

-- A valid loadout is up to SLOTS distinct known ability ids. Anything else falls back to the default.
function Abilities.sanitize(loadout: unknown): { string }
	if type(loadout) ~= "table" then
		return table.clone(Abilities.DefaultLoadout)
	end
	local out: { string } = {}
	for _, id in loadout :: { any } do
		if type(id) == "string" and BY_ID[id] and not table.find(out, id) and #out < Abilities.SLOTS then
			table.insert(out, id)
		end
	end
	if #out == 0 then
		return table.clone(Abilities.DefaultLoadout)
	end
	return out
end

return Abilities
