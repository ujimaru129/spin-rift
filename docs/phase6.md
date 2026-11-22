# フェーズ6 世界同時公開

6言語、アリーナ2つ、バトルパス シーズン1で世界に公開します。公開後は約2か月ごとに新シーズン（能力1〜2種類とアリーナ1つ）を追加します。

## ゲームに入れたもの

| 機能 | 内容 | 場所 |
| --- | --- | --- |
| 6言語 | 日本語・英語・スペイン語・ポルトガル語・韓国語・インドネシア語。プレイヤーの言語設定で自動的に選び、メニューのボタンで順に切り替えられる。それ以外の言語の人には英語 | `src/shared/Strings.luau` |
| サクラ・フロート | 2つ目のアリーナ。夕焼けの浮かぶ庭園、桜の木、灯籠、舞う花びら。最高レートがシルバー（1100）に届くと解放。メニューの「アリーナ」ボタンで選ぶ | `src/server/Arena.luau`、`src/client/ArenaLook.luau` |
| 風のギミック | サクラ・フロートのカジュアル戦と練習で、風がボールを横に流す（最大0.9スタッド）。風は左上に矢印で表示。ランク戦とチュートリアルでは風なし | `src/shared/Season/Arenas.luau` |
| バトルパス シーズン1 | 30レベル（1レベル400XP）。無料報酬6個、プレミアム報酬15個。プレミアムを買うと、到達済みのレベルの報酬もまとめて手に入る | `src/shared/Season/BattlePass.luau`、`src/server/Progression.luau` |
| XP | 勝ち120・負け60、その日最初の勝利で+200（翌日も遊ぶきっかけ）。Bot戦・カジュアル戦・ランク戦が対象。壁打ちとチュートリアルは対象外 | `BattlePass.xpFor` |
| 見た目アイテム | ラケット9種、ボールの軌跡6種、称号8種。メニューの「カスタマイズ」で付け替える。能力を使ったショットは、能力の色のまま（相手が読めるように） | `src/shared/Season/Cosmetics.luau` |
| テスター称号 | クローズドテストに参加した人に「クローズドテスター」の称号 | `src/server/ClosedTest.luau` |

### バトルパスの報酬

| レベル | 無料 | プレミアム |
| --- | --- | --- |
| 2 | | 軌跡：ほのお |
| 4 | | ラケット：ゴールド |
| 5 | 称号：ルーキー | |
| 6 | | 称号：パーフェクト・マスター |
| 8 | | 軌跡：花びら |
| 10 | ラケット：マゼンタ | ラケット：サクラ |
| 12 | | 軌跡：黄金 |
| 14 | | ラケット：アイス |
| 15 | 軌跡：こおり | |
| 16 | | 称号：スマッシュ職人 |
| 18 | | 軌跡：ポイズン |
| 20 | 称号：ラリー職人 | ラケット：マグマ |
| 22 | | 称号：幻影使い |
| 24 | | 軌跡：ギャラクシー |
| 25 | ラケット：エメラルド | |
| 26 | | ラケット：ヴォイド |
| 28 | | 称号：リフトの申し子 |
| 30 | 称号：シーズン1 経験者 | ラケット：プリズム |

勝ち負けを半々とすると、1試合あたり平均90XP（＋毎日のボーナス）なので、レベル30まで約130試合です。2か月のシーズンで、よく遊ぶ人が最後まで届く量にしています。

## 公開前のチェックリスト

### Creator Dashboard でやること

- [x] **プレミアムのゲームパスを作る**（ID 2096444234）：「収益化」→「パス」で、名前「Battle Pass Season 1 Premium」、価格400 Robux。作ったパスのIDを `src/server/Progression.luau` の `PREMIUM_PASS_ID` に書く（0のままだと、ボタンを押すと無料で手に入ってしまう）
- [x] **コンテンツの質問票（年齢区分）**に答える。暴力表現・課金のランダム要素（ガチャ）はなし
- [x] **ジャンル**を「スポーツ」に、**対応端末**をPC・スマホ・タブレット・ゲーム機に
- [x] **アイコンとサムネイル**を用意する（`docs/store/`）
- [x] **ゲームの説明文**を6言語で入れる（下の文面）。「ローカライズ」で言語ごとに設定する
- [x] **サーバーの最大人数**：ロビーで待つ人と、同じサーバーでのカジュアル戦があるので、20人程度がおすすめ
- [x] **APIサービス**（DataStore・MemoryStore）を有効にする
- [x] **公開範囲**を「公開」にする（2026-11-22。最初は16歳以上のみ。16歳未満に届けるには「プレイヤー100人」か「キッズとセレクトの公開クレジット」（返金可能な1,000 Robux）が必要）

### コードでやること

- [x] `src/server/ClosedTest.luau` の `ENABLED` を `false` に戻す（テスター限定を外す）
- [x] `PREMIUM_PASS_ID` を設定する
- [ ] Studio で Lighting の Technology を **Future** にしてから公開する
- [ ] スペイン語・ポルトガル語・韓国語・インドネシア語の文言を、その言語を話す人に確認してもらう（`src/shared/Strings.luau`）

### 公開後に見ること（最初の1週間）

| 見ること | 場所 | 目安 |
| --- | --- | --- |
| 同時接続数・新規プレイヤー | Creator Dashboard「分析」 | — |
| D1・D7リテンション | 「リテンション」 | D1 30%以上 |
| チュートリアルを終える人の割合 | 「オンボーディング」6÷2 | 70%以上 |
| ランク戦の待ち時間 | 「分析」→「カスタムイベント」の `RankedWait`（値＝待った秒数。内訳1＝終わり方 matched/bot/cancel/quit/requeue/other、内訳2＝待ち時間の範囲、内訳3＝地域）。平均＝合計÷件数 | マッチした人の平均30秒以内、bot が多すぎないこと |
| エラー | 「エラーレポート」 | 新しいエラーが増えていないか |
| プレミアムの購入率 | `PremiumBought` イベント | — |
| 感想・バグ報告 | `lune run tools/feedback` | — |

## 新シーズンの出し方（約2か月ごと）

1. `PlayerData.SEASON`、`Leaderboard.SEASON`、`BattlePass.SEASON` を1つ上げる（レートは1000に向けて70%に戻り、バトルパスは0から。アイテムは残る）
2. `BattlePass.Free` と `BattlePass.Premium` を新しい報酬に入れ替え、新しいアイテムを `Cosmetics.luau` と `Strings.luau`（6言語）に足す
3. 新しいプレミアムのゲームパスを作り、`PREMIUM_PASS_ID` を変える
4. 新しい能力を `Abilities.luau` に足したら、`lune run tools/balance 80` で勝率が45〜55%に入るまで調整する
5. 新しいアリーナを `Arenas.luau`、`Arena.luau`、`ArenaLook.luau` に足す
6. メニューの副題（`menu.subtitle`）とバトルパスの題（`pass.title`）を新シーズンに変える

## ストアの説明文

### 日本語

```
能力ありの卓球で、世界中のプレイヤーと1対1の真剣勝負！

■ 12種類の特殊能力から2つ選んで戦う
カーブ、3つに分身する球、透明な球、時間を遅くする…読み合いで勝て！

■ 世界中とランク戦
レートの近い相手と自動でマッチング。ブロンズからマスター、そして地域上位100人の「リフトレジェンド」へ。

■ 見た目は自由にカスタマイズ
バトルパスでラケット、ボールの軌跡、称号を集めよう。強さはお金で買えません。

PC・スマホ・タブレット・ゲーム機に対応。はじめての人は1分のチュートリアルから！
```

### English

```
1v1 table tennis battles with special abilities, against players from all over the world!

■ Pick 2 of 12 special abilities
Curve shots, balls that split into three, invisible bounces, slowing time… outsmart your opponent!

■ Ranked play worldwide
Get matched with players at your level. Climb from Bronze to Master, and join the top 100 of your region as a Rift Legend.

■ Make it yours
Collect paddles, ball trails and titles in the Battle Pass. Power can't be bought.

Play on PC, mobile, tablet and console. New? Start with the 1-minute tutorial!
```

### Español

```
¡Duelos 1 contra 1 de tenis de mesa con habilidades especiales, contra jugadores de todo el mundo!

■ Elige 2 de 12 habilidades especiales
Tiros con efecto, pelotas que se dividen en tres, botes invisibles, tiempo lento… ¡supera a tu rival!

■ Clasificatoria mundial
Te emparejamos con jugadores de tu nivel. Sube de Bronce a Maestro y entra en el top 100 de tu región como Leyenda Rift.

■ Hazlo tuyo
Consigue raquetas, estelas y títulos en el Pase de batalla. El poder no se compra.

Para PC, móvil, tableta y consola. ¿Eres nuevo? ¡Empieza con el tutorial de 1 minuto!
```

### Português

```
Duelos 1 contra 1 de tênis de mesa com habilidades especiais, contra jogadores do mundo todo!

■ Escolha 2 de 12 habilidades especiais
Tiros com efeito, bolas que viram três, quiques invisíveis, tempo lento… engane seu oponente!

■ Ranqueada mundial
Partidas com jogadores do seu nível. Suba do Bronze ao Mestre e entre no top 100 da sua região como Lenda Rift.

■ Deixe do seu jeito
Colete raquetes, rastros e títulos no Passe de batalha. Poder não se compra.

Para PC, celular, tablet e console. Novo por aqui? Comece pelo tutorial de 1 minuto!
```

### 한국어

```
특수 능력이 있는 탁구로 전 세계 플레이어와 1대1 진검승부!

■ 12가지 특수 능력 중 2개를 골라 싸우자
휘는 공, 3개로 분신하는 공, 투명한 공, 시간을 느리게 하는 능력… 수 싸움에서 이겨라!

■ 전 세계 랭크전
비슷한 실력의 상대와 자동 매칭. 브론즈부터 마스터, 그리고 지역 상위 100명 '리프트 레전드'까지.

■ 나만의 스타일로
배틀 패스로 라켓, 공 궤적, 칭호를 모으자. 강함은 돈으로 살 수 없습니다.

PC·모바일·태블릿·콘솔 지원. 처음이라면 1분 튜토리얼부터!
```

### Bahasa Indonesia

```
Duel tenis meja 1 lawan 1 dengan kemampuan spesial, melawan pemain dari seluruh dunia!

■ Pilih 2 dari 12 kemampuan spesial
Pukulan melengkung, bola yang terbelah tiga, pantulan tak terlihat, waktu melambat… kalahkan lawanmu dengan strategi!

■ Mode peringkat sedunia
Bertanding dengan pemain selevel. Naik dari Perunggu ke Master, lalu masuk 100 besar wilayahmu sebagai Legenda Rift.

■ Tampil beda
Kumpulkan raket, jejak bola, dan gelar di Battle Pass. Kekuatan tidak bisa dibeli.

Main di PC, ponsel, tablet, dan konsol. Pemain baru? Mulai dari tutorial 1 menit!
```

## 自動テスト

| ファイル | 内容 |
| --- | --- |
| `tests/Season.spec.luau` | バトルパスのレベルとXP（毎日のボーナス、壁打ちは対象外）、報酬が実在のアイテムで重複しないこと、装備できる条件、アリーナの解放条件、風があってもボールが台に落ちて表示どおりの位置に届くこと |
| `tests/Smoke.spec.luau` | 6言語すべての文言がそろっていること、画面で使っている文言がすべてあること。XPとレベル報酬、プレミアム購入（Studioではテスト用に無料）で到達済みの報酬が届くこと、持っていないアイテムは装備できないこと。シルバー未満ではサクラ・フロートを選べないこと、カジュアルでは風が吹くこと、相手に見た目アイテムが伝わること。バトルパスとカスタマイズの画面が6言語で描けること |
