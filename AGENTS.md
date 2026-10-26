# このリポジトリで作業するときの約束

- 最初に [docs/development.md](docs/development.md) を読む（構成・命名・検証・AutoHotkey v2 の落とし穴）。設計の考え方は [docs/principles.md](docs/principles.md)。
- 返答は日本語で簡潔に。絵文字は使わない。
- キー割り当ての出典は `keymap/*.ahk` のコメントだけ。表やドキュメントに重ねて書かない。空きと言う前に keymap を検索して確かめる（利用者が直接編集する）。
- 大きなファイルは全体を読まず、検索で該当行だけ読む。
- 検証：構文は `AutoHotkey64.exe /ErrorStdOut /validate main.ahk`（出力が空なら問題なし）。動作は `tests\run_tests.ps1` を非同期の端末で動かし、出力は `FAIL|TOTAL` の行だけ見る。機能を足したら `tests\cases\` に 1 件足す。使い捨ての `_t_` スクリプトは作らない。
- 試験の間は、前面のウィンドウやキー・マウスに触らない（送ったキーが別の窓に届く）。
- 新しい説明用の Markdown は、頼まれない限り作らない。
