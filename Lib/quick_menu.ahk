#Requires AutoHotkey v2.0
;==============================================================================
; quick_menu.ahk
; QuickPalette : 便利機能をまとめて呼び出すランチャー（AutoHotkey v2）
;------------------------------------------------------------------------------
; 【3つの呼び出し方】
; (1) コマンドパレット（QuickPalette_Show）… Caps → u
;     機能の一覧と入力欄を表示する。各機能には英語の短い名前（英名）が付いており、
;     一覧の先頭の列に表示している。
;       ・半角英字を打つ … 英名がその文字で始まる機能へジャンプする
;                          例：u → upper（大文字に）、cl → clipboard、sy → symbols
;                          続けて打つほど絞れる。BS で 1 文字戻す。
;       ・英名に当てはまらない入力 … 日本語名・キーワードで一覧を絞り込む
;       ・↑↓ または Ctrl+J / Ctrl+K … 選択を移動
;       ・Enter / ダブルクリック        … 実行
;
; (2) クイックメニュー（QuickMenu_Show）… Caps → j
;     英字 1 文字でカテゴリを選び、もう 1 文字で機能を実行する（2 打鍵）。
;       例：T → U … 選択中の文字を大文字に
;           I → K … 記号メニューを開く
;       ・BS / ← … カテゴリ一覧に戻る
;
; (3) 記号メニュー（QM_SymbolMenu_Show）… Caps → k（2026/09/30 追加）
;     記号の一覧を表示し、英字 1 文字でその記号を入力する。
;     キーは記号の英語名の頭文字（重なるものは英語名の中の目立つ文字）。
;       E ! Exclamation     H # Hash           D $ Dollar        R % peRcent
;       N & ampersaNd(and)  C ^ Caret          T ~ Tilde         B \ Backslash
;       V | Vertical bar    A @ At sign        G ` Grave accent  Q ? Question
;       P + Plus            M - Minus          X * asterisk(×)   S / Slash
;     ・見た目は QM_SYMBOL_UI で切り替える（このファイルの下の方）。既定は "tooltip"（ツールチップ。キーを InputHook で受ける。Lib\symbol_quick.ahk）。
;       "window" にすると、以前の小窓（下の説明）に戻る
;     ・小窓版：↑↓ + Enter、マウスのクリックでも選べる
;     ・一覧の順番と割り当ては QM_SymbolMenu.Symbols で変更できる
;     ・全角／半角の自動切り替え（2026/09/30 追加）
;         開く直前に入力先の IME の状態を調べ、
;           IME オフ・半角英数          → 半角で入力（!）
;           ひらがな・カタカナ・全角英数 → 全角で入力（！）
;         メニューのタイトルに「半角」「全角」を表示する。
;         判定が外れたときは Space で切り替えられる。
;         全角の文字を個別に変えたいときは QM_SymbolMenu.FULL_OVERRIDE に書く。
;
; 【閉じ方（共通）】
;   ・Esc                           … 閉じて元のウィンドウに戻る
;   ・ほかの場所をクリック / Alt+Tab … 閉じる
;   ・Caps をもう一度押す            … 閉じる（開いているときだけ有効）
;   ・一定時間操作しない             … メニューを閉じる（MENU_TIMEOUT_MS で設定。0 で無効）
;   ・同じ呼び出しをもう一度         … メニューを閉じる（開閉の切り替え）
;
; 【機能を追加するには】
; QuickPalette._Init() の中に、次の形式で 1 行追加する。
;     this.Add("カテゴリの英字", "メニュー用の英字", "英名", "表示名", 実行する関数, "検索キーワード")
;   ・英名は半角英小文字・数字・ハイフン。ほかの機能と頭文字がなるべく重ならないものにする。
;   ・表示名に " を含めるときは、全体を '...' で囲む（\" は使えない）。
;
; 【注意】
; ・選択文字を扱う機能は、クリップボード経由でコピー・貼り付けを行う。
;   実行後、クリップボードは元の内容に戻す。
; ・関数名・変数名はすべて QM_ / QuickPalette / QuickMenu で始めて、
;   既存のスクリプトと重複しないようにしている。
; ・AutoHotkey v2 は変数名とメソッド名の大文字小文字を区別しないため、
;   static 変数にはメソッドと重ならない名前を付けること。
;
; 【ファイルの分け方】
; このファイルはメニュー（登録と画面）だけ。メニューから呼ぶ処理の本体は次のファイルにある。
;   ui_common.ahk  … ツールチップ（UI_Tip）、小窓の位置、モニター（ほかの部品も使う）
;   text_ops.ahk   … 選択文字の取得・貼り付け、文字の変換、IME の状態、検索・翻訳
;   window_ops.ahk … ウィンドウ・仮想デスクトップ・システムの操作
;==============================================================================

#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\text_ops.ahk
#Include %A_LineFile%\..\last_input.ahk
#Include %A_LineFile%\..\symbol_quick.ahk
#Include %A_LineFile%\..\window_ops.ahk
#Include %A_LineFile%\..\multi_clipboard.ahk
#Include %A_LineFile%\..\screen_capture.ahk
#Include %A_LineFile%\..\keymap_view.ahk
#Include %A_LineFile%\..\powerpoint_pack.ahk
#Include %A_LineFile%\..\date_input.ahk

class QuickPalette {
    ;--- 設定 -----------------------------------------------------------------
    static MENU_TIMEOUT_MS := 15000  ; 操作がないとき自動で閉じるまでの時間 [ms]（0 で無効）

    ;--- カテゴリ（メニューの表示順）--------------------------------------------
    static Cats := [
        {key: "T", name: "テキスト変換"},
        {key: "I", name: "挿入"},
        {key: "N", name: "日付・時刻"},
        {key: "W", name: "ウィンドウ"},
        {key: "D", name: "仮想デスクトップ"},
        {key: "G", name: "検索・翻訳"},
        {key: "S", name: "システム"},
        {key: "C", name: "画面キャプチャ"},
        {key: "M", name: "マルチクリップボード"},
        {key: "A", name: "アプリ・フォルダ"},
        {key: "V", name: "VS Code"},
        {key: "P", name: "PowerPoint"}]

    static Items := []
    static _inited := false
    static _used   := Map()     ; 表示名 → 最後に使った時刻（最近使った順の並べ替え用）
    static _view   := []        ; パレットの ListView の行番号 → 項目
    static _target := 0         ; パレット／メニューを開く前にアクティブだったウィンドウ

    ; クイックメニューの状態（画面は QM_ListPopup）
    static _menu   := 0         ; QM_ListPopup
    static _mLevel := ""        ; "" = カテゴリ一覧、それ以外 = 表示中のカテゴリの英字
    static _mView  := []        ; メニューの行番号 → {type, key, it}

    ;=== 機能の登録 =============================================================
    static _Init() {
        if this._inited
            return
        this._inited := true

        ;--- テキスト変換（選択中の文字を変換して置き換える）---------------------
        this.Add("T", "U", "upper",        "大文字に",                      (*) => QM_TransformSelection(StrUpper), "oomoji")
        this.Add("T", "L", "lower",        "小文字に",                      (*) => QM_TransformSelection(StrLower), "komoji")
        this.Add("T", "T", "titlecase",    "単語の先頭を大文字に",          (*) => QM_TransformSelection(StrTitle), "capitalize")
        this.Add("T", "H", "halfwidth",    "英数字・記号を半角に",          (*) => QM_TransformSelection(QM_ToHalfAlnum), "hankaku eisuu")
        this.Add("T", "K", "fullkana",     "半角カナを全角に",              (*) => QM_TransformSelection(QM_HalfKanaToFull), "zenkaku kana")
        this.Add("T", "A", "katakana",     "ひらがな → カタカナ",           (*) => QM_TransformSelection(QM_ToKatakana), "")
        this.Add("T", "R", "hiragana",     "カタカナ → ひらがな",           (*) => QM_TransformSelection(QM_ToHiragana), "")
        this.Add("T", "J", "joinlines",    "改行を削除して 1 行に",         (*) => QM_TransformSelection(QM_JoinLinesText), "kaigyou pdf")
        this.Add("T", "E", "trimlines",    "行の前後の空白と空行を削除",    (*) => QM_TransformSelection(QM_TrimLines), "kuuhaku empty")
        this.Add("T", "B", "bullets",      "行頭に「・」を付ける",          (*) => QM_TransformSelection(QM_Bullets), "kajougaki")
        this.Add("T", "S", "sortlines",    "行を並べ替え",                  (*) => QM_TransformSelection(QM_SortLines), "narabekae")
        this.Add("T", "D", "dedup",        "重複した行を削除",              (*) => QM_TransformSelection(QM_DedupLines), "unique chouhuku")
        this.Add("T", "Q", "unquote",      'パスの引用符 "" を除去',        (*) => QM_TransformSelection(QM_Unquote), "path quote inyoufu")
        this.Add("T", "P", "slashpath",    "パスの \ を / に",              (*) => QM_TransformSelection(QM_BackslashToSlash), "path")
        this.Add("T", "C", "count",        "文字数・行数を数える",          (*) => QM_CountSelection(), "mojisuu")
        this.Add("T", "V", "plainpaste",   "書式なしで貼り付け",            (*) => QM_PastePlain(), "harituke")

        ;--- 挿入 ---------------------------------------------------------------
        this.Add("I", "K", "symbols",      "記号メニュー（! # $ % & …）",   (*) => QM_SymbolMenu_Show(), "kigou symbol")

        ;--- 日付・時刻（上段 y u i o p：日付、中段 h j k l：時刻、下段：曜日・ファイル名用）----------
        ; Space+F の u で日付・時刻メニュー、i で日付入力、o で yyyy/MM/dd、p で yyMMdd_ を直接呼べる
        this.Add("N", "N", "date-pick",    "日付を選んで入力（日付 → フォーマットの順に選ぶ）", (*) => DateInput_Start(), "hiduke nyuuryoku select")
        this.Add("N", "Y", "date-full",    "日時（yyyy/MM/dd HH:mm:ss）",      (*) => QM_InsertTime("yyyy/MM/dd HH:mm:ss"), "hiduke jikoku nichiji")
        this.Add("N", "U", "date-ymd",     "日付（yyyy/MM/dd）",               (*) => QM_InsertTime("yyyy/MM/dd"), "hiduke")
        this.Add("N", "I", "date-short",   "日付（yy/MM/dd）",                 (*) => QM_InsertTime("yy/MM/dd"), "hiduke")
        this.Add("N", "O", "date-num",     "日付（yyyyMMdd）",                 (*) => QM_InsertTime("yyyyMMdd"), "hiduke filename")
        this.Add("N", "P", "date-page",    "日付（yyMMdd_）Obsidian のページ名用", (*) => QM_InsertTime("yyMMdd_"), "hiduke obsidian")
        this.Add("N", "H", "time-hm",      "時刻（HH:mm）",                    (*) => QM_InsertTime("HH:mm"), "jikoku")
        this.Add("N", "J", "time-hms",     "時刻（HH:mm:ss）",                 (*) => QM_InsertTime("HH:mm:ss"), "jikoku")
        this.Add("N", "K", "time-hmsnum",  "時刻（HHmmss）",                   (*) => QM_InsertTime("HHmmss"), "jikoku filename")
        this.Add("N", "L", "time-hmnum",   "時刻（HHmm）",                     (*) => QM_InsertTime("HHmm"), "jikoku filename")
        this.Add("N", "M", "date-minute",  "日時（yyyy/MM/dd HH:mm）",         (*) => QM_InsertTime("yyyy/MM/dd HH:mm"), "hiduke jikoku nichiji")
        this.Add("N", "W", "date-week",    "日付と曜日（yyyy/MM/dd(ddd)）",    (*) => QM_InsertTime("yyyy/MM/dd(ddd)"), "hiduke youbi")
        this.Add("N", "D", "date-file",    "ファイル名用（yyyyMMdd_HHmmss）",   (*) => QM_InsertTime("yyyyMMdd_HHmmss"), "hiduke jikoku filename")
        this.Add("N", "F", "date-filemin", "ファイル名用（yyyyMMdd_HHmm）",     (*) => QM_InsertTime("yyyyMMdd_HHmm"), "hiduke jikoku filename")

        ;--- ウィンドウ ---------------------------------------------------------
        this.Add("W", "T", "topmost",      "常に最前面を切り替え",          (*) => QM_ToggleTopmost(), "saizenmen")
        this.Add("W", "R", "opacity",      "半透明を切り替え",              (*) => QM_ToggleTransparent(), "transparent toumei")
        this.Add("W", "C", "center",       "画面の中央へ移動",              (*) => QM_CenterWindow(), "chuuou")
        this.Add("W", "I", "wininfo",      "ウィンドウ情報をコピー",        (*) => QM_CopyWindowInfo(), "ahk_exe class")

        ;--- 仮想デスクトップ ---------------------------------------------------
        this.Add("D", "C", "desk-new",     "新しいデスクトップを作成",      (*) => QM_DesktopNew(), "virtual desktop create sakusei")
        this.Add("D", "X", "desk-close",   "今のデスクトップを閉じる",      (*) => QM_DesktopClose(), "virtual desktop delete sakujo")
        this.Add("D", "N F `;", "desk-next",  "次（右）のデスクトップへ",      (*) => QM_DesktopStep(1), "virtual desktop switch kirikae")
        this.Add("D", "P J A", "desk-prev",  "前（左）のデスクトップへ",      (*) => QM_DesktopStep(-1), "virtual desktop switch kirikae")
        this.Add("D", "W", "carry-next",   "ウィンドウを連れて次へ",        (*) => QM_DesktopStep(1, true), "virtual desktop move window idou")
        this.Add("D", "Q", "carry-prev",   "ウィンドウを連れて前へ",        (*) => QM_DesktopStep(-1, true), "virtual desktop move window idou")
        this.Add("D", "M", "carry-new",    "新しいデスクトップへウィンドウを移動", (*) => QM_DesktopNew(true), "virtual desktop move window idou")
        this.Add("D", "T", "taskview",     "タスクビュー（Win+Tab）",       (*) => Send("#{Tab}"), "virtual desktop ichiran")
        this.Add("D", "I", "desk-info",    "今のデスクトップ番号を表示",    (*) => QM_DesktopInfo(), "virtual desktop bangou")
        ; 番号を指定して切り替える QM_DesktopGo は、使わないので Lib\archive\unused_functions.ahk に移した（戻し方はそのファイルの冒頭）

        ;--- 検索・翻訳 ---------------------------------------------------------
        this.Add("G", "G", "google",       "選択文字を Google 検索",        (*) => QM_WebSelection("https://www.google.com/search?q="), "search kensaku")
        this.Add("G", "J", "ja-translate", "選択文字を日本語に翻訳",        (*) => QM_WebSelection("https://translate.google.com/?sl=auto&tl=ja&text="), "honyaku japanese")
        this.Add("G", "E", "en-translate", "選択文字を英語に翻訳",          (*) => QM_WebSelection("https://translate.google.com/?sl=auto&tl=en&text="), "honyaku english")

        ;--- システム -----------------------------------------------------------
        this.Add("S", "V", "clipboard",    "クリップボード履歴（Win+V）",   (*) => Send("#v"), "history rireki")
        this.Add("S", "P", "peekclip",     "クリップボードの内容を表示",    (*) => QM_ShowClipboard(), "clipboard preview")
        this.Add("S", "S", "screenshot",   "画面の範囲キャプチャ",          (*) => Send("#+s"), "capture snip")
        this.Add("S", "E", "emoji",        "絵文字パネル",                  (*) => Send("#."), "kigou")
        this.Add("S", "T", "taskmgr",      "タスクマネージャー",            (*) => Send("^+{Esc}"), "task")
        this.Add("S", "L", "lock",         "PC をロック",                   (*) => DllCall("LockWorkStation"), "")
        this.Add("S", "O", "monitoroff",   "画面を消す",                    (*) => QM_DisplayOff(), "display off")
        this.Add("S", "R", "reload",       "スクリプトを再読み込み",        (*) => Reload(), "ahk")
        this.Add("S", "K", "keymap",       "キー割り当て一覧（JIS 配列）",   (*) => Keymap_Show(), "keyboard layout kiihaiti wariate")

        ;--- 画面キャプチャ（Lib\screen_capture.ahk。使わない撮り方は Lib\archive\capture_extras.ahk に移した）----------------
        this.Add("C", "R", "cap-region",  "範囲を指定（ドラッグ）",          (*) => Cap_Region(), "capture screenshot snip hanni")
        this.Add("C", "T", "cap-trim",    "範囲を指定（端を自動トリミング）", (*) => Cap_RegionTrim(), "capture screenshot trim crop hanni kiritori")
        this.Add("C", "W", "cap-window",  "ウィンドウを選んで全体",          (*) => Cap_Window(), "capture screenshot window")
        this.Add("C", "C", "cap-area",    "ウィンドウ内のクリックした領域",  (*) => Cap_Area(), "capture screenshot element buhin ryouiki")

        ;--- マルチクリップボード -----------------------------------------------
        this.Add("M", "S", "clip-save",    "選択文字を箱にコピー保存",      (*) => Clip_Copy(), "clipboard box save copy")
        this.Add("M", "X", "clip-cut",     "選択文字を箱に切り取り保存",    (*) => Clip_Cut(), "clipboard box cut")
        this.Add("M", "P", "clip-paste",   "箱から貼り付け",                (*) => Clip_Paste(), "clipboard box paste")
        this.Add("M", "C", "clip-content", "箱の中身を見る",              (*) => Clip_Show(), "clipboard box content list")
        this.Add("M", "D", "clip-clear",   "箱を空にする",                  (*) => Clip_Clear(), "clipboard box clear delete")

        ;--- アプリ・フォルダ ---------------------------------------------------
        this.Add("A", "D", "downloads",    "ダウンロードフォルダ",          (*) => Run("shell:Downloads"), "folder")
        this.Add("A", "S", "scriptdir",    "スクリプトのフォルダ",          (*) => Run(A_ScriptDir), "folder ahk")
        this.Add("A", "C", "vscode",       "スクリプトを VS Code で開く",   (*) => QM_OpenScriptInCode(), "code ahk")
        this.Add("A", "N", "notepad",      "メモ帳",                        (*) => Run("notepad.exe"), "memo")
        this.Add("A", "K", "calc",         "電卓",                          (*) => Run("calc.exe"), "dentaku")
        this.Add("A", "E", "winsettings",  "Windows の設定",                (*) => Run("ms-settings:"), "settei")

        ;--- VS Code（折りたたみ・展開）-----------------------------------------
        this.Add("V", "T", "fold-toggle",      "折りたたみ／展開を切り替え", (*) => QM_VSCodeChord("^l"), "vscode tatami tenkai")
        this.Add("V", "Q", "fold-recursive",   "再帰的に折りたたむ",         (*) => QM_VSCodeChord("^[", 100), "vscode tatami")
        this.Add("V", "R", "unfold-recursive", "再帰的に展開",               (*) => QM_VSCodeChord("^]", 100), "vscode tenkai expand")
        this.Add("V", "W", "fold-all",         "すべて折りたたむ",           (*) => QM_VSCodeChord("^0"), "vscode tatami")
        this.Add("V", "E", "unfold-all",       "すべて展開",                 (*) => QM_VSCodeChord("^j"), "vscode tenkai expand")

        ;--- PowerPoint（Lib\powerpoint_pack.ahk。PowerPoint が前面にあるときだけ動く）---------
        this.Add("P", "F", "ppt-edit-mode", "図形編集モード（大きさ・移動・回転）", (*) => Ppt_EditStart(), "powerpoint slide shape edit zukei henshu")
        if PPT_SHOW_LEGACY {
        this.Add("P", "L", "ppt-left",      "左にそろえる",                  (*) => Ppt_Align("left"), "powerpoint slide align seiretsu")
        this.Add("P", "R", "ppt-right",     "右にそろえる",                  (*) => Ppt_Align("right"), "powerpoint slide align seiretsu")
        this.Add("P", "T", "ppt-top",       "上にそろえる",                  (*) => Ppt_Align("top"), "powerpoint slide align seiretsu")
        this.Add("P", "B", "ppt-bottom",    "下にそろえる",                  (*) => Ppt_Align("bottom"), "powerpoint slide align seiretsu")
        this.Add("P", "C", "ppt-center",    "左右の中央にそろえる",          (*) => Ppt_Align("center"), "powerpoint slide align seiretsu")
        this.Add("P", "M", "ppt-middle",    "上下の中央にそろえる",          (*) => Ppt_Align("middle"), "powerpoint slide align seiretsu")
        this.Add("P", "D", "ppt-dist-h",    "横に等間隔に並べる",            (*) => Ppt_Distribute("h"), "powerpoint slide distribute toukankaku")
        this.Add("P", "E", "ppt-dist-v",    "縦に等間隔に並べる",            (*) => Ppt_Distribute("v"), "powerpoint slide distribute toukankaku")
        this.Add("P", "W", "ppt-same-w",    "幅を最初の図形にそろえる",      (*) => Ppt_MatchSize("w"), "powerpoint slide size haba")
        this.Add("P", "H", "ppt-same-h",    "高さを最初の図形にそろえる",    (*) => Ppt_MatchSize("h"), "powerpoint slide size takasa")
        this.Add("P", "S", "ppt-same-size", "幅と高さを最初の図形にそろえる", (*) => Ppt_MatchSize("wh"), "powerpoint slide size ookisa")
        this.Add("P", "X", "ppt-swap",      "2 つの図形の位置を入れ替え",    (*) => Ppt_Swap(), "powerpoint slide swap exchange irekae")
        this.Add("P", "I", "ppt-paste-pic", "画像として貼り付け",            (*) => Ppt_PastePicture(), "powerpoint slide paste picture image gazou")
        }

        this._BuildGui()
        this._BuildMenuGui()
    }

    ; 機能を 1 つ登録する
    static Add(catKey, key, tag, name, fn, keywords := "") {
        catName := this._CatName(catKey)
        it := {cat: catName, catKey: catKey, key: key, tag: StrLower(tag), name: name, fn: fn}
        it.hint := catKey "→" key
        it.hay  := StrLower(tag " " name " " catName " " keywords)
        this.Items.Push(it)
    }

    static _CatName(catKey) {
        for c in this.Cats
            if (c.key = catKey)
                return c.name
        return ""
    }

    ;=== 共通 ===================================================================

    ; パレット・メニュー・記号メニューのどれかがアクティブか（Caps で閉じるホットキーの条件）
    static _IsOpen() {
        if QM_SymbolMenu.IsActive()
            return true
        if !this._inited
            return false
        return WinActive("ahk_id " this._gui.Hwnd) || this._menu.IsActive()
    }

    ; すべて閉じて元のウィンドウに戻る
    static CloseAll() {
        QM_SymbolMenu.Close()
        if !this._inited
            return
        this._menu.Close()
        if WinExist("ahk_id " this._gui.Hwnd) {                 ; 表示中のみ（非表示のウィンドウは見つからない）
            this._gui.Hide()
            this._RestoreTarget()
        }
    }

    static _RestoreTarget() {
        if (this._target && WinExist("ahk_id " this._target))
            try WinActivate("ahk_id " this._target)
    }

    ; 機能を実行する（元のウィンドウに戻してから）
    static _Exec(it) {
        QM_BackToTarget(this._target, 50)
        try it.fn.Call()
        catch as e
            UI_Tip("実行できませんでした：" e.Message)
    }

    ;=== コマンドパレット =======================================================
    static _HINT := "英字：英名でジャンプ　↑↓：選択　Enter：実行　Esc / Caps：閉じる"

    static _BuildGui() {
        g := Gui("+AlwaysOnTop -Caption +Border +ToolWindow", "QuickPalette")
        g.SetFont("s11", "Yu Gothic UI")
        g.MarginX := 10, g.MarginY := 10
        this._gui  := g
        this._edit := g.AddEdit("w600")
        this._lv   := g.AddListView("w600 r14 -Multi -Hdr NoSortHdr +LV0x10000", ["英名", "機能", "カテゴリ", "キー"])
        this._lv.ModifyCol(1, 120), this._lv.ModifyCol(2, 290), this._lv.ModifyCol(3, 120), this._lv.ModifyCol(4, 50)
        g.SetFont("s9 c808080")
        this._foot := g.AddText("w600", this._HINT)

        this._edit.OnEvent("Change", (*) => this._Filter())
        this._lv.OnEvent("DoubleClick", (*) => this._Run())
        g.OnEvent("Escape", (*) => this.CloseAll())
        g.OnEvent("Close",  (*) => this.CloseAll())

        OnMessage(0x0100, ObjBindMethod(this, "_OnKeyDown"))   ; WM_KEYDOWN
        OnMessage(0x0102, ObjBindMethod(this, "_OnChar"))      ; WM_CHAR（Enter などのビープ音を防ぐ）
        OnMessage(0x0006, ObjBindMethod(this, "_OnActivate"))  ; WM_ACTIVATE（ほかを選んだら閉じる）
    }

    ; target を指定すると、その画面を「元のウィンドウ」として扱う（メニューから開くとき用）
    static Show(target := 0) {
        this._Init()
        this._menu.Close(false)
        this._target := target || WinExist("A")
        this._edit.Value := ""
        this._Filter()

        ; 元のウィンドウがあるモニターの、上から 1/5 の位置に表示
        mon := MonitorGetPrimary()
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this._target)
            mon := UI_MonitorFromPoint(wx + ww // 2, wy + wh // 2)
        }
        MonitorGetWorkArea(mon, &l, &t, &r, &b)
        this._gui.Show("Hide AutoSize")
        UI_GetWinSize(this._gui.Hwnd, &gw, &gh)
        this._gui.Show("x" (l + (r - l - gw) // 2) " y" (t + (b - t) // 5))
        this._edit.Focus()
        QM_ImeOff(this._edit.Hwnd)
    }

    ; 全機能を「最近使った順 → 登録順」に並べて返す
    static _SortedItems() {
        cand := []
        for i, it in this.Items
            cand.Push({it: it, s: this._used.Get(it.name, 0), i: i})
        loop cand.Length - 1 {                                   ; 挿入ソート
            j := A_Index + 1, x := cand[j]
            while (j > 1 && (cand[j - 1].s < x.s || (cand[j - 1].s = x.s && cand[j - 1].i > x.i))) {
                cand[j] := cand[j - 1]
                j--
            }
            cand[j] := x
        }
        out := []
        for c in cand
            out.Push(c.it)
        return out
    }

    ; 入力に合わせて一覧を更新する
    static _Filter() {
        q := StrLower(Trim(RegExReplace(this._edit.Value, "[\s　]+", " ")))
        all := this._SortedItems()
        sel := 1

        if (q = "") {
            list := all
            this._foot.Value := this._HINT
        } else {
            jump := 0
            if RegExMatch(q, "^[a-z0-9\-]+$")
                for i, it in all
                    if (SubStr(it.tag, 1, StrLen(q)) = q) {
                        jump := i
                        break
                    }
            if jump {
                list := all, sel := jump
                this._foot.Value := "▶ 英名「" q "…」にジャンプ　　Enter：実行　BS：1 文字戻す"
            } else {
                tokens := StrSplit(q, " ")
                list := []
                for it in all {
                    ok := true
                    for tk in tokens
                        if !InStr(it.hay, tk) {
                            ok := false
                            break
                        }
                    if ok
                        list.Push(it)
                }
                this._foot.Value := list.Length
                    ? "🔍 「" q "」で絞り込み：" list.Length " 件"
                    : "🔍 「" q "」に当てはまる機能がありません"
            }
        }

        this._lv.Opt("-Redraw")
        this._lv.Delete()
        this._view := list
        for it in list
            this._lv.Add(, it.tag, it.name, it.cat, it.hint)
        this._lv.Opt("+Redraw")
        if list.Length
            this._lv.Modify(sel, "Select Focus Vis")
    }

    static _Move(d) {
        n := this._lv.GetCount()
        if !n
            return
        cur := this._lv.GetNext(0) || 1
        new := cur + d
        if (Abs(d) = 1)                                          ; 1 行移動は端で反対側へ
            new := Mod(new - 1 + n, n) + 1
        else
            new := Max(1, Min(n, new))
        this._lv.Modify(0, "-Select -Focus")
        this._lv.Modify(new, "Select Focus Vis")
    }

    static _Run() {
        row := this._lv.GetNext(0)
        if !row
            return
        it := this._view[row]
        this._used[it.name] := A_TickCount
        this._gui.Hide()
        SetTimer(() => this._Exec(it), -1)                      ; メッセージ処理の外で実行
    }

    static _OnKeyDown(wParam, lParam, msg, hwnd) {
        if !this._inited || (hwnd != this._edit.Hwnd && hwnd != this._lv.Hwnd)
            return
        ctrl := GetKeyState("Ctrl")
        switch wParam {
            case 0x26: this._Move(-1)                            ; ↑
            case 0x28: this._Move(1)                             ; ↓
            case 0x21: this._Move(-10)                           ; PgUp
            case 0x22: this._Move(10)                            ; PgDn
            case 0x0D: this._Run()                               ; Enter
            case 0x1B: this.CloseAll()                           ; Esc
            case 0x4A, 0x4E:                                     ; Ctrl+J / Ctrl+N
                if !ctrl
                    return
                this._Move(1)
            case 0x4B, 0x50:                                     ; Ctrl+K / Ctrl+P
                if !ctrl
                    return
                this._Move(-1)
            default:
                return
        }
        return 0
    }

    static _OnChar(wParam, lParam, msg, hwnd) {
        if (this._inited && hwnd = this._edit.Hwnd)
            for c in [10, 11, 13, 14, 16, 27]                    ; Ctrl+J/K/N/P、Enter、Esc の文字入力を捨てる
                if (wParam = c)
                    return 0
    }

    static _OnActivate(wParam, lParam, msg, hwnd) {
        if (this._inited && hwnd = this._gui.Hwnd && (wParam & 0xFFFF) = 0)
            SetTimer(() => this._gui.Hide(), -1)
    }

    ;=== クイックメニュー =======================================================
    static _BuildMenuGui() {
        this._menu := QM_ListPopup("QuickMenu", 300, ["キー", "機能"], [44, 250], 8
            , "英字：選択　BS / ←：戻る　Esc / Caps：閉じる"
            , ObjBindMethod(this, "_OnMenuKey"), ObjBindMethod(this, "_MenuPick"))
    }

    ; level を指定すると、そのカテゴリを開いた状態で表示する
    static ShowMenu(level := "") {
        this._Init()
        if this._menu.isOpen {                                   ; 開いていれば閉じる（切り替え）
            this._menu.Close()
            return
        }
        this._target := this._menu.target := WinExist("A")
        this._mLevel := (this._CatName(level) != "") ? level : ""
        this._MenuRender()
        this._menu.Open()
    }

    ; 現在の階層の一覧を表示する
    static _MenuRender() {
        lv := this._menu.lv
        lv.Opt("-Redraw")
        lv.Delete()
        this._mView := []
        if (this._mLevel = "") {
            this._menu.title.Value := "クイックメニュー"
            for c in this.Cats {
                lv.Add(, c.key, c.name "  ▸")
                this._mView.Push({type: "cat", key: c.key})
            }
            lv.Add(, "/", "コマンドパレットを開く")
            this._mView.Push({type: "palette", key: "/"})
        } else {
            this._menu.title.Value := "クイックメニュー ▸ " this._CatName(this._mLevel)
            for it in this.Items
                if (it.catKey = this._mLevel) {
                    lv.Add(, it.key, it.name)
                    this._mView.Push({type: "item", key: it.key, it: it})
                }
        }
        lv.Opt("+Redraw")
        lv.Modify(1, "Select Focus")
        this._menu.Fit(this._mView.Length)
    }

    ; 行を選んだとき
    static _MenuPick(row) {
        if (row < 1 || row > this._mView.Length)
            return
        v := this._mView[row]
        switch v.type {
            case "cat":
                this._mLevel := v.key
                this._MenuRender()
                this._menu.ResetTimeout()
            case "palette":
                target := this._target
                this._menu.Close(false)
                SetTimer(() => this.Show(target), -1)
            case "item":
                it := v.it
                this._used[it.name] := A_TickCount
                this._menu.Close(false)
                SetTimer(() => this._Exec(it), -1)
        }
    }

    ; Esc・Enter・↑↓ 以外のキー（その 3 つは QM_ListPopup が受ける）。一覧の既定の動きを止めるときは 0 を返す
    static _OnMenuKey(vk) {
        lv := this._menu.lv
        switch vk {
            case 0x08, 0x25:                                     ; BS / ←：カテゴリ一覧に戻る
                if (this._mLevel != "") {
                    this._mLevel := ""
                    this._MenuRender()
                }
                return 0
            case 0x27:                                           ; →：カテゴリに入る
                row := lv.GetNext(0)
                if (row && this._mView[row].type = "cat")
                    this._MenuPick(row)
                return 0
        }

        ; 英数字・/ ・; ：該当する行を実行（key は空白区切りで複数指定できる）
        ch := ""
        if ((vk >= 0x41 && vk <= 0x5A) || (vk >= 0x30 && vk <= 0x39))
            ch := Chr(vk)
        else if (vk = 0xBF)
            ch := "/"
        else if (vk >= 0xBA && vk <= 0xBB && DllCall("MapVirtualKey", "UInt", vk, "UInt", 2, "UInt") = Ord(";"))
            ch := ";"                                         ; JIS は 0xBB、US は 0xBA
        if (ch != "") {
            hits := []
            for i, v in this._mView
                if (InStr(" " v.key " ", " " ch " "))
                    hits.Push(i)
            if (hits.Length = 1)
                this._MenuPick(hits[1])
            else if (hits.Length > 1) {                          ; 同じキーが複数：押すたびに次の候補を選択（Enter で実行）
                cur := lv.GetNext(0), next := hits[1]
                for i in hits
                    if (i > cur) {
                        next := i
                        break
                    }
                this._menu.Select(next)
            }
            return 0                                             ; 該当なしは無視
        }
    }
}


;==============================================================================
; QM_SymbolMenu : 記号を一覧から選んで入力する
;==============================================================================
class QM_SymbolMenu {
    ;--- 記号の一覧（表示順）----------------------------------------------------
    ; key：押す英字 / sym：入力する記号（半角）/ en：英語名（key の文字を大文字で強調）/ ja：読み
    static Symbols := [
        {key: "E", sym: "!",  en: "Exclamation",          ja: "エクスクラメーション（感嘆符）"},
        {key: "Q", sym: "?",  en: "Question",             ja: "クエスチョン（疑問符）"},
        {key: "A", sym: "@",  en: "At sign",              ja: "アットマーク"},
        {key: "H", sym: "#",  en: "Hash",                 ja: "ハッシュ（シャープ）"},
        {key: "D", sym: "$",  en: "Dollar",               ja: "ドル"},
        {key: "R", sym: "%",  en: "peRcent",              ja: "パーセント"},
        {key: "N", sym: "&",  en: "ampersaNd（and）",     ja: "アンパサンド"},
        {key: "C", sym: "^",  en: "Caret",                ja: "キャレット"},
        {key: "T", sym: "~",  en: "Tilde",                ja: "チルダ"},
        {key: "B", sym: "\",  en: "Backslash",            ja: "バックスラッシュ（円記号）"},
        {key: "V", sym: "|",  en: "Vertical bar（pipe）", ja: "縦棒（パイプ）"},
        {key: "G", sym: "``", en: "Grave accent",         ja: "バッククォート"},
        {key: "P", sym: "+",  en: "Plus",                 ja: "プラス"},
        {key: "M", sym: "-",  en: "Minus",                ja: "マイナス（ハイフン）"},
        {key: "X", sym: "*",  en: "asterisk（×）",       ja: "アスタリスク"},
        {key: "S", sym: "/",  en: "Slash",                ja: "スラッシュ"}]

    ; 全角で入力するときに、標準の全角文字（！→！ のように +0xFEE0）以外を使いたい記号
    ;   例：Map("\", "￥", "-", "ー")  … 円記号や長音記号にしたい場合
    static FULL_OVERRIDE := Map()

    ;--- 内部状態（※メソッド名と大文字小文字違いで重ならない名前にすること）--------
    static _p := 0, _target := 0, _full := false             ; _p：画面（QM_ListPopup。初めて開くときに作る）

    ; 表示する（開いていれば閉じる）
    static Show() {
        if (this._p && this._p.isOpen) {
            this._p.Close()
            return
        }
        this._target := WinExist("A")
        this._full := QM_TargetImeIsFullWidth(this._target)     ; メニューが前面に出る前に調べる
        this._Build()
        this._p.target := this._target
        this._Refresh()
        this._p.Select(1)
        this._p.Open()
    }

    static IsActive() => this._p && this._p.IsActive()

    ; 閉じる（restore = true なら元のウィンドウに戻る）
    static Close(restore := true) {
        if this._p
            this._p.Close(restore)
    }

    ; 入力する文字（全角モードなら全角に変換）
    static _Char(sym) {
        if !this._full
            return sym
        if this.FULL_OVERRIDE.Has(sym)
            return this.FULL_OVERRIDE[sym]
        return QM_ToFullAscii(sym)
    }

    static _Build() {
        if this._p
            return
        p := QM_ListPopup("QuickSymbol", 460, ["キー", "記号", "英語名", "読み"], [44, 44, 170, 196], 16
            , "英字：入力　Space：全角／半角を切り替え　↑↓ + Enter：選んで入力　Esc / Caps：閉じる"
            , ObjBindMethod(this, "_OnKey"), ObjBindMethod(this, "_Pick"))
        for s in this.Symbols
            p.lv.Add(, s.key, s.sym, s.en, s.ja)
        p.Fit(this.Symbols.Length)
        this._p := p
    }

    ; タイトルと「記号」列を、全角／半角に合わせて書き換える
    static _Refresh() {
        this._p.title.Value := "記号メニュー　［" (this._full ? "全角" : "半角") "で入力］"
        for i, s in this.Symbols
            this._p.lv.Modify(i, , , this._Char(s.sym))
    }

    ; 記号を入力する
    static _Pick(row) {
        if (row < 1 || row > this.Symbols.Length)
            return
        ch := this._Char(this.Symbols[row].sym)
        this.Close(false)
        SetTimer(() => this._Type(ch), -1)
    }

    static _Type(ch) {
        QM_BackToTarget(this._target, 30)
        SendText(ch)                                             ; 文字をそのまま入力（キー配列・Shift の影響を受けない）
        LastInput_NoteText(ch)                                   ; 「直前の 1 文字」に覚える（全角・半角はこの形のまま）
    }

    ; Esc・Enter・↑↓ 以外のキー（その 3 つは QM_ListPopup が受ける）。一覧の既定の動きを止めるときは 0 を返す
    static _OnKey(vk) {
        if (vk = 0x20) {                                         ; Space：全角／半角を切り替え
            this._full := !this._full
            this._Refresh()
            return 0
        }
        if (vk >= 0x41 && vk <= 0x5A) {                          ; 英字：該当する記号を入力
            ch := Chr(vk)
            for i, s in this.Symbols
                if (s.key = ch) {
                    this._Pick(i)
                    break
                }
            return 0                                             ; 該当なしは無視
        }
    }
}


;==============================================================================
; QM_ListPopup : 文字カーソルの近くに出す小さな一覧（クイックメニューと記号メニューが使う）
;   タイトル・一覧・説明の 3 段。キーは一覧が受ける（Esc：閉じる、Enter：選んでいる行、↑↓：行の移動）。
;   ほかのキーは onKey(vk) に渡す（0 を返すと、一覧の既定の動き（頭文字検索・ビープ音）を止める）。
;   閉じ方：Esc、ほかの場所をクリック／Alt+Tab、一定時間操作しない（QuickPalette.MENU_TIMEOUT_MS）、Close()。
;   閉じたら target（開く前にアクティブだったウィンドウ）に戻る。使う側が開く前に入れる。
;==============================================================================
class QM_ListPopup {
    ; name：ウィンドウ名　width：幅　cols / colWidths：一覧の列と幅　rows：一覧の行数（Fit で合わせ直せる）
    ; foot：下の説明　onKey(vk)：Esc・Enter・↑↓ 以外のキー　onPick(row)：行の決定（Enter・クリック）
    __New(name, width, cols, colWidths, rows, foot, onKey, onPick) {
        g := Gui("+AlwaysOnTop -Caption +Border +ToolWindow", name)
        g.MarginX := 8, g.MarginY := 6
        g.SetFont("s9 c808080", "Yu Gothic UI")
        this.title := g.AddText("w" width, "")
        g.SetFont("s11 cDefault")
        this.lv := g.AddListView("w" width " r" rows " -Multi -Hdr NoSortHdr +LV0x10000 -E0x200", cols)
        for i, w in colWidths
            this.lv.ModifyCol(i, w)
        g.SetFont("s9 c808080")
        this.foot := g.AddText("w" width, foot)
        this.gui := g
        this.isOpen := false
        this.target := 0
        this.onKey := onKey, this.onPick := onPick
        this.timeoutFn := ObjBindMethod(this, "Close")

        this.lv.OnEvent("Click", (ctrl, row) => (row ? onPick(row) : 0))
        g.OnEvent("Escape", (*) => this.Close())
        g.OnEvent("Close",  (*) => this.Close())
        OnMessage(0x0100, ObjBindMethod(this, "_OnKeyDown"))   ; WM_KEYDOWN
        OnMessage(0x0102, ObjBindMethod(this, "_OnChar"))      ; WM_CHAR（Enter などのビープ音を防ぐ）
        OnMessage(0x0006, ObjBindMethod(this, "_OnActivate"))  ; WM_ACTIVATE（ほかを選んだら閉じる）
    }

    ; 文字カーソルの下（取れなければマウスの位置）に出す。中身は先に用意しておく
    Open() {
        UI_PopupPos(&x, &y)
        this.gui.Show("Hide AutoSize")
        UI_ClampToMonitor(this.gui.Hwnd, &x, &y)
        this.gui.Show("x" x " y" y)
        this.isOpen := true
        this.lv.Focus()
        QM_ImeOff(this.lv.Hwnd)
        this.ResetTimeout()
    }

    ; 閉じる（restore = true なら元のウィンドウに戻る）
    Close(restore := true) {
        if !this.isOpen
            return
        this.isOpen := false                                     ; 先に下ろす（非アクティブ化の通知で二重に閉じないように）
        SetTimer(this.timeoutFn, 0)
        this.gui.Hide()
        if (restore && this.target && WinExist("ahk_id " this.target))
            try WinActivate("ahk_id " this.target)
    }

    IsActive() => this.isOpen && WinActive("ahk_id " this.gui.Hwnd)

    ; 一覧の高さを n 行に合わせる（表示中なら、位置はそのままで大きさだけ合わせる）
    Fit(n) {
        UI_FitListView(this.lv, n, this.foot)
        if this.isOpen
            this.gui.Show("AutoSize")
    }

    ResetTimeout() {
        if (QuickPalette.MENU_TIMEOUT_MS > 0)
            SetTimer(this.timeoutFn, -QuickPalette.MENU_TIMEOUT_MS)
    }

    ; 行 row を選んだ状態にする
    Select(row) {
        this.lv.Modify(0, "-Select -Focus")
        this.lv.Modify(row, "Select Focus Vis")
    }

    _OnKeyDown(wParam, lParam, msg, hwnd) {
        if !this.isOpen || hwnd != this.lv.Hwnd
            return
        vk := UI_RealVk(wParam, lParam)
        this.ResetTimeout()
        switch vk {
            case 0x1B:                                           ; Esc：閉じる
                this.Close()
                return 0
            case 0x0D:                                           ; Enter：選んでいる行
                this.onPick.Call(this.lv.GetNext(0))
                return 0
            case 0x26, 0x28:                                     ; ↑↓：通常の行移動
                return
        }
        return this.onKey.Call(vk)
    }

    _OnChar(wParam, lParam, msg, hwnd) {
        if (hwnd = this.lv.Hwnd)
            return 0                                             ; 一覧の頭文字検索とビープ音を止める
    }

    _OnActivate(wParam, lParam, msg, hwnd) {
        if (this.isOpen && hwnd = this.gui.Hwnd && (wParam & 0xFFFF) = 0)
            SetTimer(() => this.Close(false), -1)               ; ほかの場所をクリック／Alt+Tab で閉じる
    }
}

; メニューを開く前のウィンドウを前面に戻し（最大 0.5 秒待つ）、sleepMs 待つ。メニューから実行する操作が、元のウィンドウに届くように
QM_BackToTarget(target, sleepMs) {
    if (target && WinExist("ahk_id " target)) {
        try WinActivate("ahk_id " target)
        try WinWaitActive("ahk_id " target, , 0.5)
    }
    Sleep(sleepMs)
}


;==============================================================================
; 呼び出し用ラッパー
;==============================================================================
QuickPalette_Show()  => QuickPalette.Show()
QuickMenu_Show()     => QuickPalette.ShowMenu()
QM_DesktopMenu_Show() => QuickPalette.ShowMenu("D")
QM_DateMenu_Show()    => QuickPalette.ShowMenu("N")
QM_CaptureMenu_Show() => QuickPalette.ShowMenu("C")
; 記号メニューの見た目："tooltip"（ツールチップ。キーを InputHook で受ける。軽い。Lib\symbol_quick.ahk）/ "window"（一覧の小窓。矢印 + Enter でも選べる）
QM_SYMBOL_UI := "tooltip"
QM_SymbolMenu_Show() => (QM_SYMBOL_UI = "window") ? QM_SymbolMenu.Show() : QM_SymbolQuick_Show()

;==============================================================================
; 開いているときだけ有効なホットキー
;==============================================================================
#HotIf QuickPalette._IsOpen()
sc03A:: QuickPalette.CloseAll()                                  ; Caps：閉じる
#HotIf
