# ストア用の画像

`art.html` から作ったアイコンとサムネイルです。色は `src/shared/Palette.luau`（ネオン・ルーフトップ）に合わせています。

| ファイル | 大きさ | 使い道 |
| --- | --- | --- |
| `icon.png` | 512×512 | アイコン |
| `key.png` | 1920×1080 | サムネイル（タイトル） |
| `powers.png` | 1920×1080 | サムネイル（8つの能力） |
| `ranked.png` | 1920×1080 | サムネイル（ランク戦） |

3枚のサムネイルは Creator Hub で「アクティブ」にしてあり、Roblox が出し分けて、反応の良いものを多く表示します。

## 作り直すとき

`art.html` を書き換えてから、このフォルダで次のコマンドを実行します（Google Chrome を画面に出さずに使います）。

```bash
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; P="$(pwd)"; T="$(mktemp -d)"
for s in icon:512,512 key:1920,1080 powers:1920,1080 ranked:1920,1080; do
  "$C" --headless=new --hide-scrollbars --user-data-dir="$T" --force-device-scale-factor=1 \
    --virtual-time-budget=8000 --window-size=${s#*:} --screenshot="$P/${s%%:*}.png" "file://$P/art.html#${s%%:*}"
done; rm -rf "$T"
```

できた画像は、Creator Hub の「プレース」→「アイコン」「サムネイル」からアップロードします。
