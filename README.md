# SUPER BATTLE PING-PONG!!

能力ありの卓球で1対1の真剣勝負をする、Robloxのオンライン対戦ゲーム。

- 企画・仕様書：[卓球バトルゲーム 企画・仕様書](https://claude.ai/artifact/Wb7VtrggpjJEyZ8imLT5ab)
- コンセプトアート（3D）：[SPIN RIFT Concept Art](https://claude.ai/artifact/DBQq2aiGqVfSjMVeBLv6Ac)
- [フェーズ1 手触りの試作](docs/phase1.md)
- [フェーズ2 オンライン対戦](docs/phase2.md)
- [フェーズ3 特殊能力](docs/phase3.md)
- [フェーズ4 ランク戦とマッチング](docs/phase4.md)
- [フェーズ5 クローズドテスト](docs/phase5.md)
- いまのフェーズ：[フェーズ6 世界同時公開](docs/phase6.md)（公開前のチェックリスト、6言語のストア説明文、新シーズンの出し方）

## 開発環境のセットアップ

ツールのバージョンは `rokit.toml` で固定しています（Rojo / StyLua / selene / Lune）。

1. [Rokit](https://github.com/rojo-rbx/rokit) をインストール
2. リポジトリ直下でツールを入れる

   ```bash
   rokit install
   ```

3. Studioに Rojo プラグインを入れる（Rojo 7.7.1 と同じバージョン）

   ```bash
   rojo plugin install
   ```

4. Studio で新しい空の Place を開き、開発サーバーを起動して Rojo プラグインから Connect

   ```bash
   rojo serve
   ```

5. Lighting の Technology は **Future** にする。`rojo build` で作った place には `default.project.json` で最初から入っている。`rojo serve` で空の Place に同期するときは、Studio で手で Future にする（スクリプトからは変更できないため）
6. Play（F5）で遊ぶ

VS Code を使う場合は `.vscode/extensions.json` の推奨拡張（Rojo、luau-lsp、StyLua、selene）を入れてください。

## よく使うコマンド

| 目的 | コマンド |
| --- | --- |
| placeファイルを書き出す | `rojo build -o SpinRift.rbxl` |
| テスト（Lune） | `lune run tests/run` |
| 能力のバランスを測る | `lune run tools/balance 80` |
| 公開中のゲームの感想を読む | `ROBLOX_API_KEY=... lune run tools/feedback <ユニバースID> [out.csv]` |
| 整形 | `stylua src tests` |
| Lint | `selene src` |

## フォルダ構成と Roblox 上の配置

| フォルダ | Roblox上の場所 | 内容 |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | サーバー・クライアント共通。`Rally` が試合のルール、`Rank` がレートとマッチングのルール、`Strings` が画面の文言（6言語）、`Season` がアリーナ・見た目アイテム・バトルパス |
| `src/server` | `ServerScriptService.Server` | 試合の進行（`MatchService`）、アリーナ（`Arena`）、ランク戦（`RankedQueue`・`RankedRoom`・`RankedResult`）、成績の保存（`PlayerData`）、ランキング（`Leaderboard`）、バトルパスとアイテム（`Progression`）、感想（`Feedback`）、分析（`Analytics`）、テスター限定（`ClosedTest`） |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | 操作、カメラ、ボールの描画（`BallView`）、画面のUI（`Hud`）、アリーナごとの光（`ArenaLook`） |

ファイル名の規則（Rojo）: `*.server.luau` = Script、`*.client.luau` = LocalScript、`*.luau` = ModuleScript。

## ラリーの仕組み（`src/shared/Rally`）

Roblox の Instance を使わない純粋なロジックなので、サーバー・クライアント・Lune のテストで同じコードが動きます。

| モジュール | 役割 |
| --- | --- |
| `Config` | 台の大きさ、判定の時間幅、球の速さ、点数のルールなど、調整する数値をすべてここに集める |
| `Trajectory` | ボールの軌道。打った瞬間に「始点・バウンド位置・終点・高さ・飛ぶ時間」を決め、時刻から位置を計算する |
| `Judge` | 打つタイミングの判定（PERFECT / GOOD / あまい / MISS）、届く範囲、送られてきた時刻と位置の補正 |
| `Match` | 1試合の進行。サーブ、ラリー、得点、5点先取の1ゲームとデュース（4-4から）、リフトゲージ、途中退出 |
| `Bot` | コンピューターの相手（壁打ち・やさしい・ふつう・つよい）。能力も使う |
| `Abilities` | 8種類の能力の定義（名前、ゲージ、効果）と調整用の数値 |

ボールは Roblox の物理演算を使いません。サーバーが軌道を決めて全員に送り、各プレイヤーの画面は共通のサーバー時刻（`workspace:GetServerTimeNow()`）でその軌道を描きます。プレイヤーが送るのは「打った時刻と狙った方向」だけで、当たったかどうかはサーバーが判定します。

通信の遅れへの対策は [docs/phase2.md](docs/phase2.md) にまとめています。
