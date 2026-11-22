--!strict
-- Every word the player sees, in Japanese and English. Clients pick the language from the
-- player's Roblox locale and can switch it from the menu.
--
-- Strings.t("key", { name = value }) returns the text with {name} filled in.

local Abilities = require(script.Parent:WaitForChild("Rally"):WaitForChild("Abilities"))

local Strings = {}

export type Locale = "ja" | "en"

local current: Locale = "ja"

local T: { [string]: { ja: string, en: string } } = {
	-- menu
	["menu.subtitle"] = { ja = "クローズドテスト版", en = "Closed test" },
	["menu.loadingRank"] = { ja = "ランク：読み込み中…", en = "Rank: loading…" },
	["menu.ranked"] = { ja = "ランク戦", en = "Ranked" },
	["menu.casual"] = {
		ja = "カジュアル戦（このサーバーの人と）",
		en = "Casual (players in this server)",
	},
	["menu.practice"] = { ja = "練習", en = "Practice" },
	["menu.wall"] = { ja = "壁打ち", en = "Wall" },
	["menu.botEasy"] = { ja = "Bot：やさしい", en = "Bot: Easy" },
	["menu.botNormal"] = { ja = "Bot：ふつう", en = "Bot: Normal" },
	["menu.botHard"] = { ja = "Bot：つよい", en = "Bot: Hard" },
	["menu.tutorial"] = { ja = "はじめての人：チュートリアル", en = "New here? Tutorial" },
	["menu.tryTutorial"] = {
		ja = "はじめての人は、まずチュートリアル（1〜2分）から！",
		en = "First time? Start with the tutorial (1-2 minutes)!",
	},
	["menu.pick"] = { ja = "能力を2つ選ぶ", en = "Pick 2 abilities" },
	["menu.help"] = {
		ja = "移動：WASD・左スティック\n打つ：クリック・スペース・R2・画面の「打つ」\nコース：マウスの左右・右スティック・移動の向き\n能力：Q・E（L1・L2）",
		en = "Move: WASD / left stick\nHit: click, Space, R2 or the HIT button\nAim: mouse left/right, right stick or moving\nAbilities: Q, E (L1, L2)",
	},
	["menu.leaderboard"] = { ja = "ランキングを見る", en = "Leaderboard" },
	["menu.feedback"] = { ja = "感想・バグを送る", en = "Send feedback" },
	["menu.language"] = { ja = "English", en = "日本語" },
	["menu.profile"] = {
		ja = "{tier}  レート {rating}  {wins}勝{losses}敗  {region}{extra}",
		en = "{tier}  Rating {rating}  {wins}W {losses}L  {region}{extra}",
	},
	["menu.placement"] = { ja = "（あと{n}試合で順位が安定）", en = " ({n} placement games left)" },
	["menu.banned"] = {
		ja = "試合を途中で抜けた回数が多いため、しばらくランク戦に参加できません",
		en = "You left too many matches. Ranked is locked for a few minutes.",
	},
	["menu.rankedUnavailable"] = {
		ja = "今はランク戦に参加できません",
		en = "Ranked is not available right now.",
	},
	["menu.noShow"] = {
		ja = "相手が来なかったため、試合は中止になりました（レートは変わりません）",
		en = "Your opponent did not arrive. The match was called off (no rating change).",
	},
	["menu.teleportFailed"] = {
		ja = "ランク戦の部屋に移動できませんでした。もう一度お試しください",
		en = "Could not move you to the match server. Please try again.",
	},

	-- leaderboard
	["board.title"] = { ja = "ランキング", en = "Leaderboard" },
	["board.world"] = { ja = "世界", en = "World" },
	["board.region"] = { ja = "地域", en = "Region" },
	["board.titleScope"] = { ja = "ランキング（{scope}）", en = "Leaderboard ({scope})" },
	["board.empty"] = { ja = "まだ記録がありません", en = "No records yet" },
	["common.close"] = { ja = "閉じる", en = "Close" },
	["common.cancel"] = { ja = "キャンセル", en = "Cancel" },

	-- waiting
	["wait.casual"] = { ja = "相手を待っています…", en = "Waiting for an opponent…" },
	["wait.casualSub"] = {
		ja = "このサーバーで、もう1人が「カジュアル戦」を押すと始まります",
		en = "Starts when someone else in this server presses Casual.",
	},
	["wait.ranked"] = { ja = "ランク戦の相手を探しています…", en = "Finding a ranked opponent…" },
	["wait.rankedSub"] = {
		ja = "近いレートの相手を探しています",
		en = "Looking for someone close to your rating",
	},
	["wait.rankedStatus"] = { ja = "{seconds}秒  {search}", en = "{seconds}s  {search}" },
	["wait.bot"] = {
		ja = "Bot と対戦する（レートは変わりません）",
		en = "Play a Bot instead (no rating change)",
	},
	["wait.teleporting"] = { ja = "対戦部屋へ移動しています…", en = "Moving to the match server…" },
	["wait.room"] = { ja = "相手の到着を待っています…", en = "Waiting for your opponent to arrive…" },
	["wait.roomSub"] = { ja = "ランク戦の部屋です", en = "Ranked match server" },
	["search.diff"] = { ja = "レート差 ±{n}", en = "rating ±{n}" },
	["search.anyDiff"] = { ja = "レート差なし", en = "any rating" },
	["search.same"] = { ja = "同じ地域", en = "your region" },
	["search.neighbors"] = { ja = "近くの地域も", en = "nearby regions" },
	["search.any"] = { ja = "全地域", en = "all regions" },

	-- match HUD
	["hud.you"] = { ja = "あなた", en = "YOU" },
	["hud.menu"] = { ja = "メニュー", en = "Menu" },
	["hud.gauge"] = { ja = "リフトゲージ", en = "Rift gauge" },
	["hud.hit"] = { ja = "打つ", en = "HIT" },
	["hud.games"] = { ja = "ゲーム", en = "Games" },
	["hud.rally"] = { ja = "ラリー {n}", en = "Rally {n}" },
	["hud.ping"] = { ja = "通信 {ms}ms", en = "Ping {ms}ms" },
	["hud.cost"] = { ja = "ゲージ {n}", en = "Gauge {n}" },
	["hud.armedSlot"] = { ja = "次の返球で発動", en = "On next return" },
	["hud.early"] = { ja = "{ms}ms 早い", en = "{ms}ms early" },
	["hud.late"] = { ja = "{ms}ms 遅い", en = "{ms}ms late" },
	["opponent.wall"] = { ja = "WALL", en = "WALL" },
	["opponent.bot"] = { ja = "BOT（{level}）", en = "BOT ({level})" },
	["level.Easy"] = { ja = "やさしい", en = "Easy" },
	["level.Normal"] = { ja = "ふつう", en = "Normal" },
	["level.Hard"] = { ja = "つよい", en = "Hard" },
	["grade.Perfect"] = { ja = "PERFECT!!", en = "PERFECT!!" },
	["grade.Good"] = { ja = "GOOD", en = "GOOD" },
	["grade.Weak"] = { ja = "あまい…", en = "WEAK…" },
	["grade.Miss"] = { ja = "MISS", en = "MISS" },
	["grade.Barrier"] = { ja = "バリア！", en = "BARRIER!" },

	-- hints during a match
	["hint.serveTouch"] = { ja = "あなたのサーブ：「打つ」をタップ", en = "Your serve: tap HIT" },
	["hint.serve"] = {
		ja = "あなたのサーブ：クリックかスペース",
		en = "Your serve: click or press Space",
	},
	["hint.theirServe"] = { ja = "相手のサーブ", en = "Opponent's serve" },
	["hint.armed"] = { ja = "{ability}：次の返球で発動", en = "{ability}: fires on your next return" },
	["hint.fizzled"] = {
		ja = "ゲージが足りず、能力は発動しなかった",
		en = "Not enough gauge: the ability did not fire",
	},
	["hint.protected"] = { ja = "バリアが守ってくれる！", en = "Your barrier will save it!" },
	["denied.gauge"] = { ja = "ゲージが足りない", en = "Not enough gauge" },
	["denied.used"] = {
		ja = "このラリーではもう能力を使った",
		en = "You already used an ability this rally",
	},
	["denied.notRally"] = { ja = "ラリー中に使える", en = "Use it during a rally" },
	["denied.noBall"] = {
		ja = "自分に向かってくる球があるときに使える",
		en = "Use it while the ball is coming at you",
	},
	["denied.active"] = { ja = "もう発動している", en = "Already active" },
	["denied.other"] = { ja = "今は使えない", en = "Can't use that now" },
	["point.you"] = { ja = "POINT!", en = "POINT!" },
	["point.miss"] = { ja = "取れなかった", en = "Missed it" },
	["point.whiff"] = { ja = "空振り", en = "Whiffed" },
	["point.reach"] = { ja = "届かなかった", en = "Out of reach" },
	["point.lost"] = { ja = "失点", en = "Point lost" },
	["game.won"] = { ja = "ゲーム獲得！", en = "Game won!" },
	["game.lost"] = { ja = "ゲームを落とした", en = "Game lost" },
	["ability.used"] = { ja = "{who}{ability}！", en = "{who}{ability}!" },
	["ability.them"] = { ja = "相手：", en = "Opponent: " },
	["ability.barrierFired"] = { ja = "{who}リフトバリア発動！", en = "{who}Rift Barrier!" },
	["ability.theirLoadout"] = { ja = "相手の能力：{list}", en = "Opponent brings: {list}" },
	["ability.info"] = {
		ja = "{name}（{role}・ゲージ{cost}）：{effect}",
		en = "{name} ({role}, gauge {cost}): {effect}",
	},

	-- results
	["result.win"] = { ja = "WIN!", en = "WIN!" },
	["result.lose"] = { ja = "LOSE", en = "LOSE" },
	["result.games"] = { ja = "ゲーム {a} - {b}", en = "Games {a} - {b}" },
	["result.again"] = { ja = "もう一度", en = "Play again" },
	["result.menu"] = { ja = "メニューへ", en = "Menu" },
	["result.forfeit"] = { ja = "相手が退出しました", en = "Your opponent left" },
	["result.rating"] = {
		ja = "レート {before} → {after}（{delta}）",
		en = "Rating {before} → {after} ({delta})",
	},
	["result.rankUp"] = { ja = "ランクアップ！ {tier}", en = "Rank up! {tier}" },

	-- tutorial
	["tut.title"] = { ja = "チュートリアル", en = "Tutorial" },
	["tut.move"] = {
		ja = "左右に動いて、ボールが来る場所に立とう（WASD・左スティック）",
		en = "Move left and right to where the ball is going (WASD / left stick)",
	},
	["tut.hit"] = {
		ja = "ボールが自分のラケットに来た瞬間に打とう（クリック・スペース・「打つ」）：あと{n}回",
		en = "Hit the ball the moment it reaches your paddle (click / Space / HIT): {n} more",
	},
	["tut.perfect"] = {
		ja = "ぴったりのタイミングで打つと PERFECT。1回出してみよう",
		en = "Hit it right on time for a PERFECT. Get one!",
	},
	["tut.ability"] = {
		ja = "ゲージがたまった！ Q（L1・左の能力ボタン）でカーブショットを準備して、打ち返そう",
		en = "Gauge is charged! Press Q (L1 / ability button) to arm Curve Shot, then return the ball",
	},
	["tut.done"] = {
		ja = "クリア！ 次は Bot と対戦するか、ランク戦に挑戦しよう",
		en = "Done! Next, try a Bot match or jump into Ranked",
	},

	-- feedback
	["fb.title"] = { ja = "感想・バグを送る", en = "Send feedback" },
	["fb.fun"] = { ja = "楽しさ", en = "Fun" },
	["fb.bug"] = { ja = "バグ", en = "Bug" },
	["fb.balance"] = { ja = "能力・バランス", en = "Balance" },
	["fb.other"] = { ja = "その他", en = "Other" },
	["fb.placeholder"] = {
		ja = "ここに書いてください（200文字まで）",
		en = "Write here (up to 200 characters)",
	},
	["fb.send"] = { ja = "送る", en = "Send" },
	["fb.thanks"] = { ja = "ありがとう！ 送りました", en = "Thanks! Sent." },
	["fb.tooSoon"] = {
		ja = "少し時間をおいてから送ってください",
		en = "Please wait a little before sending again",
	},
	["fb.failed"] = {
		ja = "送れませんでした。あとでもう一度お試しください",
		en = "Could not send. Please try again later.",
	},

	-- access
	["access.denied"] = {
		ja = "いまはクローズドテスト中です。テスター用のグループに参加してから遊んでください。",
		en = "This game is in a closed test. Join the tester group to play.",
	},
}

local REGION = {
	NA = { ja = "北米", en = "North America" },
	SA = { ja = "南米", en = "South America" },
	EU = { ja = "ヨーロッパ", en = "Europe" },
	ASIA = { ja = "アジア", en = "Asia" },
	OCE = { ja = "オセアニア", en = "Oceania" },
}

local RANK = {
	Bronze = { ja = "ブロンズ", en = "Bronze" },
	Silver = { ja = "シルバー", en = "Silver" },
	Gold = { ja = "ゴールド", en = "Gold" },
	Diamond = { ja = "ダイヤ", en = "Diamond" },
	Master = { ja = "マスター", en = "Master" },
	Legend = { ja = "リフトレジェンド", en = "Rift Legend" },
}

local ABILITY_EN: { [string]: { name: string, role: string, effect: string } } = {
	Curve = { name = "Curve Shot", role = "Attack", effect = "Your next return bends sideways in flight" },
	Smash = {
		name = "Lightning Smash",
		role = "Attack",
		effect = "Your next return is 1.6x faster and the opponent's timing window shrinks to 65%",
	},
	Phantom = { name = "Phantom", role = "Trick", effect = "Your next return splits into 3 balls. Only one is real" },
	Blind = { name = "Blind Bound", role = "Trick", effect = "Your next return is invisible until it bounces" },
	TimeSlow = {
		name = "Time Slow",
		role = "Defense",
		effect = "The ball coming at you moves at half speed for 2s and is easier to time",
	},
	Barrier = {
		name = "Rift Barrier",
		role = "Defense",
		effect = "If you miss the incoming ball, it is returned once for you (as a very weak ball)",
	},
	GravityWell = { name = "Gravity Well", role = "Hinder", effect = "Your opponent moves at half speed for 4s" },
	Blink = { name = "Blink", role = "Move", effect = "Teleport 6 studs in the direction you are moving" },
}

-- Picks Japanese for Japanese locales and English for everything else.
function Strings.fromLocaleId(localeId: string?): Locale
	if localeId and string.sub(string.lower(localeId), 1, 2) == "ja" then
		return "ja"
	end
	return "en"
end

function Strings.setLocale(locale: Locale)
	current = locale
end

function Strings.locale(): Locale
	return current
end

function Strings.t(key: string, vars: { [string]: any }?): string
	local entry = T[key]
	if not entry then
		return key
	end
	local text = entry[current]
	if vars then
		text = string.gsub(text, "{(%w+)}", function(name)
			local v = vars[name]
			return if v == nil then "{" .. name .. "}" else tostring(v)
		end)
	end
	return text
end

function Strings.has(key: string): boolean
	return T[key] ~= nil
end

function Strings.region(id: string): string
	local r = REGION[id]
	return if r then r[current] else id
end

-- Rank label from an id ("Gold") and division ("II").
function Strings.rank(id: string, division: string?): string
	local r = RANK[id]
	local name = if r then r[current] else id
	return if division then `{name} {division}` else name
end

function Strings.abilityName(id: string): string
	if current == "en" and ABILITY_EN[id] then
		return ABILITY_EN[id].name
	end
	local def = Abilities.get(id)
	return if def then def.name else id
end

function Strings.abilityInfo(id: string): string
	local def = Abilities.get(id)
	if not def then
		return id
	end
	local en = ABILITY_EN[id]
	return Strings.t("ability.info", {
		name = Strings.abilityName(id),
		role = if current == "en" and en then en.role else def.role,
		cost = def.cost,
		effect = if current == "en" and en then en.effect else def.effect,
	})
end

-- For tests: every key has both languages, and every ability has an English entry.
function Strings.missing(): { string }
	local out = {}
	for key, entry in T do
		if entry.ja == nil or entry.en == nil or entry.ja == "" or entry.en == "" then
			table.insert(out, key)
		end
	end
	for _, def in Abilities.List do
		if not ABILITY_EN[def.id] then
			table.insert(out, "ability:" .. def.id)
		end
	end
	return out
end

return Strings
