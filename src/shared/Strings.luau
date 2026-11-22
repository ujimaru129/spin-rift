--!strict
-- Every word the player sees, in six languages: Japanese, English, Spanish, Portuguese (Brazil),
-- Korean and Indonesian. Clients pick the language from the player's Roblox locale (anything not
-- covered falls back to English) and can switch it from the menu.
--
-- Strings.t("key", { name = value }) returns the text with {name} filled in.
-- Spanish, Portuguese, Korean and Indonesian were written by the developers' assistant and should be
-- checked by native speakers before launch.

local Abilities = require(script.Parent:WaitForChild("Rally"):WaitForChild("Abilities"))

local Strings = {}

export type Locale = "ja" | "en" | "es" | "pt" | "ko" | "id"
type Entry = { ja: string, en: string, es: string, pt: string, ko: string, id: string }

Strings.LOCALES = { "ja", "en", "es", "pt", "ko", "id" } :: { Locale }

local current: Locale = "ja"

local T: { [string]: Entry } = {
	-- menu
	["menu.subtitle"] = {
		ja = "シーズン1",
		en = "Season 1",
		es = "Temporada 1",
		pt = "Temporada 1",
		ko = "시즌 1",
		id = "Musim 1",
	},
	["menu.loadingRank"] = {
		ja = "ランク：読み込み中…",
		en = "Rank: loading…",
		es = "Rango: cargando…",
		pt = "Rank: carregando…",
		ko = "랭크: 불러오는 중…",
		id = "Rank: memuat…",
	},
	["menu.ranked"] = {
		ja = "ランク戦",
		en = "Ranked",
		es = "Clasificatoria",
		pt = "Ranqueada",
		ko = "랭크전",
		id = "Ranked",
	},
	["menu.casual"] = {
		ja = "カジュアル戦（このサーバーの人と）",
		en = "Casual (players in this server)",
		es = "Casual (jugadores de este servidor)",
		pt = "Casual (jogadores deste servidor)",
		ko = "일반전 (이 서버의 플레이어와)",
		id = "Santai (pemain di server ini)",
	},
	["menu.practice"] = {
		ja = "練習",
		en = "Practice",
		es = "Práctica",
		pt = "Treino",
		ko = "연습",
		id = "Latihan",
	},
	["menu.wall"] = { ja = "壁打ち", en = "Wall", es = "Pared", pt = "Parede", ko = "벽치기", id = "Dinding" },
	["menu.botEasy"] = {
		ja = "Bot：やさしい",
		en = "Bot: Easy",
		es = "Bot: Fácil",
		pt = "Bot: Fácil",
		ko = "봇: 쉬움",
		id = "Bot: Mudah",
	},
	["menu.botNormal"] = {
		ja = "Bot：ふつう",
		en = "Bot: Normal",
		es = "Bot: Normal",
		pt = "Bot: Normal",
		ko = "봇: 보통",
		id = "Bot: Normal",
	},
	["menu.botHard"] = {
		ja = "Bot：つよい",
		en = "Bot: Hard",
		es = "Bot: Difícil",
		pt = "Bot: Difícil",
		ko = "봇: 어려움",
		id = "Bot: Sulit",
	},
	["menu.tutorial"] = {
		ja = "はじめての人：チュートリアル",
		en = "New here? Tutorial",
		es = "¿Primera vez? Tutorial",
		pt = "Novo aqui? Tutorial",
		ko = "처음이라면: 튜토리얼",
		id = "Baru di sini? Tutorial",
	},
	["menu.tryTutorial"] = {
		ja = "はじめての人は、まずチュートリアル（1〜2分）から！",
		en = "First time? Start with the tutorial (1-2 minutes)!",
		es = "¿Primera vez? ¡Empieza con el tutorial (1-2 minutos)!",
		pt = "Primeira vez? Comece pelo tutorial (1-2 minutos)!",
		ko = "처음이라면 튜토리얼(1~2분)부터 해 보세요!",
		id = "Pertama kali? Mulai dari tutorial (1-2 menit)!",
	},
	["menu.pick"] = {
		ja = "能力を2つ選ぶ",
		en = "Pick 2 abilities",
		es = "Elige 2 habilidades",
		pt = "Escolha 2 habilidades",
		ko = "능력 2개 선택",
		id = "Pilih 2 kemampuan",
	},
	["menu.help"] = {
		ja = "移動：← →・A D（左スティック）\nコース：← → を押しながら打つ（マウス・右スティックでも）\n打つ：スペース・J・クリック（R2・画面の「打つ」）\n能力：Q・E・K・L（L1・L2）。サーブ前にも準備できる",
		en = "Move: ← → or A D (left stick)\nAim: hold ← or → as you hit (or mouse, right stick)\nHit: Space, J or click (R2, HIT button)\nAbilities: Q, E or K, L (L1, L2), even before a serve",
		es = "Moverte: ← → o A D (stick izquierdo)\nApuntar: mantén ← o → al golpear (o mouse, stick derecho)\nGolpear: Espacio, J o clic (R2, botón GOLPE)\nHabilidades: Q, E o K, L (L1, L2), también antes del saque",
		pt = "Mover: ← → ou A D (analógico esquerdo)\nMirar: segure ← ou → ao rebater (ou mouse, analógico direito)\nRebater: Espaço, J ou clique (R2, botão BATER)\nHabilidades: Q, E ou K, L (L1, L2), até antes do saque",
		ko = "이동: ← → 또는 A D (왼쪽 스틱)\n조준: ← →를 누른 채 치기 (마우스, 오른쪽 스틱도 가능)\n치기: 스페이스, J 또는 클릭 (R2, 화면의 '치기')\n능력: Q, E 또는 K, L (L1, L2). 서브 전에도 준비 가능",
		id = "Gerak: ← → atau A D (stik kiri)\nArah: tahan ← atau → saat memukul (atau mouse, stik kanan)\nPukul: Spasi, J atau klik (R2, tombol PUKUL)\nKemampuan: Q, E atau K, L (L1, L2), bisa sebelum servis",
	},
	["menu.leaderboard"] = {
		ja = "ランキング",
		en = "Leaderboard",
		es = "Clasificación",
		pt = "Ranking",
		ko = "랭킹",
		id = "Papan peringkat",
	},
	["menu.feedback"] = {
		ja = "感想・バグ",
		en = "Feedback",
		es = "Comentarios",
		pt = "Feedback",
		ko = "의견·버그",
		id = "Masukan",
	},
	["menu.language"] = {
		ja = "言語：日本語",
		en = "Language: English",
		es = "Idioma: Español",
		pt = "Idioma: Português",
		ko = "언어: 한국어",
		id = "Bahasa: Indonesia",
	},
	["menu.customize"] = {
		ja = "カスタマイズ",
		en = "Customize",
		es = "Personalizar",
		pt = "Personalizar",
		ko = "꾸미기",
		id = "Kustomisasi",
	},
	["menu.pass"] = {
		ja = "バトルパス",
		en = "Battle Pass",
		es = "Pase de batalla",
		pt = "Passe de batalha",
		ko = "배틀 패스",
		id = "Battle Pass",
	},
	["menu.arena"] = {
		ja = "アリーナ：{name}",
		en = "Arena: {name}",
		es = "Arena: {name}",
		pt = "Arena: {name}",
		ko = "아레나: {name}",
		id = "Arena: {name}",
	},
	["menu.profile"] = {
		ja = "{tier}  レート {rating}  {wins}勝{losses}敗  {region}{extra}",
		en = "{tier}  Rating {rating}  {wins}W {losses}L  {region}{extra}",
		es = "{tier}  Puntos {rating}  {wins}V {losses}D  {region}{extra}",
		pt = "{tier}  Pontos {rating}  {wins}V {losses}D  {region}{extra}",
		ko = "{tier}  레이팅 {rating}  {wins}승 {losses}패  {region}{extra}",
		id = "{tier}  Rating {rating}  {wins}M {losses}K  {region}{extra}",
	},
	["menu.placement"] = {
		ja = "（あと{n}試合で順位が安定）",
		en = " ({n} placement games left)",
		es = " (faltan {n} partidas de posicionamiento)",
		pt = " ({n} partidas de classificação restantes)",
		ko = " (배치고사 {n}판 남음)",
		id = " ({n} laga penempatan lagi)",
	},
	["menu.banned"] = {
		ja = "試合を途中で抜けた回数が多いため、しばらくランク戦に参加できません",
		en = "You left too many matches. Ranked is locked for a few minutes.",
		es = "Abandonaste demasiadas partidas. La clasificatoria está bloqueada por unos minutos.",
		pt = "Você abandonou partidas demais. A ranqueada está bloqueada por alguns minutos.",
		ko = "경기 이탈이 너무 많아 잠시 랭크전에 참여할 수 없습니다.",
		id = "Kamu terlalu sering keluar dari laga. Mode Ranked dikunci selama beberapa menit.",
	},
	["menu.rankedUnavailable"] = {
		ja = "今はランク戦に参加できません",
		en = "Ranked is not available right now.",
		es = "La clasificatoria no está disponible ahora.",
		pt = "A ranqueada não está disponível agora.",
		ko = "지금은 랭크전에 참여할 수 없습니다.",
		id = "Mode Ranked sedang tidak tersedia.",
	},
	["menu.noShow"] = {
		ja = "相手が来なかったため、試合は中止になりました（レートは変わりません）",
		en = "Your opponent did not arrive. The match was called off (no rating change).",
		es = "Tu rival no llegó. La partida se canceló (sin cambio de puntos).",
		pt = "Seu oponente não chegou. A partida foi cancelada (sem mudança de pontos).",
		ko = "상대가 오지 않아 경기가 취소되었습니다 (레이팅 변동 없음).",
		id = "Lawanmu tidak datang. Laga dibatalkan (rating tidak berubah).",
	},
	["menu.teleportFailed"] = {
		ja = "ランク戦の部屋に移動できませんでした。もう一度お試しください",
		en = "Could not move you to the match server. Please try again.",
		es = "No se pudo llevarte al servidor de la partida. Inténtalo de nuevo.",
		pt = "Não foi possível levar você ao servidor da partida. Tente de novo.",
		ko = "경기 서버로 이동하지 못했습니다. 다시 시도해 주세요.",
		id = "Gagal memindahkanmu ke server laga. Coba lagi.",
	},

	-- leaderboard
	["board.title"] = {
		ja = "ランキング",
		en = "Leaderboard",
		es = "Clasificación",
		pt = "Ranking",
		ko = "랭킹",
		id = "Papan peringkat",
	},
	["board.world"] = { ja = "世界", en = "World", es = "Mundo", pt = "Mundo", ko = "전 세계", id = "Dunia" },
	["board.region"] = { ja = "地域", en = "Region", es = "Región", pt = "Região", ko = "지역", id = "Wilayah" },
	["board.titleScope"] = {
		ja = "ランキング（{scope}）",
		en = "Leaderboard ({scope})",
		es = "Clasificación ({scope})",
		pt = "Ranking ({scope})",
		ko = "랭킹 ({scope})",
		id = "Papan peringkat ({scope})",
	},
	["board.empty"] = {
		ja = "まだ記録がありません",
		en = "No records yet",
		es = "Aún no hay registros",
		pt = "Ainda sem registros",
		ko = "아직 기록이 없습니다",
		id = "Belum ada catatan",
	},
	["common.close"] = { ja = "閉じる", en = "Close", es = "Cerrar", pt = "Fechar", ko = "닫기", id = "Tutup" },
	["common.cancel"] = {
		ja = "キャンセル",
		en = "Cancel",
		es = "Cancelar",
		pt = "Cancelar",
		ko = "취소",
		id = "Batal",
	},

	-- waiting
	["wait.casual"] = {
		ja = "相手を待っています…",
		en = "Waiting for an opponent…",
		es = "Esperando a un rival…",
		pt = "Esperando um oponente…",
		ko = "상대를 기다리는 중…",
		id = "Menunggu lawan…",
	},
	["wait.casualSub"] = {
		ja = "このサーバーで、もう1人が「カジュアル戦」を押すと始まります",
		en = "Starts when someone else in this server presses Casual.",
		es = "Empieza cuando otra persona de este servidor presione Casual.",
		pt = "Começa quando outra pessoa deste servidor apertar Casual.",
		ko = "이 서버의 다른 사람이 '일반전'을 누르면 시작합니다.",
		id = "Dimulai saat pemain lain di server ini menekan Santai.",
	},
	["wait.ranked"] = {
		ja = "ランク戦の相手を探しています…",
		en = "Finding a ranked opponent…",
		es = "Buscando rival para clasificatoria…",
		pt = "Procurando oponente para a ranqueada…",
		ko = "랭크전 상대를 찾는 중…",
		id = "Mencari lawan Ranked…",
	},
	["wait.rankedSub"] = {
		ja = "近いレートの相手を探しています",
		en = "Looking for someone close to your rating",
		es = "Buscando a alguien con puntos parecidos",
		pt = "Procurando alguém com pontos parecidos",
		ko = "비슷한 레이팅의 상대를 찾고 있습니다",
		id = "Mencari lawan dengan rating serupa",
	},
	["wait.rankedStatus"] = {
		ja = "{seconds}秒  {search}",
		en = "{seconds}s  {search}",
		es = "{seconds} s  {search}",
		pt = "{seconds} s  {search}",
		ko = "{seconds}초  {search}",
		id = "{seconds} dtk  {search}",
	},
	["wait.bot"] = {
		ja = "Bot と対戦する（レートは変わりません）",
		en = "Play a Bot instead (no rating change)",
		es = "Jugar contra un bot (sin cambio de puntos)",
		pt = "Jogar contra um bot (sem mudança de pontos)",
		ko = "봇과 대전하기 (레이팅 변동 없음)",
		id = "Lawan bot saja (rating tidak berubah)",
	},
	["wait.teleporting"] = {
		ja = "対戦部屋へ移動しています…",
		en = "Moving to the match server…",
		es = "Yendo al servidor de la partida…",
		pt = "Indo para o servidor da partida…",
		ko = "경기 서버로 이동 중…",
		id = "Pindah ke server laga…",
	},
	["wait.room"] = {
		ja = "相手の到着を待っています…",
		en = "Waiting for your opponent to arrive…",
		es = "Esperando a que llegue tu rival…",
		pt = "Esperando seu oponente chegar…",
		ko = "상대가 도착하기를 기다리는 중…",
		id = "Menunggu lawan tiba…",
	},
	["wait.roomSub"] = {
		ja = "ランク戦の部屋です",
		en = "Ranked match server",
		es = "Servidor de partida clasificatoria",
		pt = "Servidor de partida ranqueada",
		ko = "랭크전 경기 서버",
		id = "Server laga Ranked",
	},
	["search.diff"] = {
		ja = "レート差 ±{n}",
		en = "rating ±{n}",
		es = "puntos ±{n}",
		pt = "pontos ±{n}",
		ko = "레이팅 ±{n}",
		id = "rating ±{n}",
	},
	["search.anyDiff"] = {
		ja = "レート差なし",
		en = "any rating",
		es = "sin límite de puntos",
		pt = "sem limite de pontos",
		ko = "레이팅 제한 없음",
		id = "rating berapa pun",
	},
	["search.same"] = {
		ja = "同じ地域",
		en = "your region",
		es = "tu región",
		pt = "sua região",
		ko = "같은 지역",
		id = "wilayahmu",
	},
	["search.neighbors"] = {
		ja = "近くの地域も",
		en = "nearby regions",
		es = "regiones cercanas",
		pt = "regiões próximas",
		ko = "가까운 지역 포함",
		id = "wilayah terdekat",
	},
	["search.any"] = {
		ja = "全地域",
		en = "all regions",
		es = "todas las regiones",
		pt = "todas as regiões",
		ko = "모든 지역",
		id = "semua wilayah",
	},

	-- match HUD
	["hud.you"] = { ja = "あなた", en = "YOU", es = "TÚ", pt = "VOCÊ", ko = "나", id = "KAMU" },
	["hud.menu"] = { ja = "メニュー", en = "Menu", es = "Menú", pt = "Menu", ko = "메뉴", id = "Menu" },
	["hud.gauge"] = {
		ja = "リフトゲージ",
		en = "Rift gauge",
		es = "Medidor Rift",
		pt = "Medidor Rift",
		ko = "리프트 게이지",
		id = "Energi Rift",
	},
	["hud.hit"] = { ja = "打つ", en = "HIT", es = "GOLPE", pt = "BATER", ko = "치기", id = "PUKUL" },
	["hud.games"] = { ja = "ゲーム", en = "Games", es = "Juegos", pt = "Games", ko = "게임", id = "Gim" },
	["hud.rally"] = {
		ja = "ラリー {n}",
		en = "Rally {n}",
		es = "Peloteo {n}",
		pt = "Rally {n}",
		ko = "랠리 {n}",
		id = "Reli {n}",
	},
	["hud.ping"] = {
		ja = "通信 {ms}ms",
		en = "Ping {ms}ms",
		es = "Ping {ms} ms",
		pt = "Ping {ms} ms",
		ko = "핑 {ms}ms",
		id = "Ping {ms} ms",
	},
	["hud.cost"] = {
		ja = "ゲージ {n}",
		en = "Gauge {n}",
		es = "Medidor {n}",
		pt = "Medidor {n}",
		ko = "게이지 {n}",
		id = "Energi {n}",
	},
	["hud.armedSlot"] = {
		ja = "次の返球で発動",
		en = "On next return",
		es = "En la próxima devolución",
		pt = "Na próxima rebatida",
		ko = "다음 리턴에 발동",
		id = "Saat pukulan berikutnya",
	},
	["hud.early"] = {
		ja = "{ms}ms 早い",
		en = "{ms}ms early",
		es = "{ms} ms antes de tiempo",
		pt = "{ms} ms adiantado",
		ko = "{ms}ms 빠름",
		id = "{ms} ms terlalu cepat",
	},
	["hud.late"] = {
		ja = "{ms}ms 遅い",
		en = "{ms}ms late",
		es = "{ms} ms tarde",
		pt = "{ms} ms atrasado",
		ko = "{ms}ms 늦음",
		id = "{ms} ms terlambat",
	},
	["hud.wind"] = {
		ja = "風 {arrow}",
		en = "Wind {arrow}",
		es = "Viento {arrow}",
		pt = "Vento {arrow}",
		ko = "바람 {arrow}",
		id = "Angin {arrow}",
	},
	["opponent.wall"] = { ja = "WALL", en = "WALL", es = "PARED", pt = "PAREDE", ko = "벽", id = "DINDING" },
	["opponent.bot"] = {
		ja = "BOT（{level}）",
		en = "BOT ({level})",
		es = "BOT ({level})",
		pt = "BOT ({level})",
		ko = "봇 ({level})",
		id = "BOT ({level})",
	},
	["level.Easy"] = { ja = "やさしい", en = "Easy", es = "Fácil", pt = "Fácil", ko = "쉬움", id = "Mudah" },
	["level.Normal"] = { ja = "ふつう", en = "Normal", es = "Normal", pt = "Normal", ko = "보통", id = "Normal" },
	["level.Hard"] = { ja = "つよい", en = "Hard", es = "Difícil", pt = "Difícil", ko = "어려움", id = "Sulit" },
	["grade.Perfect"] = {
		ja = "PERFECT!!",
		en = "PERFECT!!",
		es = "¡¡PERFECTO!!",
		pt = "PERFEITO!!",
		ko = "PERFECT!!",
		id = "SEMPURNA!!",
	},
	["grade.Good"] = { ja = "GOOD", en = "GOOD", es = "BIEN", pt = "BOM", ko = "GOOD", id = "BAGUS" },
	["grade.Weak"] = {
		ja = "あまい…",
		en = "WEAK…",
		es = "FLOJO…",
		pt = "FRACO…",
		ko = "약함…",
		id = "LEMAH…",
	},
	["grade.Miss"] = { ja = "MISS", en = "MISS", es = "FALLO", pt = "ERROU", ko = "MISS", id = "MELESET" },
	["grade.Barrier"] = {
		ja = "バリア！",
		en = "BARRIER!",
		es = "¡BARRERA!",
		pt = "BARREIRA!",
		ko = "배리어!",
		id = "PERISAI!",
	},

	-- how-to-play box during a match (one per kind of device)
	["hud.aim"] = {
		ja = "コース {mark}",
		en = "Aim {mark}",
		es = "Dirección {mark}",
		pt = "Direção {mark}",
		ko = "조준 {mark}",
		id = "Arah {mark}",
	},
	["controls.keyboard"] = {
		ja = "移動：← →（A D）\nコース：← → を押しながら打つ\n打つ：スペース（J・クリック）\n能力：Q・E（K・L）\n（能力はサーブ前にも準備できる）",
		en = "Move: ← → (A D)\nAim: hold ← or → as you hit\nHit: Space (J, click)\nAbilities: Q, E (K, L)\n(arm them before a serve too)",
		es = "Moverte: ← → (A D)\nApuntar: mantén ← o → al golpear\nGolpear: Espacio (J, clic)\nHabilidades: Q, E (K, L)\n(también antes del saque)",
		pt = "Mover: ← → (A D)\nMirar: segure ← ou → ao rebater\nRebater: Espaço (J, clique)\nHabilidades: Q, E (K, L)\n(dá para preparar antes do saque)",
		ko = "이동: ← → (A D)\n조준: ← →를 누른 채 치기\n치기: 스페이스 (J, 클릭)\n능력: Q, E (K, L)\n(서브 전에도 준비 가능)",
		id = "Gerak: ← → (A D)\nArah: tahan ← atau → saat memukul\nPukul: Spasi (J, klik)\nKemampuan: Q, E (K, L)\n(bisa disiapkan sebelum servis)",
	},
	["controls.touch"] = {
		ja = "移動：左のスティック\nコース：スティックを倒した向き\n打つ：「打つ」ボタン\n能力：「打つ」の左と上のボタン\n（能力はサーブ前にも準備できる）",
		en = "Move: left stick\nAim: the way you push the stick\nHit: HIT button\nAbilities: buttons left of and above HIT\n(arm them before a serve too)",
		es = "Moverte: stick izquierdo\nApuntar: hacia donde inclinas el stick\nGolpear: botón GOLPE\nHabilidades: botones junto a GOLPE\n(también antes del saque)",
		pt = "Mover: analógico esquerdo\nMirar: para onde você inclina o analógico\nRebater: botão BATER\nHabilidades: botões ao lado de BATER\n(dá para preparar antes do saque)",
		ko = "이동: 왼쪽 스틱\n조준: 스틱을 기울인 방향\n치기: '치기' 버튼\n능력: '치기' 옆과 위의 버튼\n(서브 전에도 준비 가능)",
		id = "Gerak: stik kiri\nArah: ke mana stik kamu miringkan\nPukul: tombol PUKUL\nKemampuan: tombol di samping PUKUL\n(bisa disiapkan sebelum servis)",
	},
	["controls.gamepad"] = {
		ja = "移動：左スティック\nコース：右スティック\n打つ：R2\n能力：L1・L2\n（能力はサーブ前にも準備できる）",
		en = "Move: left stick\nAim: right stick\nHit: R2\nAbilities: L1, L2\n(arm them before a serve too)",
		es = "Moverte: stick izquierdo\nApuntar: stick derecho\nGolpear: R2\nHabilidades: L1, L2\n(también antes del saque)",
		pt = "Mover: analógico esquerdo\nMirar: analógico direito\nRebater: R2\nHabilidades: L1, L2\n(dá para preparar antes do saque)",
		ko = "이동: 왼쪽 스틱\n조준: 오른쪽 스틱\n치기: R2\n능력: L1, L2\n(서브 전에도 준비 가능)",
		id = "Gerak: stik kiri\nArah: stik kanan\nPukul: R2\nKemampuan: L1, L2\n(bisa disiapkan sebelum servis)",
	},

	-- hints during a match
	["hint.serveTouch"] = {
		ja = "あなたのサーブ：「打つ」をタップ",
		en = "Your serve: tap HIT",
		es = "Tu saque: toca GOLPE",
		pt = "Seu saque: toque em BATER",
		ko = "내 서브: '치기'를 탭",
		id = "Servismu: ketuk PUKUL",
	},
	["hint.serve"] = {
		ja = "あなたのサーブ：クリックかスペース",
		en = "Your serve: click or press Space",
		es = "Tu saque: haz clic o presiona Espacio",
		pt = "Seu saque: clique ou aperte Espaço",
		ko = "내 서브: 클릭 또는 스페이스",
		id = "Servismu: klik atau tekan Spasi",
	},
	["hint.theirServe"] = {
		ja = "相手のサーブ",
		en = "Opponent's serve",
		es = "Saque del rival",
		pt = "Saque do oponente",
		ko = "상대 서브",
		id = "Servis lawan",
	},
	["hint.armed"] = {
		ja = "{ability}：次の返球で発動",
		en = "{ability}: fires on your next return",
		es = "{ability}: se activa en tu próxima devolución",
		pt = "{ability}: ativa na sua próxima rebatida",
		ko = "{ability}: 다음 리턴에 발동",
		id = "{ability}: aktif di pukulan berikutnya",
	},
	["hint.fizzled"] = {
		ja = "ゲージが足りず、能力は発動しなかった",
		en = "Not enough gauge: the ability did not fire",
		es = "Medidor insuficiente: la habilidad no se activó",
		pt = "Medidor insuficiente: a habilidade não ativou",
		ko = "게이지가 부족해 능력이 발동하지 않음",
		id = "Energi kurang: kemampuan tidak aktif",
	},
	["hint.protected"] = {
		ja = "バリアが守ってくれる！",
		en = "Your barrier will save it!",
		es = "¡Tu barrera la salvará!",
		pt = "Sua barreira vai te salvar!",
		ko = "배리어가 지켜 준다!",
		id = "Perisaimu akan menyelamatkannya!",
	},
	["denied.gauge"] = {
		ja = "ゲージが足りない",
		en = "Not enough gauge",
		es = "Medidor insuficiente",
		pt = "Medidor insuficiente",
		ko = "게이지 부족",
		id = "Energi kurang",
	},
	["denied.used"] = {
		ja = "このラリーではもう能力を使った",
		en = "You already used an ability this rally",
		es = "Ya usaste una habilidad en este peloteo",
		pt = "Você já usou uma habilidade neste rally",
		ko = "이번 랠리에서 이미 능력을 사용함",
		id = "Kamu sudah memakai kemampuan di reli ini",
	},
	["denied.notRally"] = {
		ja = "ラリー中に使える",
		en = "Use it during a rally",
		es = "Úsala durante un peloteo",
		pt = "Use durante um rally",
		ko = "랠리 중에 사용 가능",
		id = "Pakai saat reli",
	},
	["denied.noBall"] = {
		ja = "自分に向かってくる球があるときに使える",
		en = "Use it while the ball is coming at you",
		es = "Úsala cuando la pelota venga hacia ti",
		pt = "Use quando a bola estiver vindo na sua direção",
		ko = "공이 나에게 올 때 사용 가능",
		id = "Pakai saat bola menuju ke arahmu",
	},
	["denied.active"] = {
		ja = "もう発動している",
		en = "Already active",
		es = "Ya está activa",
		pt = "Já está ativa",
		ko = "이미 발동 중",
		id = "Sudah aktif",
	},
	["denied.other"] = {
		ja = "今は使えない",
		en = "Can't use that now",
		es = "Ahora no se puede usar",
		pt = "Não dá para usar agora",
		ko = "지금은 사용할 수 없음",
		id = "Belum bisa dipakai",
	},
	["point.you"] = { ja = "POINT!", en = "POINT!", es = "¡PUNTO!", pt = "PONTO!", ko = "득점!", id = "POIN!" },
	["point.miss"] = {
		ja = "取れなかった",
		en = "Missed it",
		es = "No llegaste",
		pt = "Não alcançou",
		ko = "놓쳤다",
		id = "Tidak terkejar",
	},
	["point.whiff"] = {
		ja = "空振り",
		en = "Whiffed",
		es = "Golpe al aire",
		pt = "Furou",
		ko = "헛스윙",
		id = "Pukulan meleset",
	},
	["point.reach"] = {
		ja = "届かなかった",
		en = "Out of reach",
		es = "Fuera de alcance",
		pt = "Fora de alcance",
		ko = "닿지 않았다",
		id = "Tidak terjangkau",
	},
	["point.lost"] = {
		ja = "失点",
		en = "Point lost",
		es = "Punto perdido",
		pt = "Ponto perdido",
		ko = "실점",
		id = "Kehilangan poin",
	},
	["game.won"] = {
		ja = "ゲーム獲得！",
		en = "Game won!",
		es = "¡Juego ganado!",
		pt = "Game vencido!",
		ko = "게임 획득!",
		id = "Menang gim!",
	},
	["game.lost"] = {
		ja = "ゲームを落とした",
		en = "Game lost",
		es = "Juego perdido",
		pt = "Game perdido",
		ko = "게임을 내줬다",
		id = "Kalah gim",
	},
	["ability.used"] = {
		ja = "{who}{ability}！",
		en = "{who}{ability}!",
		es = "{who}¡{ability}!",
		pt = "{who}{ability}!",
		ko = "{who}{ability}!",
		id = "{who}{ability}!",
	},
	["ability.them"] = {
		ja = "相手：",
		en = "Opponent: ",
		es = "Rival: ",
		pt = "Oponente: ",
		ko = "상대: ",
		id = "Lawan: ",
	},
	["ability.barrierFired"] = {
		ja = "{who}リフトバリア発動！",
		en = "{who}Rift Barrier!",
		es = "{who}¡Barrera Rift!",
		pt = "{who}Barreira Rift!",
		ko = "{who}리프트 배리어 발동!",
		id = "{who}Perisai Rift!",
	},
	["ability.theirLoadout"] = {
		ja = "相手の能力：{list}",
		en = "Opponent brings: {list}",
		es = "Tu rival trae: {list}",
		pt = "O oponente trouxe: {list}",
		ko = "상대 능력: {list}",
		id = "Kemampuan lawan: {list}",
	},
	["ability.info"] = {
		ja = "{name}（{role}・ゲージ{cost}）：{effect}",
		en = "{name} ({role}, gauge {cost}): {effect}",
		es = "{name} ({role}, medidor {cost}): {effect}",
		pt = "{name} ({role}, medidor {cost}): {effect}",
		ko = "{name} ({role}, 게이지 {cost}): {effect}",
		id = "{name} ({role}, energi {cost}): {effect}",
	},

	-- results
	["result.win"] = { ja = "WIN!", en = "WIN!", es = "¡VICTORIA!", pt = "VITÓRIA!", ko = "승리!", id = "MENANG!" },
	["result.lose"] = { ja = "LOSE", en = "LOSE", es = "DERROTA", pt = "DERROTA", ko = "패배", id = "KALAH" },
	["result.games"] = {
		ja = "ゲーム {a} - {b}",
		en = "Games {a} - {b}",
		es = "Juegos {a} - {b}",
		pt = "Games {a} - {b}",
		ko = "게임 {a} - {b}",
		id = "Gim {a} - {b}",
	},
	["result.again"] = {
		ja = "もう一度",
		en = "Play again",
		es = "Jugar otra vez",
		pt = "Jogar de novo",
		ko = "다시 하기",
		id = "Main lagi",
	},
	["result.menu"] = { ja = "メニューへ", en = "Menu", es = "Menú", pt = "Menu", ko = "메뉴로", id = "Menu" },
	["result.forfeit"] = {
		ja = "相手が退出しました",
		en = "Your opponent left",
		es = "Tu rival se fue",
		pt = "Seu oponente saiu",
		ko = "상대가 나갔습니다",
		id = "Lawanmu keluar",
	},
	["result.idleWin"] = {
		ja = "相手が操作していなかったため勝ち",
		en = "Your opponent stopped playing",
		es = "Tu rival dejó de jugar",
		pt = "Seu oponente parou de jogar",
		ko = "상대가 조작하지 않아 승리",
		id = "Lawanmu berhenti bermain",
	},
	["result.idleLose"] = {
		ja = "操作がなかったため負け",
		en = "You stopped playing, so you lost",
		es = "Dejaste de jugar y perdiste",
		pt = "Você parou de jogar e perdeu",
		ko = "조작하지 않아 패배",
		id = "Kamu berhenti bermain, jadi kalah",
	},
	["result.rating"] = {
		ja = "レート {before} → {after}（{delta}）",
		en = "Rating {before} → {after} ({delta})",
		es = "Puntos {before} → {after} ({delta})",
		pt = "Pontos {before} → {after} ({delta})",
		ko = "레이팅 {before} → {after} ({delta})",
		id = "Rating {before} → {after} ({delta})",
	},
	["result.rankUp"] = {
		ja = "ランクアップ！ {tier}",
		en = "Rank up! {tier}",
		es = "¡Subiste de rango! {tier}",
		pt = "Subiu de rank! {tier}",
		ko = "랭크 업! {tier}",
		id = "Naik rank! {tier}",
	},

	-- tutorial
	["tut.hit"] = {
		ja = "左右に動いてボールの前へ。ラケットに来た瞬間に打とう（クリック・スペース・「打つ」）：あと{n}回",
		en = "Move left/right to get in front of the ball, then hit it as it reaches your paddle (click / Space / HIT): {n} more",
		es = "Muévete a los lados para ponerte frente a la pelota y golpéala cuando llegue a tu raqueta (clic / Espacio / GOLPE): faltan {n}",
		pt = "Ande para os lados até ficar na frente da bola e rebata quando ela chegar à raquete (clique / Espaço / BATER): faltam {n}",
		ko = "좌우로 움직여 공 앞에 서고, 라켓에 오는 순간 치자 (클릭 / 스페이스 / 치기): {n}번 남음",
		id = "Geser ke kiri/kanan ke depan bola, lalu pukul saat sampai di raketmu (klik / Spasi / PUKUL): {n} lagi",
	},
	["tut.perfect"] = {
		ja = "ぴったりのタイミングで打つと PERFECT。1回出してみよう",
		en = "Hit it right on time for a PERFECT. Get one!",
		es = "Golpea en el momento justo para un PERFECTO. ¡Consigue uno!",
		pt = "Rebata no tempo certo para um PERFEITO. Consiga um!",
		ko = "딱 맞는 타이밍에 치면 PERFECT. 한 번 해 보자!",
		id = "Pukul tepat waktu untuk dapat SEMPURNA. Coba sekali!",
	},
	["tut.ability"] = {
		ja = "ゲージがたまった！ Q（L1・左の能力ボタン）でカーブショットを準備して、打ち返そう",
		en = "Gauge is charged! Press Q (L1 / ability button) to arm Curve Shot, then return the ball",
		es = "¡Medidor cargado! Presiona Q (L1 / botón de habilidad) para preparar el Tiro con efecto y luego devuelve la pelota",
		pt = "Medidor cheio! Aperte Q (L1 / botão de habilidade) para preparar o Tiro com efeito e rebata a bola",
		ko = "게이지가 찼다! Q (L1 / 능력 버튼)로 커브 샷을 준비하고 받아치자",
		id = "Energi penuh! Tekan Q (L1 / tombol kemampuan) untuk menyiapkan Pukulan Melengkung, lalu kembalikan bola",
	},
	["tut.done"] = {
		ja = "クリア！ 次は Bot と対戦するか、ランク戦に挑戦しよう",
		en = "Done! Next, try a Bot match or jump into Ranked",
		es = "¡Listo! Ahora juega contra un bot o entra a Clasificatoria",
		pt = "Pronto! Agora jogue contra um bot ou entre na Ranqueada",
		ko = "클리어! 이제 봇과 대전하거나 랭크전에 도전하자",
		id = "Selesai! Sekarang lawan bot atau masuk mode Ranked",
	},

	-- feedback
	["fb.title"] = {
		ja = "感想・バグを送る",
		en = "Send feedback",
		es = "Enviar comentarios",
		pt = "Enviar feedback",
		ko = "의견·버그 보내기",
		id = "Kirim masukan",
	},
	["fb.fun"] = { ja = "楽しさ", en = "Fun", es = "Diversión", pt = "Diversão", ko = "재미", id = "Keseruan" },
	["fb.bug"] = { ja = "バグ", en = "Bug", es = "Error", pt = "Bug", ko = "버그", id = "Bug" },
	["fb.balance"] = {
		ja = "バランス",
		en = "Balance",
		es = "Equilibrio",
		pt = "Balanceamento",
		ko = "밸런스",
		id = "Keseimbangan",
	},
	["fb.other"] = { ja = "その他", en = "Other", es = "Otro", pt = "Outro", ko = "기타", id = "Lainnya" },
	["fb.placeholder"] = {
		ja = "ここに書いてください（200文字まで）",
		en = "Write here (up to 200 characters)",
		es = "Escribe aquí (hasta 200 caracteres)",
		pt = "Escreva aqui (até 200 caracteres)",
		ko = "여기에 적어 주세요 (200자까지)",
		id = "Tulis di sini (maks. 200 karakter)",
	},
	["fb.send"] = { ja = "送る", en = "Send", es = "Enviar", pt = "Enviar", ko = "보내기", id = "Kirim" },
	["fb.thanks"] = {
		ja = "ありがとう！ 送りました",
		en = "Thanks! Sent.",
		es = "¡Gracias! Enviado.",
		pt = "Obrigado! Enviado.",
		ko = "고마워요! 보냈어요",
		id = "Terima kasih! Terkirim.",
	},
	["fb.tooSoon"] = {
		ja = "少し時間をおいてから送ってください",
		en = "Please wait a little before sending again",
		es = "Espera un poco antes de enviar otra vez",
		pt = "Espere um pouco antes de enviar de novo",
		ko = "잠시 후에 다시 보내 주세요",
		id = "Tunggu sebentar sebelum mengirim lagi",
	},
	["fb.failed"] = {
		ja = "送れませんでした。あとでもう一度お試しください",
		en = "Could not send. Please try again later.",
		es = "No se pudo enviar. Inténtalo más tarde.",
		pt = "Não foi possível enviar. Tente mais tarde.",
		ko = "보내지 못했습니다. 나중에 다시 시도해 주세요.",
		id = "Gagal mengirim. Coba lagi nanti.",
	},

	-- access
	["access.denied"] = {
		ja = "いまはクローズドテスト中です。テスター用のグループに参加してから遊んでください。",
		en = "This game is in a closed test. Join the tester group to play.",
		es = "Este juego está en prueba cerrada. Únete al grupo de testers para jugar.",
		pt = "Este jogo está em teste fechado. Entre no grupo de testers para jogar.",
		ko = "지금은 비공개 테스트 중입니다. 테스터 그룹에 가입한 뒤 플레이해 주세요.",
		id = "Game ini sedang dalam uji tertutup. Gabung grup penguji untuk bermain.",
	},

	-- arenas
	["arena.Rooftop"] = {
		ja = "ネオン・ルーフトップ",
		en = "Neon Rooftop",
		es = "Azotea Neón",
		pt = "Terraço Neon",
		ko = "네온 루프톱",
		id = "Atap Neon",
	},
	["arena.Sakura"] = {
		ja = "サクラ・フロート",
		en = "Sakura Float",
		es = "Sakura Flotante",
		pt = "Sakura Flutuante",
		ko = "사쿠라 플로트",
		id = "Sakura Melayang",
	},
	["arena.locked"] = {
		ja = "{rank}で解放",
		en = "Unlocks at {rank}",
		es = "Se desbloquea en {rank}",
		pt = "Desbloqueia em {rank}",
		ko = "{rank} 달성 시 해금",
		id = "Terbuka di {rank}",
	},
	["arena.windNote"] = {
		ja = "風でボールが少し流される（ランク戦では風なし）",
		en = "Wind nudges the ball (no wind in Ranked)",
		es = "El viento desvía un poco la pelota (sin viento en Clasificatoria)",
		pt = "O vento desvia um pouco a bola (sem vento na Ranqueada)",
		ko = "바람이 공을 조금 밀어낸다 (랭크전에서는 바람 없음)",
		id = "Angin sedikit menggeser bola (tanpa angin di mode Ranked)",
	},

	-- battle pass
	["pass.title"] = {
		ja = "バトルパス シーズン1",
		en = "Battle Pass Season 1",
		es = "Pase de batalla T1",
		pt = "Passe de batalha T1",
		ko = "배틀 패스 시즌 1",
		id = "Battle Pass Musim 1",
	},
	["pass.level"] = {
		ja = "レベル {n} / {max}",
		en = "Level {n} / {max}",
		es = "Nivel {n} / {max}",
		pt = "Nível {n} / {max}",
		ko = "레벨 {n} / {max}",
		id = "Level {n} / {max}",
	},
	["pass.xp"] = {
		ja = "{xp} / {need} XP",
		en = "{xp} / {need} XP",
		es = "{xp} / {need} XP",
		pt = "{xp} / {need} XP",
		ko = "{xp} / {need} XP",
		id = "{xp} / {need} XP",
	},
	["pass.free"] = { ja = "無料", en = "Free", es = "Gratis", pt = "Grátis", ko = "무료", id = "Gratis" },
	["pass.premium"] = {
		ja = "プレミアム",
		en = "Premium",
		es = "Premium",
		pt = "Premium",
		ko = "프리미엄",
		id = "Premium",
	},
	["pass.buy"] = {
		ja = "プレミアムを買う（{price} Robux）",
		en = "Get Premium ({price} Robux)",
		es = "Comprar Premium ({price} Robux)",
		pt = "Comprar Premium ({price} Robux)",
		ko = "프리미엄 구매 ({price} Robux)",
		id = "Beli Premium ({price} Robux)",
	},
	["pass.owned"] = {
		ja = "プレミアム所有中",
		en = "Premium owned",
		es = "Premium activo",
		pt = "Premium ativo",
		ko = "프리미엄 보유 중",
		id = "Premium dimiliki",
	},
	["pass.howXp"] = {
		ja = "試合でXP：勝ち120・負け60、その日最初の勝利+200",
		en = "Earn XP: win 120, loss 60, first win of the day +200",
		es = "Gana XP: victoria 120, derrota 60, primera victoria del día +200",
		pt = "Ganhe XP: vitória 120, derrota 60, primeira vitória do dia +200",
		ko = "XP 획득: 승리 120, 패배 60, 오늘의 첫 승리 +200",
		id = "Dapat XP: menang 120, kalah 60, kemenangan pertama hari ini +200",
	},
	["pass.got"] = {
		ja = "入手済み",
		en = "Owned",
		es = "Obtenido",
		pt = "Obtido",
		ko = "획득 완료",
		id = "Dimiliki",
	},
	["pass.row"] = { ja = "Lv{n}", en = "Lv{n}", es = "Nv{n}", pt = "Nv{n}", ko = "Lv{n}", id = "Lv{n}" },
	["pass.xpGain"] = {
		ja = "+{xp} XP",
		en = "+{xp} XP",
		es = "+{xp} XP",
		pt = "+{xp} XP",
		ko = "+{xp} XP",
		id = "+{xp} XP",
	},
	["pass.dailyBonus"] = {
		ja = "今日最初の勝利ボーナス！",
		en = "First win of the day bonus!",
		es = "¡Bono por la primera victoria del día!",
		pt = "Bônus da primeira vitória do dia!",
		ko = "오늘의 첫 승리 보너스!",
		id = "Bonus kemenangan pertama hari ini!",
	},
	["pass.levelUp"] = {
		ja = "バトルパス レベル {n}！",
		en = "Battle Pass level {n}!",
		es = "¡Pase de batalla nivel {n}!",
		pt = "Passe de batalha nível {n}!",
		ko = "배틀 패스 레벨 {n}!",
		id = "Battle Pass level {n}!",
	},
	["pass.newItem"] = {
		ja = "{item} を手に入れた！",
		en = "You got {item}!",
		es = "¡Conseguiste {item}!",
		pt = "Você ganhou {item}!",
		ko = "{item} 획득!",
		id = "Kamu dapat {item}!",
	},

	-- cosmetics
	["cos.title"] = {
		ja = "カスタマイズ",
		en = "Customize",
		es = "Personalizar",
		pt = "Personalizar",
		ko = "꾸미기",
		id = "Kustomisasi",
	},
	["cos.paddle"] = { ja = "ラケット", en = "Paddle", es = "Raqueta", pt = "Raquete", ko = "라켓", id = "Raket" },
	["cos.trail"] = {
		ja = "ボールの軌跡",
		en = "Ball trail",
		es = "Estela de la pelota",
		pt = "Rastro da bola",
		ko = "공 궤적",
		id = "Jejak bola",
	},
	["cos.titleSlot"] = { ja = "称号", en = "Title", es = "Título", pt = "Título", ko = "칭호", id = "Gelar" },
	["cos.none"] = { ja = "なし", en = "None", es = "Ninguno", pt = "Nenhum", ko = "없음", id = "Tidak ada" },
	["cos.locked"] = {
		ja = "未入手",
		en = "Locked",
		es = "Bloqueado",
		pt = "Bloqueado",
		ko = "미획득",
		id = "Terkunci",
	},
}

local REGION: { [string]: Entry } = {
	NA = {
		ja = "北米",
		en = "North America",
		es = "Norteamérica",
		pt = "América do Norte",
		ko = "북미",
		id = "Amerika Utara",
	},
	SA = {
		ja = "南米",
		en = "South America",
		es = "Sudamérica",
		pt = "América do Sul",
		ko = "남미",
		id = "Amerika Selatan",
	},
	EU = { ja = "ヨーロッパ", en = "Europe", es = "Europa", pt = "Europa", ko = "유럽", id = "Eropa" },
	ASIA = { ja = "アジア", en = "Asia", es = "Asia", pt = "Ásia", ko = "아시아", id = "Asia" },
	OCE = {
		ja = "オセアニア",
		en = "Oceania",
		es = "Oceanía",
		pt = "Oceania",
		ko = "오세아니아",
		id = "Oseania",
	},
}

local RANK: { [string]: Entry } = {
	Bronze = { ja = "ブロンズ", en = "Bronze", es = "Bronce", pt = "Bronze", ko = "브론즈", id = "Perunggu" },
	Silver = { ja = "シルバー", en = "Silver", es = "Plata", pt = "Prata", ko = "실버", id = "Perak" },
	Gold = { ja = "ゴールド", en = "Gold", es = "Oro", pt = "Ouro", ko = "골드", id = "Emas" },
	Diamond = { ja = "ダイヤ", en = "Diamond", es = "Diamante", pt = "Diamante", ko = "다이아", id = "Berlian" },
	Master = { ja = "マスター", en = "Master", es = "Maestro", pt = "Mestre", ko = "마스터", id = "Master" },
	Legend = {
		ja = "リフトレジェンド",
		en = "Rift Legend",
		es = "Leyenda Rift",
		pt = "Lenda Rift",
		ko = "리프트 레전드",
		id = "Legenda Rift",
	},
}

-- Ability name / role / effect outside Japanese (Japanese lives in Abilities.luau).
type AbilityText = { name: string, role: string, effect: string }
local ABILITY: { [string]: { [string]: AbilityText } } = {
	Curve = {
		en = { name = "Curve Shot", role = "Attack", effect = "Your next return bends sideways in flight" },
		es = { name = "Tiro con efecto", role = "Ataque", effect = "Tu próxima devolución se curva en el aire" },
		pt = { name = "Tiro com efeito", role = "Ataque", effect = "Sua próxima rebatida faz curva no ar" },
		ko = { name = "커브 샷", role = "공격", effect = "다음 리턴이 날아가는 도중 옆으로 휜다" },
		id = { name = "Pukulan Melengkung", role = "Serang", effect = "Pukulan berikutnya melengkung ke samping" },
	},
	Smash = {
		en = {
			name = "Lightning Smash",
			role = "Attack",
			effect = "Your next return is 1.6x faster and the opponent's timing window shrinks to 65%",
		},
		es = {
			name = "Remate relámpago",
			role = "Ataque",
			effect = "Tu próxima devolución va 1,6 veces más rápido y la ventana de tiempo del rival baja al 65%",
		},
		pt = {
			name = "Cortada relâmpago",
			role = "Ataque",
			effect = "Sua próxima rebatida é 1,6x mais rápida e a janela do oponente cai para 65%",
		},
		ko = {
			name = "라이트닝 스매시",
			role = "공격",
			effect = "다음 리턴이 1.6배 빨라지고 상대의 타이밍 폭이 65%로 줄어든다",
		},
		id = {
			name = "Smes Kilat",
			role = "Serang",
			effect = "Pukulan berikutnya 1,6x lebih cepat dan jendela waktu lawan jadi 65%",
		},
	},
	Phantom = {
		en = { name = "Phantom", role = "Trick", effect = "Your next return splits into 3 balls. Only one is real" },
		es = {
			name = "Fantasma",
			role = "Engaño",
			effect = "Tu próxima devolución se divide en 3 pelotas. Solo una es real",
		},
		pt = { name = "Fantasma", role = "Truque", effect = "Sua próxima rebatida vira 3 bolas. Só uma é real" },
		ko = { name = "팬텀", role = "교란", effect = "다음 리턴이 3개로 분신한다. 진짜는 하나뿐" },
		id = {
			name = "Bayangan",
			role = "Tipuan",
			effect = "Pukulan berikutnya terbelah jadi 3 bola. Hanya satu yang asli",
		},
	},
	Blind = {
		en = { name = "Blind Bound", role = "Trick", effect = "Your next return is invisible until it bounces" },
		es = {
			name = "Rebote ciego",
			role = "Engaño",
			effect = "Tu próxima devolución es invisible hasta que rebota",
		},
		pt = { name = "Quique cego", role = "Truque", effect = "Sua próxima rebatida fica invisível até quicar" },
		ko = {
			name = "블라인드 바운드",
			role = "교란",
			effect = "다음 리턴이 바운드될 때까지 보이지 않는다",
		},
		id = { name = "Pantulan Buta", role = "Tipuan", effect = "Pukulan berikutnya tak terlihat sampai memantul" },
	},
	TimeSlow = {
		en = {
			name = "Time Slow",
			role = "Defense",
			effect = "The ball coming at you moves at half speed for 2s and is easier to time",
		},
		es = {
			name = "Tiempo lento",
			role = "Defensa",
			effect = "La pelota que viene hacia ti va a mitad de velocidad durante 2 s y es más fácil de golpear",
		},
		pt = {
			name = "Tempo lento",
			role = "Defesa",
			effect = "A bola que vem até você fica na metade da velocidade por 2 s e é mais fácil de acertar",
		},
		ko = {
			name = "타임 슬로",
			role = "방어",
			effect = "나에게 오는 공이 2초간 절반 속도가 되고 타이밍 잡기도 쉬워진다",
		},
		id = {
			name = "Waktu Lambat",
			role = "Bertahan",
			effect = "Bola yang menuju ke arahmu jadi setengah kecepatan selama 2 dtk dan lebih mudah dipukul",
		},
	},
	Barrier = {
		en = {
			name = "Rift Barrier",
			role = "Defense",
			effect = "If you miss the incoming ball, it is returned once for you (as a very weak ball)",
		},
		es = {
			name = "Barrera Rift",
			role = "Defensa",
			effect = "Si fallas la pelota que viene, se devuelve sola una vez (muy floja)",
		},
		pt = {
			name = "Barreira Rift",
			role = "Defesa",
			effect = "Se você errar a bola que vem, ela é devolvida sozinha uma vez (bem fraca)",
		},
		ko = {
			name = "리프트 배리어",
			role = "방어",
			effect = "다가오는 공을 놓치면 한 번 자동으로 받아친다 (아주 약한 공)",
		},
		id = {
			name = "Perisai Rift",
			role = "Bertahan",
			effect = "Jika kamu gagal memukul bola yang datang, bola dikembalikan sekali otomatis (sangat lemah)",
		},
	},
	GravityWell = {
		en = { name = "Gravity Well", role = "Hinder", effect = "Your opponent moves at half speed for 4s" },
		es = {
			name = "Pozo gravitatorio",
			role = "Control",
			effect = "Tu rival se mueve a mitad de velocidad durante 4 s",
		},
		pt = {
			name = "Poço gravitacional",
			role = "Controle",
			effect = "Seu oponente anda na metade da velocidade por 4 s",
		},
		ko = {
			name = "그래비티 웰",
			role = "방해",
			effect = "상대의 이동 속도가 4초간 절반이 된다",
		},
		id = { name = "Sumur Gravitasi", role = "Hambat", effect = "Lawan bergerak setengah kecepatan selama 4 dtk" },
	},
	Blink = {
		en = { name = "Blink", role = "Move", effect = "Teleport 6 studs in the direction you are moving" },
		es = { name = "Parpadeo", role = "Movimiento", effect = "Te teletransportas 6 studs hacia donde te mueves" },
		pt = { name = "Lampejo", role = "Movimento", effect = "Teleporta 6 studs na direção em que você anda" },
		ko = { name = "블링크", role = "이동", effect = "움직이는 방향으로 6스터드 순간이동" },
		id = { name = "Kedip", role = "Gerak", effect = "Teleportasi 6 stud ke arah gerakmu" },
	},
}

-- Cosmetic item names (titles are shown as-is next to the player's name).
local ITEM: { [string]: Entry } = {
	paddle_cyan = { ja = "シアン", en = "Cyan", es = "Cian", pt = "Ciano", ko = "시안", id = "Sian" },
	paddle_magenta = {
		ja = "マゼンタ",
		en = "Magenta",
		es = "Magenta",
		pt = "Magenta",
		ko = "마젠타",
		id = "Magenta",
	},
	paddle_emerald = {
		ja = "エメラルド",
		en = "Emerald",
		es = "Esmeralda",
		pt = "Esmeralda",
		ko = "에메랄드",
		id = "Zamrud",
	},
	paddle_gold = { ja = "ゴールド", en = "Gold", es = "Oro", pt = "Ouro", ko = "골드", id = "Emas" },
	paddle_sakura = { ja = "サクラ", en = "Sakura", es = "Sakura", pt = "Sakura", ko = "사쿠라", id = "Sakura" },
	paddle_ice = { ja = "アイス", en = "Ice", es = "Hielo", pt = "Gelo", ko = "아이스", id = "Es" },
	paddle_lava = { ja = "マグマ", en = "Magma", es = "Magma", pt = "Magma", ko = "마그마", id = "Magma" },
	paddle_void = { ja = "ヴォイド", en = "Void", es = "Vacío", pt = "Vazio", ko = "보이드", id = "Hampa" },
	paddle_prism = { ja = "プリズム", en = "Prism", es = "Prisma", pt = "Prisma", ko = "프리즘", id = "Prisma" },
	trail_fire = { ja = "ほのお", en = "Fire", es = "Fuego", pt = "Fogo", ko = "불꽃", id = "Api" },
	trail_ice = { ja = "こおり", en = "Frost", es = "Escarcha", pt = "Geada", ko = "얼음", id = "Embun beku" },
	trail_sakura = { ja = "花びら", en = "Petals", es = "Pétalos", pt = "Pétalas", ko = "꽃잎", id = "Kelopak" },
	trail_gold = { ja = "黄金", en = "Golden", es = "Dorado", pt = "Dourado", ko = "황금", id = "Keemasan" },
	trail_toxic = { ja = "ポイズン", en = "Toxic", es = "Tóxico", pt = "Tóxico", ko = "포이즌", id = "Racun" },
	trail_galaxy = {
		ja = "ギャラクシー",
		en = "Galaxy",
		es = "Galaxia",
		pt = "Galáxia",
		ko = "갤럭시",
		id = "Galaksi",
	},
	title_rookie = { ja = "ルーキー", en = "Rookie", es = "Novato", pt = "Novato", ko = "루키", id = "Pemula" },
	title_rallyer = {
		ja = "ラリー職人",
		en = "Rally Artisan",
		es = "Maestro del peloteo",
		pt = "Mestre do rally",
		ko = "랠리 장인",
		id = "Ahli Reli",
	},
	title_perfect = {
		ja = "パーフェクト・マスター",
		en = "Perfect Master",
		es = "Maestro del PERFECTO",
		pt = "Mestre do PERFEITO",
		ko = "퍼펙트 마스터",
		id = "Master Sempurna",
	},
	title_smash = {
		ja = "スマッシュ職人",
		en = "Smash Artisan",
		es = "Rey del remate",
		pt = "Rei da cortada",
		ko = "스매시 장인",
		id = "Ahli Smes",
	},
	title_phantom = {
		ja = "幻影使い",
		en = "Phantom Caller",
		es = "Invocador de fantasmas",
		pt = "Invocador de fantasmas",
		ko = "환영술사",
		id = "Pemanggil Bayangan",
	},
	title_riftborn = {
		ja = "リフトの申し子",
		en = "Riftborn",
		es = "Hijo del Rift",
		pt = "Filho do Rift",
		ko = "리프트의 아이",
		id = "Anak Rift",
	},
	title_s1 = {
		ja = "シーズン1 経験者",
		en = "Season 1 Veteran",
		es = "Veterano T1",
		pt = "Veterano T1",
		ko = "시즌 1 베테랑",
		id = "Veteran Musim 1",
	},
	title_tester = {
		ja = "クローズドテスター",
		en = "Closed Tester",
		es = "Tester de beta cerrada",
		pt = "Tester da beta fechada",
		ko = "비공개 테스터",
		id = "Penguji Beta",
	},
}

local function pick(entry: Entry): string
	return (entry :: any)[current] or entry.en
end

-- Picks the language for a Roblox locale id such as "ja-jp" or "pt-br". Others get English.
function Strings.fromLocaleId(localeId: string?): Locale
	local code = if localeId then string.sub(string.lower(localeId), 1, 2) else ""
	for _, l in Strings.LOCALES do
		if l == code then
			return l
		end
	end
	return "en"
end

function Strings.setLocale(locale: Locale)
	current = locale
end

function Strings.locale(): Locale
	return current
end

-- The language after this one, for the menu's language button.
function Strings.nextLocale(): Locale
	local i = table.find(Strings.LOCALES, current) or 1
	return Strings.LOCALES[(i % #Strings.LOCALES) + 1]
end

function Strings.t(key: string, vars: { [string]: any }?): string
	local entry = T[key]
	if not entry then
		return key
	end
	local text = pick(entry)
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
	return if r then pick(r) else id
end

-- Rank label from an id ("Gold") and division ("II").
function Strings.rank(id: string, division: string?): string
	local r = RANK[id]
	local name = if r then pick(r) else id
	return if division then `{name} {division}` else name
end

function Strings.item(id: string): string
	local e = ITEM[id]
	return if e then pick(e) else id
end

local function abilityText(id: string): AbilityText?
	if current == "ja" then
		return nil
	end
	local byLang = ABILITY[id]
	return if byLang then (byLang[current] or byLang.en) else nil
end

function Strings.abilityName(id: string): string
	local t = abilityText(id)
	if t then
		return t.name
	end
	local def = Abilities.get(id)
	return if def then def.name else id
end

function Strings.abilityInfo(id: string): string
	local def = Abilities.get(id)
	if not def then
		return id
	end
	local t = abilityText(id)
	return Strings.t("ability.info", {
		name = Strings.abilityName(id),
		role = if t then t.role else def.role,
		cost = def.cost,
		effect = if t then t.effect else def.effect,
	})
end

-- For tests: every key, region, rank, item and ability has every language.
function Strings.missing(itemIds: { string }?): { string }
	local out = {}
	local function check(name: string, e: { [string]: any })
		for _, l in Strings.LOCALES do
			local v = e[l]
			if type(v) ~= "string" or v == "" then
				table.insert(out, `{name}:{l}`)
			end
		end
	end
	for key, e in T do
		check(key, e)
	end
	for key, e in REGION do
		check("region." .. key, e)
	end
	for key, e in RANK do
		check("rank." .. key, e)
	end
	for key, e in ITEM do
		check("item." .. key, e)
	end
	for _, id in itemIds or {} do
		if not ITEM[id] then
			table.insert(out, "item." .. id .. ":all")
		end
	end
	for _, def in Abilities.List do
		local byLang = ABILITY[def.id]
		for _, l in Strings.LOCALES do
			if l ~= "ja" and not (byLang and byLang[l]) then
				table.insert(out, `ability.{def.id}:{l}`)
			end
		end
	end
	return out
end

-- Every key the client code asks for literally, for a test that scans the sources.
function Strings.keys(): { [string]: boolean }
	local out = {}
	for k in T do
		out[k] = true
	end
	return out
end

return Strings
