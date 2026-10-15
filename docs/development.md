# 開発メモ

このリポジトリを改修するときの共通の約束事と、検証のやり方。判断の基準は `principles.md`、依頼の一覧は `backlog.md`。

## 構成と読み込み順
- `main.ahk` が入口。`Lib\` の部品を上から順に読み込み、そのあと `keymap\` のキー割り当てを読み込む。
- 部品は `#Include %A_LineFile%\..\○○.ahk` で、必要な部品を自分で読み込む。同じファイルは 1 回しか読み込まれない。
- キー割り当ては `keymap\hold_keys.ahk`（押しながら使う）と `keymap\leader_keys.ahk`（押して離してから次のキー）。機能の本体は `Lib\` に置き、keymap には呼び出しだけを書く。
- 使わなくなったものは `Lib\archive\` へ移す（読み込まれない）。

## 命名
- 関数・変数・クラスは、部品ごとの接頭辞を付けて重複を避ける：`QM_` / `QuickPalette`（クイックメニュー）、`Cap_`（画面キャプチャ。内部用は `_Cap_`）、`VimiumC_`（Vimium C 風ヒント）、`Mouse_`、`IH_`（入力待ち）など。
- AutoHotkey v2 は変数名・関数名・メソッド名の大文字小文字を区別しない。ローカル変数が同名のクラス・関数・static 変数を隠さないよう、別の名前にする（例：`gui := Gui(...)` は不可、`log` は `Log()` と衝突）。
- 設定値は部品の冒頭に大文字の変数で置く（例：`CAP_SAVE_DIR`）。

## 機能の足し方
- クイックメニューへの追加：`QuickPalette._Init()` に `this.Add(...)` を 1 行足す（書き方は `Lib/quick_menu.ahk` 冒頭）。カテゴリのキーを足すときは `Cats` にも書く。
- 入力待ち（Caps → ○ など）への追加：`keymap/leader_keys.ahk` の表に書く。空き（`""`）を探して地価の高い順に置く（`principles.md`）。
- キー割り当ての書き方は、`Lib/keymap_view.ahk`（キー割り当て一覧）が読めるように、既存の行と同じ形にする：`起点 & キー::  処理  ; コメント`、`"キー",  処理,  ; コメント`。新しい関数を割り当てたら、一覧に日本語で出るよう `KM_FUNC_NAMES` に足すか、行末にコメントを付ける。
- 選択中だけ有効にするホットキーは `#HotIf IsObject(状態)` で囲み、最後に `#HotIf` で戻す（例：`Cap_session`、`VimiumC_session`）。

## 検証
- 構文：`AutoHotkey64.exe /ErrorStdOut /validate main.ahk`（終了コード 0 なら問題なし）。実行ファイルは `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`。
- 動作：実際に動かして確かめる。キーやマウスの入力は、別プロセスの補助スクリプトから `SendLevel(1)` + `SendInput` で送る（既定のレベル 0 は、ほかの AutoHotkey のホットキーに無視される）。
- 一時ファイルは `_t_` で始まる名前にし、確認が終わったら削除する。
- 注意
  - 補助スクリプトが送るキーは、フォーカスのあるウィンドウに届く。操作中の端末や VS Code に届くと入力が混ざるので、対象のウィンドウを前面に出してから送る。
  - 別プロセスが送った入力は「物理入力」にならないので、`GetKeyState(キー, "P")` は偽のまま。試すときはその判定を一時的にファイルの有無などへ置き換えた複製で確かめる（複製は元と同じフォルダに置く）。
  - 補助スクリプトを同時に複数動かさない。前の実行の入力が次の実行に混ざる。
  - 一時ファイルの内容は、エディターのビューアーでなく端末の `Get-Content` で読む（更新前の内容が出ることがある）。

## AutoHotkey v2 の落とし穴
- 文字列の中でも、半角スペース + `;` はコメントの始まりになる。文字列に入れるときは `` `; `` とする。
- `"\""` はエスケープにならない。引用符は `'...'` で囲むか `""` を使う。PowerShell を呼ぶときは `.ps1` ファイルに書いて呼ぶ。
- JIS キーの無変換・変換・かなは `GetKeyName` が `""` を返す。`GetKeySC` / `GetKeyVK` で比べる。
- `A & B` の組み合わせの A（例：無変換 `vk1D`）は InputHook に届かない。`#HotIf` でホットキーとして受ける（`Lib/key_wait.ahk` の `IH_StopWithKey`）。
- 自分の `SendInput` は、自分のホットキーに無視される。
- IME のオン・オフは `SendInput("{vk16}")`（オン）/ `{vk1A}`（オフ）が確実。`WM_IME_CONTROL` は不安定。
- クリックを通す透明ウィンドウ：`+E0x20 +E0x08000000` に加えて `WinSetTransparent(250)`（透過属性が必要）。
- 全画面のウィンドウを `WinSetTransColor`（色抜き）で透かさない。`Show` の直後に画面全体が一瞬塗りつぶされて暗転する。透過・半透明の属性は `Show` の前に付け、見せたい部分だけを `SetWindowRgn` で切り抜く（`Lib/vimium_c_hints.ahk`、`Lib/screen_capture.ahk`）。
- 画面の座標は `config.ahk` で Per-Monitor v2（物理ピクセル）にしてある。GUI は `-DPIScale` を付けて物理ピクセルで指定する。
- UI Automation を使う部品は、仮想関数表の番号を部品の冒頭コメントに書いてある（`Lib/vimium_c_hints.ahk`、`Lib/screen_capture.ahk`）。
- `AutoHotkey64.exe /validate` の終了コードは、構文エラーがあっても 0 になる。出力の有無で判定する。存在しない変数名・関数名があると警告のダイアログで止まり、終わらないことがある（`Lib/keymap_view.ahk` の `Km_Validate` は時間切れで不可とする）。
- 組み込み関数と同じ名前（`log`）、クラスと同じ名前（`file` は `File`）は、グローバルの変数に使えない。アロー関数の中では `global` を書けないので、普通の関数にする。
- 変数名はクラス・関数と大文字小文字を区別されずに衝突する。関数 `Ppt_Align` と変数 `PPT_ALIGN` は同じ名前になり、読み込みでエラーになる（定数の変数には関数名と別の名前を付ける）。
- 自分が押した Shift（`SendInput("{LShift down}")`）を押したままにしても、ほかの `SendInput`（`{Blind}` なしを含む）では外れず、組み合わせのホットキー（`変換 & g` のような形）も発動する。ただし「*」なしの単独キーのホットキーは、Shift を押したままの間は発動しない。押したままのモードを作るときは、終了用に `*` 付きのホットキーを `#HotIf` で用意し、終了・`OnExit` で必ず離す（`Lib/shift_hold.ahk`）。
- 自動操作の試験では、`GetKeyState` は送った直後は前の状態を返すことがある。`Sleep` を挟んで読む。`A_TimeIdlePhysical` は人の入力がないと大きいままなので、時間切れの判定が即発動する。
- WebView2（`Lib/webview2/`）：ページから AHK へは `chrome.webview.postMessage(文字列)`、AHK からページへは `ExecuteScriptAsync("関数(...)")`。受け取りは `wv.WebMessageReceived(関数)` で、戻り値のオブジェクトを変数に持っておく（捨てると登録が外れる）。重い処理は、受け取った通知の中でなく `SetTimer(…, -1)` で回す。
