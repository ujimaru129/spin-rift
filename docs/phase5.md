# フェーズ5 クローズドテスト

Discordで集めた100〜300人に2週間遊んでもらい、「また遊びたくなるか」を確かめます。

**次に進む条件**：翌日も遊ぶ人（D1リテンション）が30%以上。

## ゲームに入れたもの

| 機能 | 内容 | 場所 |
| --- | --- | --- |
| 英語と日本語 | プレイヤーのRobloxの言語設定で自動的に切り替わる（日本語以外は英語）。メニューの「English／日本語」ボタンでも切り替えられる | `src/shared/Strings.luau` |
| チュートリアル | 1〜2分。①ボールを3回打ち返す ②PERFECTを1回出す ③能力（カーブショット）を使う。はじめての人には、メニューに案内を出す | `MatchService`（`Tutorial`） |
| 感想・バグ報告 | メニューの「感想・バグを送る」から、種類（楽しさ・バグ・能力とバランス・その他）を選んで200文字まで。1人1分に1回まで | `src/server/Feedback.luau` |
| 遊ばれ方の記録 | Robloxの分析機能に、はじめての人がどこまで進んだか（下の表）と、試合数・能力の使用回数・ランク戦の参加を送る | `src/server/Analytics.luau` |
| テスター限定 | テスター用のRobloxグループのメンバーだけが遊べる設定（初期はオフ） | `src/server/ClosedTest.luau` |

### はじめての人の進み具合（オンボーディングファネル）

Creator Dashboard の「分析」→「オンボーディング」で、どこで人が離れているかがわかります。

| 番号 | 段階 |
| --- | --- |
| 1 | 参加した |
| 2 | チュートリアルを始めた |
| 3 | はじめて打ち返した |
| 4 | はじめてPERFECTを出した |
| 5 | はじめて能力を使った |
| 6 | チュートリアルを終えた |
| 7 | はじめて試合を最後までやった |
| 8 | はじめてランク戦を最後までやった |

### その他の記録（カスタムイベント）

| イベント名 | いつ | 内訳 |
| --- | --- | --- |
| `MatchFinished` | 試合が終わった | モード（Wall / Easy / Normal / Hard / Online / Ranked / Tutorial）、勝ち負け |
| `AbilityUsed` | 能力を使った | 能力、モード |
| `RankedQueued` | ランク戦の待ち行列に入った | 入れたか（ok / banned） |
| `Feedback` | 感想を送った | 種類 |

## 開始前の準備

### 1. テスター用のグループを作る（テスター限定にする場合）

1. Robloxでグループを作る（例：「SUPER BATTLE PING-PONG Testers」）
2. グループのURLにある数字（グループID）を確認する
3. `src/server/ClosedTest.luau` を次のように変える

   ```lua
   ClosedTest.ENABLED = true
   ClosedTest.GROUP_ID = 12345678 -- 自分のグループID
   ClosedTest.MIN_RANK = 1
   ```

4. グループに参加していない人が入ると、日本語と英語で「クローズドテスト中です。テスター用のグループに参加してから遊んでください」と表示されて退出になる（Studioでは制限なし）

グループを作らずに、ゲームを公開して誰でも遊べる状態でテストしてもかまいません。その場合は `ENABLED = false` のままにします。

### 2. ゲームを公開する

1. Studioで「ファイル」→「Robloxに公開」
2. 「ゲーム設定」→「セキュリティ」で「APIサービスへのStudioアクセスを有効にする」をオン（Studioでの確認用）
3. 「ゲーム設定」→「権限」で公開範囲を「公開」にする（テスター限定はグループで制限）
4. Lighting の Technology を Future にしてから公開する

### 3. 感想を読めるようにする（APIキー）

1. https://create.roblox.com/dashboard/credentials でAPIキーを作る
2. 権限に「DataStore」を追加し、このゲームを選んで「エントリの一覧」と「エントリの読み取り」を許可する
3. 次のコマンドで感想を読む（CSVにも保存できる）

   ```bash
   ROBLOX_API_KEY=作ったキー lune run tools/feedback ユニバースID feedback.csv
   ```

   ユニバースIDは、Creator Dashboard のゲームのページにあります。

## スケジュール（2週間）

| 時期 | やること |
| --- | --- |
| 開始の1週間前 | Discordサーバーを作り、募集を始める（下の文面） |
| 1日目 | テスト開始。開始の告知、遊び方の説明 |
| 2〜3日目 | 最初の感想をまとめ、大きなバグを直して更新する |
| 4日目 | **D1リテンションを見る**（1〜3日目に始めた人） |
| 7日目 | 中間アンケート。必要なら能力の数値を調整 |
| 8〜13日目 | 調整版で遊んでもらう。ランク戦の待ち時間も確認 |
| 14日目 | 終了アンケート、結果をまとめて次に進むか決める |

## 見る数字と、どこで見るか

| 数字 | 目標 | 見る場所 |
| --- | --- | --- |
| D1リテンション | 30%以上 | Creator Dashboard →「分析」→「リテンション」 |
| チュートリアルを終える人の割合 | 70%以上（目安） | 「オンボーディング」の6÷2 |
| 1人あたりの試合数 | — | `MatchFinished` の数 ÷ 参加人数 |
| ランク戦の待ち時間 | 平均30秒以内 | フェーズ4の条件。ランク戦に人が集まる時間帯に確認 |
| 能力ごとの使われ方 | 極端な偏りがない | `AbilityUsed` の内訳 |
| バグ報告 | 重大なものが0件 | `tools/feedback` |

## Discordでの募集文

### 日本語

```
🏓 SUPER BATTLE PING-PONG!! クローズドテスト参加者募集！

能力ありの卓球で1対1の真剣勝負をする、Robloxの新作ゲームです。
カーブ、分身、透明な球、時間を遅くする…8種類の能力を2つ選んで、
世界中のプレイヤーとランク戦！

📅 期間：○月○日〜○月○日（2週間）
🎮 対応：PC・スマホ・タブレット・ゲーム機
👥 募集：100〜300人（先着）
🎁 参加特典：正式公開時にテスター限定の称号（予定）

参加方法
1. このサーバーの #テスト参加 で ✅ を押す
2. テスター用グループに参加する：（グループのURL）
3. ゲームに参加する：（ゲームのURL）

遊んだら、ゲーム内の「感想・バグを送る」ボタンか #感想 チャンネルで教えてください！
```

### English

```
🏓 SUPER BATTLE PING-PONG!! Closed test — testers wanted!

A new Roblox game: 1v1 table tennis battles with special abilities.
Curve shots, phantom balls, invisible bounces, time slow… pick 2 of 8 abilities
and climb the ranked ladder against players from around the world!

📅 Dates: MM/DD – MM/DD (2 weeks)
🎮 Platforms: PC, mobile, tablet, console
👥 Spots: 100–300 players (first come, first served)
🎁 Reward: tester-only title at launch (planned)

How to join
1. React with ✅ in #join-the-test
2. Join the tester group: (group link)
3. Play: (game link)

Tell us what you think with the in-game "Send feedback" button or in #feedback!
```

### Discordサーバーのチャンネル案

| チャンネル | 用途 |
| --- | --- |
| #お知らせ / #announcements | 更新の告知 |
| #テスト参加 / #join-the-test | 参加の受付 |
| #感想 / #feedback | 自由な感想 |
| #バグ報告 / #bug-reports | バグ（スクリーンショット歓迎） |
| #対戦相手募集 / #find-a-match | ランク戦の相手探し（人が少ない時間帯の対策） |

## アンケート（中間・終了時）

1. このゲームは楽しいですか？（1〜5）
2. 友達にすすめたいですか？（0〜10）
3. いちばん好きな能力と、いちばん嫌いな能力は？ その理由は？
4. 「強すぎる」「弱すぎる」と感じた能力は？
5. ランク戦の相手はすぐ見つかりましたか？
6. 操作でわかりにくかったところは？（PC／スマホ／ゲーム機）
7. 次も遊びたいと思いますか？ 思わない場合、何があれば遊びたいですか？

## 自動テスト

`tests/Smoke.spec.luau` に追加：

- すべての文言に日本語と英語があること。画面を英語に切り替えて、また日本語に戻せること
- チュートリアルを最後まで進められ（3回打ち返す→PERFECT→能力）、完了が保存され、進み具合が記録されること
- 感想が保存され、1分以内の2回目は断られ、不正な種類は受け付けないこと
- テスター限定をオンにすると、グループ外の人は退出になり、メンバーは入れること（Studioでは制限なし）

`tools/feedback.luau` は、Open Cloud と同じ形で返事をする偽のサーバーに対して、読み出しとCSVへの保存ができることを確かめました。本物の Open Cloud に対しては、まだ試していません。
