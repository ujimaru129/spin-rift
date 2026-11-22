# SPIN RIFT

能力ありの卓球で1対1の真剣勝負をする、Robloxのオンライン対戦ゲーム。

- 企画・仕様書：[卓球バトルゲーム 企画・仕様書](https://claude.ai/artifact/Wb7VtrggpjJEyZ8imLT5ab)
- コンセプトアート（3D）：[SPIN RIFT Concept Art](https://claude.ai/artifact/DBQq2aiGqVfSjMVeBLv6Ac)
- いまのフェーズ：[フェーズ1 手触りの試作](docs/phase1.md)

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

5. Studio で Lighting の Technology を **Future** にする（スクリプトからは変更できないため）
6. Play（F5）で遊ぶ

VS Code を使う場合は `.vscode/extensions.json` の推奨拡張（Rojo、luau-lsp、StyLua、selene）を入れてください。

## よく使うコマンド

| 目的 | コマンド |
| --- | --- |
| placeファイルを書き出す | `rojo build -o SpinRift.rbxl` |
| テスト（Lune） | `lune run tests/run` |
| 整形 | `stylua src tests` |
| Lint | `selene src` |

## フォルダ構成と Roblox 上の配置

| フォルダ | Roblox上の場所 | 内容 |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | サーバー・クライアント共通。`Rally` がゲームのルール |
| `src/server` | `ServerScriptService.Server` | 試合の進行（`PracticeService`）とアリーナの組み立て（`Arena`） |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | 操作、カメラ、ボールの描画（`BallView`）、画面のUI（`Hud`） |

ファイル名の規則（Rojo）: `*.server.luau` = Script、`*.client.luau` = LocalScript、`*.luau` = ModuleScript。

## ラリーの仕組み（`src/shared/Rally`）

Roblox の Instance を使わない純粋なロジックなので、サーバー・クライアント・Lune のテストで同じコードが動きます。

| モジュール | 役割 |
| --- | --- |
| `Config` | 台の大きさ、判定の時間幅、球の速さ、点数のルールなど、調整する数値をすべてここに集める |
| `Trajectory` | ボールの軌道。打った瞬間に「始点・バウンド位置・終点・高さ・飛ぶ時間」を決め、時刻から位置を計算する |
| `Judge` | 打つタイミングの判定（PERFECT / GOOD / あまい / MISS）、届く範囲、送られてきた時刻の補正 |
| `Match` | 1試合の進行。サーブ、ラリー、得点、7点先取とデュース、3ゲーム中2ゲーム先取、リフトゲージ |
| `Bot` | コンピューターの相手（壁打ち・やさしい・ふつう・つよい） |

ボールは Roblox の物理演算を使いません。サーバーが軌道を決めて全員に送り、各プレイヤーの画面は共通のサーバー時刻（`workspace:GetServerTimeNow()`）でその軌道を描きます。プレイヤーが送るのは「打った時刻と狙った方向」だけで、当たったかどうかはサーバーが判定します。
