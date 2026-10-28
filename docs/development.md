# 開発メモ

このリポジトリを改修するときの共通の約束事と、検証のやり方。判断の基準は `principles.md`、機能の使い方は `features.md`、依頼の一覧は `backlog.md`。

## ドキュメントの置き方
- `README.md` を短く保つ。読むときの負担を減らすため、大きくなったら分けて、終わったものは `docs\archive\` へ移す。
- **個々のキー割り当ては文書に書かない**（変えるたびに古くなる）。`keymap\` の行末コメントと、画面（クイックメニュー S → K）が正。文書に書くのは、レイヤーの役割とモードの動き。
- 依頼・アイデア：`backlog.md`（依頼の表。要約 1 行）、`ideas.md`（未実装）。終わった依頼の詳細・設計の経緯は `archive\backlog_history.md` / `archive\ideas_history.md` に置く（ここは経緯の記録で、現在の仕様とは違うことがある）。

## 構成と読み込み順
- `main.ahk` が入口。`Lib\` の部品を上から順に読み込み、そのあと `keymap\` のキー割り当てを読み込む。
- 部品は `#Include %A_LineFile%\..\○○.ahk` で、必要な部品を自分で読み込む。同じファイルは 1 回しか読み込まれない。
- キー割り当ては `keymap\hold_keys.ahk`（押しながら使う。末尾に単独の短押し）、`keymap\chord_keys.ahk`（変換 → 無変換 + ○ の 3 キー）と `keymap\chord_ordered_keys.ahk`（無変換 → 変換 + ○。どちらも `hold_keys.ahk` から先に読み込む。共通部品は `Lib\chord.ahk`）、`keymap\leader_keys.ahk`（押して離してから次のキー）。機能の本体は `Lib\` に置き、keymap には呼び出しだけを書く。
- 使わなくなったものは `Lib\archive\` へ移す（読み込まれない）。小さな関数は `Lib\archive\unused_functions.ahk` にまとめる。
- いくつかの部品で使うものの置き場所：表示まわり（`UI_Tip`、`UI_TipFlash`（既定のツールチップを一定時間で消す）、小窓の位置、モニターの番号・矩形、`UI_VisibleRect`、デスクトップ・タスクバーの判定 `UI_IsShellWindow`、UI Automation の生成 `UI_Uia`）は `Lib\ui_common.ahk`、入力待ち・選ぶモードの InputHook と、モードでのキーの読み替え（`IH_LayerSc` / `IH_SpaceAChar`）は `Lib\key_wait.ahk`、keymap の割り当て表の読み取りは `Lib\keymap_parse.ahk`、選択文字・文字の変換・クリップボードを戻す貼り付け（`QM_Paste`）は `Lib\text_ops.ahk`、ツールチップの番号（`TIP_ID_*`）は `Lib\config.ahk`。
- InputHook でキーをイベントで受けるモードを足すときは `Lib\key_mode.ahk` の `IHM_Run()` を使う（例：`Lib\mouse_grid.ahk`）。モードの状態を入れる変数（`MouseGrid_session` など）はモード側に持ち、`#HotIf IsObject(...)` や試験で使う。
- クイックメニューと記号メニューの小窓（タイトル・一覧・説明、Esc / 非アクティブ / 時間切れで閉じる）は `Lib\quick_menu.ahk` の `QM_ListPopup` が共通。同じ形の小窓を足すときはこれを使う。
- `quick_menu.ahk` はメニューの登録と画面だけを置き、メニューから呼ぶ処理の本体はそれぞれの部品（`text_ops` / `window_ops` / `screen_capture` など）に置く。

## ファイル一覧
```
main.ahk                 入口（これを実行する）。読み込みと Insert での再読み込み
keymap/
  hold_keys.ahk          押しながら使うレイヤー（変換 / 無変換 / Space ＋ 何か）と、短押し
  chord_keys.ahk         変換 → 無変換 を押したまま別のキー（3 キー）
  chord_ordered_keys.ahk 無変換 → 変換 を押したまま別のキー（3 キー）
  leader_keys.ahk        入力待ちの割り当て（Caps / Space+F / Space+A → 次のキー）
Lib/
  config.ahk             動作設定（常駐・フック・優先度など）、共通の定数（ツールチップの番号など）、キーコード早見表
  IME.ahk                IME の状態の取得・設定（外部から取得したライブラリ。変更しない）
  key_wait.ahk           入力待ちの共通部品（待機中の表示、キャンセル・タイムアウト、選ぶモード用の InputHook、モードでのキーの読み替え）
  keymap_parse.ahk       keymap の割り当て表を読む共通部品（割り当て一覧・入力待ちの一覧・モードでのキーの読み替えが使う）
  key_mode.ahk           InputHook でキーを受けるモードの共通の骨組み（リピートの無視・親指キーの読み替え・Space+A・時間切れ）
  chord.ahk              3 キーの割り当ての共通部品（押した順番の記録、両方押している間の判定、割り当てのないキーを止める）
  ui_common.ahk          表示まわりの共通部品（ツールチップ、小窓の位置、モニター、ウィンドウの矩形、デスクトップ・タスクバーの判定、UI Automation）
  text_input.ahk         文字入力の補助（IME の切り替え、大文字化、日付の入力、ホイールでのテキストカーソル移動）
  last_input.ahk         直前に入力した文字を覚えて、もう一度入力する。Space の短押しもここ
  text_ops.ahk           選択文字の取得・貼り付け、文字の変換、入力先の IME の状態、検索・翻訳（クイックメニューから呼ぶ）
  oneshot_modifiers.ahk  次のキーを Fn / Ctrl / Alt / Win 付きで送る入力モード
  shift_hold.ahk         Shift 長押しモード
  date_input.ahk         日付入力（日付を調整 → フォーマットを選んで入力）
  mouse_cursor.ahk       キーボードでのマウス操作（加速つきの移動、スクロール、ワープ、ドラッグ）
  mouse_grid.ahk         カーソル移動モード
  window_ops.ahk         ウィンドウ・仮想デスクトップ・システムの操作（クイックメニューから呼ぶ）
  window_switch.ahk      アプリ切り替え、タブ・ページ切り替え、モニター移動
  screen_saver.ahk       スクリーンセーバー回避
  vimium_c_hints.ahk     Vimium C 風ヒント
  quick_menu.ahk         クイックメニュー・コマンドパレット・記号メニュー（登録と画面だけ）
  multi_clipboard.ahk    マルチクリップボード
  screen_capture.ahk     画面キャプチャ
  capture_pin.ahk        付箋スクリーンショット（撮った画像を最前面に固定。screen_capture.ahk から使う）
  office_common.ahk      Office（PowerPoint・Word・Excel）共通の機能（図形編集モード）
  powerpoint_pack.ahk    PowerPoint 専用の機能（メニューには出していない）
  keymap_view.ahk / .html  キー割り当て・設定の画面（keymap のファイルを読んで JIS 配列の図を作り、WebView2 で開く。行の編集もできる）
  settings_view.ahk      設定値を画面の「設定」タブで確認・編集する部品（出す設定の一覧 SET_DEFS を持つ）
  webview2/, ComVar.ahk, Promise.ahk  外部の部品（thqby/ahk2_lib と Microsoft の WebView2Loader.dll）。変更しない
  archive/               使わなくなったスクリプトの保管場所（読み込まれない）
docs/                    README から分けた説明（features / principles / development / backlog / ideas）と、archive/（履歴）
```

## 3 キーの割り当てと短押し
- **短押し**：`hold_keys.ahk` 末尾の単独のホットキー（`*vk20::`、`vk1C::`、`vk1D::`）。「○ & キー」の起点のキーは、単独で押しても元の働き（空白、IME の変換）が出ないので、自分で送る。`*` なし（修飾キーを押すと発動しない）だと Shift+Space・Ctrl+Space が消えるので、Space は `*` 付きで `{Blind}{Space}` を送る。1 行で書く（キー割り当て一覧が読めるように）。
- **3 キー**：「A & B」は 2 キーまで。変換と無変換を両方押している間（`Chord_Both()`）の `#HotIf` の中に、起点を 2 つ重ねて書く（`vk1C & x::` の次の行に `vk1D & x:: 処理`。AutoHotkey がどちらを起点にするか決まらないため）。押した順番は、2 キーの組み合わせ（`vk1C & vk1D` / `vk1D & vk1C`）が `Chord_Begin` で `Chord_order` に覚え、`#HotIf` の条件に使う（`Lib\chord.ahk`）。
- 両方を押している間は、`hold_keys.ahk` の通常の割り当てを止める（`#HotIf !IH_waiting && !Chord_Both()`）。止めると割り当てのないキーが文字として入力されるので、`Chord_InstallCatchAll` が何もしないホットキーを足す。2 キーの組み合わせ（順番の記録）は、止めない別の欄に置く。
- 同じホットキーが複数の `#HotIf` にあると、先に読み込んだほうが優先される。`chord_*.ahk` を `hold_keys.ahk` の割り当てより前に読み込むのはこのため。
- キー割り当て一覧（`keymap_view.ahk`）は、3 キーを無変換側の行から読む。`KP_HotkeyRows` は「#HotIf !IH_waiting」で始まる欄を複数読む。

## 命名
- 関数・変数・クラスは、部品ごとの接頭辞を付けて重複を避ける：`QM_` / `QuickPalette`（クイックメニュー）、`Cap_`（画面キャプチャ。内部用は `_Cap_`）、`VimiumC_`（Vimium C 風ヒント）、`Mouse_`、`IH_`（入力待ち。共有の InputHook は `IH_hook`、待機中フラグは `IH_waiting`）、`KP_`（割り当て表の読み取り。`keymap_parse.ahk`）、`UI_`（表示の共通部品。`ui_common.ahk`）、`Office_` / `OFFICE_`（Office 共通。`office_common.ahk`）、`Ppt_` / `PPT_`（PowerPoint 専用。`powerpoint_pack.ahk`）など。`text_ops.ahk` / `window_ops.ahk` の関数は、クイックメニューから呼ぶものなので `QM_` のまま。
- AutoHotkey v2 は変数名・関数名・メソッド名の大文字小文字を区別しない。ローカル変数が同名のクラス・関数・static 変数を隠さないよう、別の名前にする（例：`gui := Gui(...)` は不可、`log` は `Log()` と衝突）。
- 設定値は部品の冒頭に大文字の変数で置く（例：`CAP_SAVE_DIR`）。キー割り当て一覧の「設定」タブで直すものは、`名前 := 値  ; 説明` の 1 行で書き、`Lib/settings_view.ahk` の `SET_DEFS` に 1 行（グループ・表示名・種類・範囲）足す。対応表（`Map`）や状態の変数は出さない。

## 機能の足し方
- クイックメニューへの追加：`QuickPalette._Init()` に `this.Add(...)` を 1 行足す（書き方は `Lib/quick_menu.ahk` 冒頭）。カテゴリのキーを足すときは `Cats` にも書く。アプリ専用の項目は、`this.Add(...)` の最後の引数に対象アプリ（`"office"` = Office のどれでも、`"ppt"` / `"word"` / `"excel"`）を渡すと、メニューを開いたときに前面だったアプリの項目だけが出る（項目が空のカテゴリは出ない）。
- 入力待ち（Caps → ○ など）への追加：`keymap/leader_keys.ahk` の表に書く。空き（`""`）を探して地価の高い順に置く（`principles.md`）。
- キー割り当ての書き方は、`Lib/keymap_view.ahk`（キー割り当て一覧）が読めるように、既存の行と同じ形にする：`起点 & キー::  処理  ; コメント`、`"キー",  処理,  ; コメント`。新しい関数を割り当てたら、一覧に日本語で出るよう `KM_FUNC_NAMES` に足すか、行末にコメントを付ける。
- 選択中だけ有効にするホットキーは `#HotIf IsObject(状態)` で囲み、最後に `#HotIf` で戻す（例：`Cap_session`、`VimiumC_session`）。

## 検証
- 既定は構文の確認だけで、動作は利用者が確かめる。`tests\`（キーの仕組みの回帰試験）は、起点キー・3 キー・入力待ち・Shift 長押しの仕組みを変えたときか、頼まれたときだけ流す。端末は同期で流して出力を捨て、終わってから結果のファイルを 1 回読む（試験中に別のコマンドを打つと、送ったキーが端末に混ざる）：
  `powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_tests.ps1 -Cases space | Out-Null` → `Get-Content $env:TEMP\_t_results.txt | Select-String 'FAIL|TOTAL'`（全部なら `-Cases` を省く。複数は `-Cases space,chord`）。
  - 仕組み：複製（`%TEMP%\_t_run`、`GetKeyState(キー,"P")` を旗ファイルに置き換え）の `main.ahk` を動かし、`tests\cases\*.ahk`（1 ファイル 1 プロセス、時間切れ 60 秒）が `tests\harness.ahk` の `T_Combo` / `T_Chord` などでキーを送って `T_Expect` で比べる。実行中の本物の `main.ahk` は `tests\suspend.ahk`（`on` / `off`）で前に止め、後で戻す（打ち切ったら `suspend.ahk リポジトリのパス off` で戻す）。
  - 試験の間は、キーボード・マウス・前面のウィンドウに触らない。試験は今の割り当てに依存する（割り当てを変えたら、対応する `cases` の期待値も直す）。
  - 試験を足すのは、手で確かめにくい不具合を直したときだけ（`space.ahk` を雛形に：`T_Start("edit"|"msg")` → 操作 → `T_Expect(名前, 実際, 期待)` → `T_End()`）。
  - 別の種類の試験が要るときだけ、下の手順で一時の補助スクリプトを書く。
- 構文：`AutoHotkey64.exe /ErrorStdOut /validate main.ahk 2>&1`（終了コード 0 で出力がなければ問題なし。関数の引数の数の誤りも見つける）。実行ファイルは `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`。
- 動作：実際に動かして確かめる。キーやマウスの入力は、別プロセスの補助スクリプトから `SendLevel(1)` + `SendInput` で送る（既定のレベル 0 は、ほかの AutoHotkey のホットキーに無視される）。
- 一時ファイルは `_t_` で始まる名前にし、確認が終わったら削除する。
- 実行中の `main.ahk`（自分の環境）が反応しないよう、試験の間は一時停止する：`PostMessage(0x111, 65305, , , "main.ahk ahk_class AutoHotkey")`（切り替えなので、終わったらもう一度送って戻す）。そのうえで、リポジトリを一時フォルダ（`%TEMP%`）へ複製して複製の `main.ahk` を動かし、補助スクリプトでキーを送る。物理入力の判定は、複製の中でだけ旗ファイルに置き換える。
- 長い試験は `.ps1` に書いて、結果をログファイルに出す。端末は `mode=async` で動かし、ログを読んで確かめる（同期で待つと端末が固まることがある）。補助スクリプトに構文エラーがあると、エラーのダイアログで止まって `-Wait` が終わらないので、`WaitForExit(時間)` で打ち切る。`.ps1` に日本語を書くときは BOM 付き UTF-8 にする（書かないのが無難）。
- 注意
  - 補助スクリプトが送るキーは、フォーカスのあるウィンドウに届く。操作中の端末や VS Code に届くと入力が混ざるので、対象のウィンドウを前面に出してから送る。
  - 別プロセスが送った入力は「物理入力」にならないので、`GetKeyState(キー, "P")` は偽のまま。試すときはその判定を一時的にファイルの有無などへ置き換えた複製で確かめる（複製は元と同じフォルダに置く）。
  - 補助スクリプトを同時に複数動かさない。前の実行の入力が次の実行に混ざる。
  - 一時ファイルの内容は、エディターのビューアーでなく端末の `Get-Content` で読む（更新前の内容が出ることがある）。
  - 補助スクリプトがキーを送っている間は、画面に触らず、別の端末も開かない。別のウィンドウが前に出ると、キーがそちらに届いて結果が無効になる。
  - 補助スクリプトは画面の拡大率（DPI）を意識しないので、`main.ahk`（Per-Monitor v2、物理ピクセル）と座標の単位が違う。マウスの位置を比べる試験では、補助スクリプトでも `SetThreadDpiAwarenessContext(-4)` を呼ぶ。
  - 大きな変更の前にはフォルダを複製し、変更前と後で同じ試験を流して結果を比べる（複製の `main.ahk` を動かして試す）。

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
- `AutoHotkey64.exe /validate` は、終了コードと出力の両方で判定する（エラーは標準エラー出力に出るので `2>&1` を付ける）。存在しない変数名・関数名があると警告のダイアログで止まり、終わらないことがある（`Lib/keymap_view.ahk` の `Km_Validate` は時間切れで不可とする）。
- 組み込み関数と同じ名前（`log`）、クラスと同じ名前（`file` は `File`）は、グローバルの変数に使えない。アロー関数の中では `global` を書けないので、普通の関数にする。
- 変数名はクラス・関数と大文字小文字を区別されずに衝突する。関数 `Ppt_Align` と変数 `PPT_ALIGN` は同じ名前になり、読み込みでエラーになる（定数の変数には関数名と別の名前を付ける）。
- 自分が押した Shift（`SendInput("{LShift down}")`）を押したままにしても、ほかの `SendInput`（`{Blind}` なしを含む）では外れず、組み合わせのホットキー（`変換 & g` のような形）も発動する。ただし「*」なしの単独キーのホットキーは、Shift を押したままの間は発動しない。押したままのモードを作るときは、終了用に `*` 付きのホットキーを `#HotIf` で用意し、終了・`OnExit` で必ず離す（`Lib/shift_hold.ahk`）。
- 自動操作の試験では、`GetKeyState` は送った直後は前の状態を返すことがある。`Sleep` を挟んで読む。`A_TimeIdlePhysical` は人の入力がないと大きいままなので、時間切れの判定が即発動する。
- WebView2（`Lib/webview2/`）：ページから AHK へは `chrome.webview.postMessage(文字列)`、AHK からページへは `ExecuteScriptAsync("関数(...)")`。受け取りは `wv.WebMessageReceived(関数)` で、戻り値のオブジェクトを変数に持っておく（捨てると登録が外れる）。重い処理は、受け取った通知の中でなく `SetTimer(…, -1)` で回す。
- 「A & B」の起点のキー（Space・変換・無変換）を単独で押して離しても、元の働きは出ない。単独のホットキー（`vk20::` など）を足して自分で送る（離したときに、組み合わせを使っていなければ発動する）。`*` なしだと、Shift / Ctrl を押している間は発動せず、そのキーが消える。
- `*vk20::` は、Shift などを押している間は離したときでなく押した時点で発動する（Shift 長押しモード中の Space+A で空白が入った）。`LastInput_SpaceTap` は、押した時点で呼ばれたら離すまで待ち、間にほかのホットキーが働いていれば送らない。
- 補助スクリプトが `SendInput` で送るとき、`{Blind}` なしだと、いま押している修飾キー（Shift 長押しモードの Shift など）がいったん離される。押したままの状態を試すときは `{Blind}` を付ける。Alt+Space はシステムメニューが開いて補助スクリプトが止まるので試さない。変数名 `log` も使わない（`Log()` と衝突する）。
- 同じ物理キーを、名前（`+`、`j` など）とスキャンコード（`sc027`）の両方でホットキーに書かない。スキャンコードで書いたホットキーが 1 つでもあると、そのキーはスキャンコード側で探され、名前で書いた別の行（`vk20 & +` など）が効かなくなる（Space+; が右矢印でなく `;` になった）。記号キーは名前で書く（`;` = `+`、`:` = `*`、`@` = `` ` ``）。スキャンコードで書くのは、名前のないキー（Caps、Tab、半角/全角、かな、`\`、`^`）だけで、すべての行を同じ書き方にそろえる。