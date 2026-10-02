#Requires AutoHotkey v2.0
;==============================================================================
; quick_menu.ahk
; QuickPalette : 便利機能をまとめて呼び出すランチャー（AutoHotkey v2）
;------------------------------------------------------------------------------
; 【3つの呼び出し方】
; (1) コマンドパレット（QuickPalette_Show）… Caps → j を想定
;     機能の一覧と入力欄を表示する。各機能には英語の短い名前（英名）が付いており、
;     一覧の先頭の列に表示している。
;       ・半角英字を打つ … 英名がその文字で始まる機能へジャンプする
;                          例：u → upper（大文字に）、cl → clipboard、sy → symbols
;                          続けて打つほど絞れる。BS で 1 文字戻す。
;       ・英名に当てはまらない入力 … 日本語名・キーワードで一覧を絞り込む
;       ・↑↓ または Ctrl+J / Ctrl+K … 選択を移動
;       ・Enter / ダブルクリック        … 実行
;
; (2) クイックメニュー（QuickMenu_Show）… Caps → k を想定
;     英字 1 文字でカテゴリを選び、もう 1 文字で機能を実行する（2 打鍵）。
;       例：T → U … 選択中の文字を大文字に
;           I → K … 記号メニューを開く
;       ・BS / ← … カテゴリ一覧に戻る
;
; (3) 記号メニュー（QM_SymbolMenu_Show）（2026/09/30 追加）
;     記号の一覧を表示し、英字 1 文字でその記号を入力する。
;     キーは記号の英語名の頭文字（重なるものは英語名の中の目立つ文字）。
;       E ! Exclamation     H # Hash           D $ Dollar        R % peRcent
;       N & ampersaNd(and)  C ^ Caret          T ~ Tilde         B \ Backslash
;       V | Vertical bar    A @ At sign        G ` Grave accent  Q ? Question
;       P + Plus            M - Minus          X * asterisk(×)   S / Slash
;     ・↑↓ + Enter、マウスのクリックでも選べる
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
;==============================================================================

class QuickPalette {
    ;--- 設定 -----------------------------------------------------------------
    static MENU_TIMEOUT_MS := 15000  ; 操作がないとき自動で閉じるまでの時間 [ms]（0 で無効）

    ;--- カテゴリ（メニューの表示順）--------------------------------------------
    static Cats := [
        {key: "T", name: "テキスト変換"},
        {key: "I", name: "挿入"},
        {key: "W", name: "ウィンドウ"},
        {key: "D", name: "仮想デスクトップ"},
        {key: "G", name: "検索・翻訳"},
        {key: "S", name: "システム"},
        {key: "A", name: "アプリ・フォルダ"},
        {key: "V", name: "VS Code"},
        {key: "F", name: "Fn キー"},
        {key: "H", name: "Shift + Fn キー"},
        {key: "C", name: "Ctrl + Fn キー"},
        {key: "X", name: "Ctrl + Shift + Fn キー"}]

    static Items := []
    static _inited := false
    static _used   := Map()     ; 表示名 → 最後に使った時刻（最近使った順の並べ替え用）
    static _view   := []        ; パレットの ListView の行番号 → 項目
    static _target := 0         ; パレット／メニューを開く前にアクティブだったウィンドウ

    ; クイックメニューの状態
    static _mOpen  := false     ; 表示中か
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
        this.Add("I", "D", "date",         "日付（yyyy/MM/dd）",            (*) => QM_InsertTime("yyyy/MM/dd"), "hiduke")
        this.Add("I", "W", "dateweek",     "日付と曜日（yyyy/MM/dd(ddd)）", (*) => QM_InsertTime("yyyy/MM/dd(ddd)"), "hiduke youbi")
        this.Add("I", "N", "datenum",      "日付（yyyyMMdd）",              (*) => QM_InsertTime("yyyyMMdd"), "hiduke filename")
        this.Add("I", "T", "time",         "時刻（HH:mm）",                 (*) => QM_InsertTime("HH:mm"), "jikoku")
        this.Add("I", "S", "datetime",     "日時（yyyy/MM/dd HH:mm）",      (*) => QM_InsertTime("yyyy/MM/dd HH:mm"), "nichiji")

        ;--- ウィンドウ ---------------------------------------------------------
        this.Add("W", "T", "topmost",      "常に最前面を切り替え",          (*) => QM_ToggleTopmost(), "saizenmen")
        this.Add("W", "R", "opacity",      "半透明を切り替え",              (*) => QM_ToggleTransparent(), "transparent toumei")
        this.Add("W", "C", "center",       "画面の中央へ移動",              (*) => QM_CenterWindow(), "chuuou")
        this.Add("W", "I", "wininfo",      "ウィンドウ情報をコピー",        (*) => QM_CopyWindowInfo(), "ahk_exe class")

        ;--- 仮想デスクトップ ---------------------------------------------------
        this.Add("D", "C", "desk-new",     "新しいデスクトップを作成",      (*) => QM_DesktopNew(), "virtual desktop create sakusei")
        this.Add("D", "X", "desk-close",   "今のデスクトップを閉じる",      (*) => QM_DesktopClose(), "virtual desktop delete sakujo")
        this.Add("D", "N", "desk-next",    "次（右）のデスクトップへ",      (*) => QM_DesktopStep(1), "virtual desktop switch kirikae")
        this.Add("D", "P", "desk-prev",    "前（左）のデスクトップへ",      (*) => QM_DesktopStep(-1), "virtual desktop switch kirikae")
        this.Add("D", "W", "carry-next",   "ウィンドウを連れて次へ",        (*) => QM_DesktopStep(1, true), "virtual desktop move window idou")
        this.Add("D", "Q", "carry-prev",   "ウィンドウを連れて前へ",        (*) => QM_DesktopStep(-1, true), "virtual desktop move window idou")
        this.Add("D", "M", "carry-new",    "新しいデスクトップへウィンドウを移動", (*) => QM_DesktopNew(true), "virtual desktop move window idou")
        this.Add("D", "T", "taskview",     "タスクビュー（Win+Tab）",       (*) => Send("#{Tab}"), "virtual desktop ichiran")
        this.Add("D", "I", "desk-info",    "今のデスクトップ番号を表示",    (*) => QM_DesktopInfo(), "virtual desktop bangou")
        ; 番号を指定して切り替え（今は使わないので非表示。使うときは次の 2 行を有効にする）
        ; loop 9
        ;     this.Add("D", String(A_Index), "desk-" A_Index, "デスクトップ " A_Index " へ", QM_DesktopGo.Bind(A_Index), "virtual desktop switch kirikae")

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

        ;--- Fn キー（F1〜F12）---------------------------------------------------
        ; キーの配置は oneshot_modifiers.ahk の Fn キー入力モードと同じ
        fnKeys := ["X", "C", "V", "S", "D", "F", "W", "E", "R", "Z", "A", "Q"]
        fnMods := [
            {cat: "F", mod: "",   tag: "",            name: ""},
            {cat: "H", mod: "+",  tag: "shift-",      name: "Shift + "},
            {cat: "C", mod: "^",  tag: "ctrl-",       name: "Ctrl + "},
            {cat: "X", mod: "^+", tag: "ctrl-shift-", name: "Ctrl + Shift + "}]
        for fm in fnMods
            for n, k in fnKeys
                this.Add(fm.cat, k, fm.tag "f" n, fm.name "F" n, SendInput.Bind(fm.mod "{F" n "}"), "fn function")

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
        return WinActive("ahk_id " this._gui.Hwnd)
            || (this._mOpen && WinActive("ahk_id " this._mgui.Hwnd))
    }

    ; すべて閉じて元のウィンドウに戻る
    static CloseAll() {
        QM_SymbolMenu.Close()
        if !this._inited
            return
        if this._mOpen
            this._MenuClose()
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
        if (this._target && WinExist("ahk_id " this._target)) {
            try WinActivate("ahk_id " this._target)
            try WinWaitActive("ahk_id " this._target, , 0.5)
        }
        Sleep(50)
        try it.fn.Call()
        catch as e
            QM_Tip("実行できませんでした：" e.Message)
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
        if this._mOpen
            this._MenuClose(false)
        this._target := target || WinExist("A")
        this._edit.Value := ""
        this._Filter()

        ; 元のウィンドウがあるモニターの、上から 1/5 の位置に表示
        mon := MonitorGetPrimary()
        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this._target)
            mon := QM_MonitorFromPoint(wx + ww // 2, wy + wh // 2)
        }
        MonitorGetWorkArea(mon, &l, &t, &r, &b)
        this._gui.Show("Hide AutoSize")
        QM_GetWinSize(this._gui.Hwnd, &gw, &gh)
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
        g := Gui("+AlwaysOnTop -Caption +Border +ToolWindow", "QuickMenu")
        g.MarginX := 8, g.MarginY := 6
        g.SetFont("s9 c808080", "Yu Gothic UI")
        this._mTitle := g.AddText("w300", "クイックメニュー")
        g.SetFont("s11 cDefault")
        this._mlv := g.AddListView("w300 r8 -Multi -Hdr NoSortHdr +LV0x10000 -E0x200", ["キー", "機能"])
        this._mlv.ModifyCol(1, 44), this._mlv.ModifyCol(2, 250)
        g.SetFont("s9 c808080")
        this._mFoot := g.AddText("w300", "英字：選択　BS / ←：戻る　Esc / Caps：閉じる")
        this._mgui := g

        this._mlv.OnEvent("Click", (ctrl, row) => (row ? this._MenuPick(row) : 0))
        g.OnEvent("Escape", (*) => this._MenuClose())
        g.OnEvent("Close",  (*) => this._MenuClose())
        this._mTimeoutFn := () => this._MenuClose()

        OnMessage(0x0100, ObjBindMethod(this, "_OnMenuKey"))       ; WM_KEYDOWN
        OnMessage(0x0102, ObjBindMethod(this, "_OnMenuChar"))      ; WM_CHAR
        OnMessage(0x0006, ObjBindMethod(this, "_OnMenuActivate"))  ; WM_ACTIVATE
    }

    ; level を指定すると、そのカテゴリを開いた状態で表示する
    static ShowMenu(level := "") {
        this._Init()
        if this._mOpen {                                         ; 開いていれば閉じる（切り替え）
            this._MenuClose()
            return
        }
        this._target := WinExist("A")
        this._mLevel := (this._CatName(level) != "") ? level : ""
        this._MenuRender()

        QM_PopupPos(&x, &y)
        this._mgui.Show("Hide AutoSize")
        QM_ClampToMonitor(this._mgui.Hwnd, &x, &y)
        this._mgui.Show("x" x " y" y)

        this._mOpen := true
        this._mlv.Focus()
        QM_ImeOff(this._mlv.Hwnd)
        this._MenuResetTimeout()
    }

    ; 現在の階層の一覧を表示する
    static _MenuRender() {
        lv := this._mlv
        lv.Opt("-Redraw")
        lv.Delete()
        this._mView := []
        if (this._mLevel = "") {
            this._mTitle.Value := "クイックメニュー"
            for c in this.Cats {
                lv.Add(, c.key, c.name "  ▸")
                this._mView.Push({type: "cat", key: c.key})
            }
            lv.Add(, "/", "コマンドパレットを開く")
            this._mView.Push({type: "palette", key: "/"})
        } else {
            this._mTitle.Value := "クイックメニュー ▸ " this._CatName(this._mLevel)
            for it in this.Items
                if (it.catKey = this._mLevel) {
                    lv.Add(, it.key, it.name)
                    this._mView.Push({type: "item", key: it.key, it: it})
                }
        }
        lv.Opt("+Redraw")
        lv.Modify(1, "Select Focus")

        QM_FitListView(lv, this._mView.Length, this._mFoot)
        if this._mOpen
            this._mgui.Show("AutoSize")                          ; 位置はそのままで大きさだけ合わせる
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
                this._MenuResetTimeout()
            case "palette":
                target := this._target
                this._MenuClose(false)
                SetTimer(() => this.Show(target), -1)
            case "item":
                it := v.it
                this._used[it.name] := A_TickCount
                this._MenuClose(false)
                SetTimer(() => this._Exec(it), -1)
        }
    }

    ; メニューを閉じる（restore = true なら元のウィンドウに戻る）
    static _MenuClose(restore := true) {
        if !this._mOpen
            return
        this._mOpen := false                                     ; 先に下ろす（非アクティブ化の通知で二重に閉じないように）
        SetTimer(this._mTimeoutFn, 0)
        this._mgui.Hide()
        if restore
            this._RestoreTarget()
    }

    static _MenuResetTimeout() {
        if (this.MENU_TIMEOUT_MS > 0)
            SetTimer(this._mTimeoutFn, -this.MENU_TIMEOUT_MS)
    }

    static _OnMenuKey(wParam, lParam, msg, hwnd) {
        if !this._inited || !this._mOpen || hwnd != this._mlv.Hwnd
            return
        vk := QM_RealVk(wParam, lParam)
        this._MenuResetTimeout()

        switch vk {
            case 0x1B:                                           ; Esc：閉じる
                this._MenuClose()
                return 0
            case 0x08, 0x25:                                     ; BS / ←：カテゴリ一覧に戻る
                if (this._mLevel != "") {
                    this._mLevel := ""
                    this._MenuRender()
                }
                return 0
            case 0x0D:                                           ; Enter：選択中の行を実行
                this._MenuPick(this._mlv.GetNext(0))
                return 0
            case 0x27:                                           ; →：カテゴリに入る
                row := this._mlv.GetNext(0)
                if (row && this._mView[row].type = "cat")
                    this._MenuPick(row)
                return 0
            case 0x26, 0x28:                                     ; ↑↓：通常の行移動
                return
        }

        ; 英数字・/ ：該当する行を実行
        ch := ""
        if ((vk >= 0x41 && vk <= 0x5A) || (vk >= 0x30 && vk <= 0x39))
            ch := Chr(vk)
        else if (vk = 0xBF)
            ch := "/"
        if (ch != "") {
            for i, v in this._mView
                if (v.key = ch) {
                    this._MenuPick(i)
                    break
                }
            return 0                                             ; 該当なしは無視
        }
    }

    static _OnMenuChar(wParam, lParam, msg, hwnd) {
        if (this._inited && hwnd = this._mlv.Hwnd)
            return 0                                             ; 一覧の頭文字検索とビープ音を止める
    }

    static _OnMenuActivate(wParam, lParam, msg, hwnd) {
        if (this._inited && this._mOpen && hwnd = this._mgui.Hwnd && (wParam & 0xFFFF) = 0)
            SetTimer(() => this._MenuClose(false), -1)          ; ほかの場所をクリック／Alt+Tab で閉じる
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
    static _win := 0, _isOpen := false, _target := 0, _full := false

    ; 表示する（開いていれば閉じる）
    static Show() {
        if this._isOpen {
            this.Close()
            return
        }
        this._target := WinExist("A")
        this._full := QM_TargetImeIsFullWidth(this._target)     ; メニューが前面に出る前に調べる
        this._Build()
        this._Refresh()

        QM_PopupPos(&x, &y)
        this._win.Show("Hide AutoSize")
        QM_ClampToMonitor(this._win.Hwnd, &x, &y)
        this._win.Show("x" x " y" y)

        this._isOpen := true
        this._lv.Modify(0, "-Select -Focus")
        this._lv.Modify(1, "Select Focus")
        this._lv.Focus()
        QM_ImeOff(this._lv.Hwnd)
        this._ResetTimeout()
    }

    static IsActive() => (this._isOpen && this._win && WinActive("ahk_id " this._win.Hwnd))

    ; 閉じる（restore = true なら元のウィンドウに戻る）
    static Close(restore := true) {
        if !this._isOpen
            return
        this._isOpen := false                                    ; 先に下ろす（非アクティブ化の通知で二重に閉じないように）
        SetTimer(this._timeoutFn, 0)
        this._win.Hide()
        if (restore && this._target && WinExist("ahk_id " this._target))
            try WinActivate("ahk_id " this._target)
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
        if this._win
            return
        g := Gui("+AlwaysOnTop -Caption +Border +ToolWindow", "QuickSymbol")
        g.MarginX := 8, g.MarginY := 6
        g.SetFont("s9 c808080", "Yu Gothic UI")
        this._title := g.AddText("w460", "記号メニュー")
        g.SetFont("s11 cDefault")
        this._lv := g.AddListView("w460 r16 -Multi -Hdr NoSortHdr +LV0x10000 -E0x200", ["キー", "記号", "英語名", "読み"])
        this._lv.ModifyCol(1, 44), this._lv.ModifyCol(2, 44), this._lv.ModifyCol(3, 170), this._lv.ModifyCol(4, 196)
        for s in this.Symbols
            this._lv.Add(, s.key, s.sym, s.en, s.ja)
        g.SetFont("s9 c808080")
        foot := g.AddText("w460", "英字：入力　Space：全角／半角を切り替え　↑↓ + Enter：選んで入力　Esc / Caps：閉じる")
        QM_FitListView(this._lv, this.Symbols.Length, foot)
        this._win := g

        this._lv.OnEvent("Click", (ctrl, row) => (row ? this._Pick(row) : 0))
        g.OnEvent("Escape", (*) => this.Close())
        g.OnEvent("Close",  (*) => this.Close())
        this._timeoutFn := () => this.Close()

        OnMessage(0x0100, ObjBindMethod(this, "_OnKeyDown"))   ; WM_KEYDOWN
        OnMessage(0x0102, ObjBindMethod(this, "_OnChar"))      ; WM_CHAR
        OnMessage(0x0006, ObjBindMethod(this, "_OnActivate"))  ; WM_ACTIVATE
    }

    ; タイトルと「記号」列を、全角／半角に合わせて書き換える
    static _Refresh() {
        this._title.Value := "記号メニュー　［" (this._full ? "全角" : "半角") "で入力］"
        for i, s in this.Symbols
            this._lv.Modify(i, , , this._Char(s.sym))
    }

    static _ResetTimeout() {
        if (QuickPalette.MENU_TIMEOUT_MS > 0)
            SetTimer(this._timeoutFn, -QuickPalette.MENU_TIMEOUT_MS)
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
        if (this._target && WinExist("ahk_id " this._target)) {
            try WinActivate("ahk_id " this._target)
            try WinWaitActive("ahk_id " this._target, , 0.5)
        }
        Sleep(30)
        SendText(ch)                                             ; 文字をそのまま入力（キー配列・Shift の影響を受けない）
    }

    static _OnKeyDown(wParam, lParam, msg, hwnd) {
        if !this._isOpen || !this._win || hwnd != this._lv.Hwnd
            return
        vk := QM_RealVk(wParam, lParam)
        this._ResetTimeout()
        switch vk {
            case 0x1B:                                           ; Esc
                this.Close()
                return 0
            case 0x0D:                                           ; Enter
                this._Pick(this._lv.GetNext(0))
                return 0
            case 0x20:                                           ; Space：全角／半角を切り替え
                this._full := !this._full
                this._Refresh()
                return 0
            case 0x26, 0x28:                                     ; ↑↓：通常の行移動
                return
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

    static _OnChar(wParam, lParam, msg, hwnd) {
        if (this._win && hwnd = this._lv.Hwnd)
            return 0                                             ; 一覧の頭文字検索とビープ音を止める
    }

    static _OnActivate(wParam, lParam, msg, hwnd) {
        if (this._isOpen && this._win && hwnd = this._win.Hwnd && (wParam & 0xFFFF) = 0)
            SetTimer(() => this.Close(false), -1)               ; ほかの場所をクリック／Alt+Tab で閉じる
    }
}


;==============================================================================
; 呼び出し用ラッパー
;==============================================================================
QuickPalette_Show()  => QuickPalette.Show()
QuickMenu_Show()     => QuickPalette.ShowMenu()
QM_DesktopMenu_Show() => QuickPalette.ShowMenu("D")
QM_SymbolMenu_Show() => QM_SymbolMenu.Show()

;==============================================================================
; 開いているときだけ有効なホットキー
;==============================================================================
#HotIf QuickPalette._IsOpen()
sc03A:: QuickPalette.CloseAll()                                  ; Caps：閉じる
#HotIf


;==============================================================================
; 共通処理
;==============================================================================

; ツールチップを一定時間表示する（InputHook 側のツールチップと干渉しないよう 20 番を使用）
QM_Tip(msg, ms := 1500) {
    ToolTip(msg, , , 20)
    SetTimer(() => ToolTip(, , , 20), -ms)
}

; ウィンドウの大きさ（非表示でも取得できる）
QM_GetWinSize(hwnd, &w, &h) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
}

; 小窓の表示位置：文字カーソルの下（取れなければマウスの位置）
QM_PopupPos(&x, &y) {
    CoordMode("Caret", "Screen"), CoordMode("Mouse", "Screen")
    if CaretGetPos(&x, &y)
        y += 24
    else
        MouseGetPos(&x, &y)
}

; 窓が画面からはみ出さないよう x, y を調整する
QM_ClampToMonitor(hwnd, &x, &y) {
    QM_GetWinSize(hwnd, &w, &h)
    MonitorGetWorkArea(QM_MonitorFromPoint(x, y), &l, &t, &r, &b)
    x := Max(l, Min(x, r - w)), y := Max(t, Min(y, b - h))
}

; 一覧の高さを行数に合わせ、その下の文字（foot）を詰める
QM_FitListView(lv, rows, foot) {
    if (lv.GetCount() = 0)
        return
    rc := Buffer(16, 0)
    DllCall("SendMessage", "Ptr", lv.Hwnd, "UInt", 0x100E, "Ptr", 0, "Ptr", rc, "Ptr")  ; LVM_GETITEMRECT
    rowH := Max(NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int"), 16)
    lv.GetPos(, &ly)
    lvH := rowH * rows + 4
    lv.Move(, , , lvH)
    foot.Move(, ly + lvH + 6)
}

; IME が処理中のキー（VK_PROCESSKEY）を、実際のキーに戻す
QM_RealVk(wParam, lParam) {
    if (wParam = 0xE5)
        return DllCall("MapVirtualKey", "UInt", (lParam >> 16) & 0xFF, "UInt", 1, "UInt")
    return wParam
}

; IME ウィンドウへ問い合わせる（相手が応答しなくても 200ms で打ち切る）
QM_ImeQuery(hIme, cmd) {
    r := 0
    ok := DllCall("SendMessageTimeout", "Ptr", hIme, "UInt", 0x0283, "Ptr", cmd, "Ptr", 0
        , "UInt", 0x2, "UInt", 200, "UPtr*", &r, "Ptr")          ; WM_IME_CONTROL, SMTO_ABORTIFHUNG
    return ok ? r : 0
}

; 入力先の IME が「全角で入力する状態」か
;   IME オン かつ 変換モードに NATIVE（かな）または FULLSHAPE（全角）が含まれる → true
;   IME オフ、半角英数                                                          → false
QM_TargetImeIsFullWidth(hwnd) {
    if !hwnd
        return false
    ; フォーカスのある部品（エディタ本体など）を探す
    focus := hwnd
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    size := (A_PtrSize = 8) ? 72 : 48
    gti := Buffer(size, 0), NumPut("UInt", size, gti)
    if DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", gti)
        if (f := NumGet(gti, (A_PtrSize = 8) ? 16 : 12, "Ptr"))  ; hwndFocus
            focus := f
    hIme := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", focus, "Ptr")
    if !hIme
        return false
    if !QM_ImeQuery(hIme, 0x0005)                               ; IMC_GETOPENSTATUS
        return false
    mode := QM_ImeQuery(hIme, 0x0001)                           ; IMC_GETCONVERSIONMODE
    return (mode & 0x9) != 0                                     ; IME_CMODE_NATIVE | IME_CMODE_FULLSHAPE
}

; 半角の英数字・記号を全角に（! → ！、スペース → 全角スペース）
QM_ToFullAscii(s) {
    out := ""
    loop parse s {
        c := Ord(A_LoopField)
        out .= (c >= 0x21 && c <= 0x7E) ? Chr(c + 0xFEE0) : (c = 0x20 ? "　" : A_LoopField)
    }
    return out
}

; 選択中の文字を取得する（クリップボードは元に戻す）
QM_CopySelection(&text) {
    saved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    ok := ClipWait(0.5)
    text := ok ? A_Clipboard : ""
    A_Clipboard := saved
    return (ok && text != "")
}

; 文字を貼り付ける（クリップボードは元に戻す）
QM_Paste(text) {
    saved := ClipboardAll()
    A_Clipboard := text
    Send("^v")
    Sleep(300)
    A_Clipboard := saved
}

; 選択中の文字を fn で変換して置き換える
QM_TransformSelection(fn) {
    if !QM_CopySelection(&text) {
        QM_Tip("文字が選択されていません")
        return
    }
    out := fn(text)
    if (out == text) {
        QM_Tip("変更はありませんでした")
        return
    }
    QM_Paste(out)
}

QM_InsertTime(fmt) => QM_Paste(FormatTime(, fmt))

QM_PastePlain() {
    if (A_Clipboard = "") {
        QM_Tip("クリップボードに文字がありません")
        return
    }
    A_Clipboard := A_Clipboard                                   ; 書式を取り除く
    Send("^v")
}

; IME をオフにする
QM_ImeOff(hwnd) {
    hIme := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if hIme
        DllCall("SendMessage", "Ptr", hIme, "UInt", 0x0283, "Ptr", 0x0006, "Ptr", 0)  ; IMC_SETOPENSTATUS = 0
}

QM_MonitorFromPoint(x, y) {
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

;--- 文字変換 -----------------------------------------------------------------

; LCMapStringEx による変換（ひらがな・カタカナ・全角・半角）
QM_LCMap(s, flags) {
    n := DllCall("LCMapStringEx", "Str", "ja-JP", "UInt", flags, "Str", s, "Int", StrLen(s)
        , "Ptr", 0, "Int", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int")
    if (n <= 0)
        return s
    buf := Buffer(n * 2)
    DllCall("LCMapStringEx", "Str", "ja-JP", "UInt", flags, "Str", s, "Int", StrLen(s)
        , "Ptr", buf, "Int", n, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int")
    return StrGet(buf, n, "UTF-16")
}
QM_ToKatakana(s) => QM_LCMap(s, 0x00200000)                     ; LCMAP_KATAKANA
QM_ToHiragana(s) => QM_LCMap(s, 0x00100000)                     ; LCMAP_HIRAGANA

; 全角の英数字・記号・スペースだけを半角にする（かな・漢字はそのまま）
QM_ToHalfAlnum(s) {
    out := ""
    loop parse s {
        c := Ord(A_LoopField)
        out .= (c >= 0xFF01 && c <= 0xFF5E) ? Chr(c - 0xFEE0) : (c = 0x3000 ? " " : A_LoopField)
    }
    return out
}

; 半角カナだけを全角カナにする（濁点・半濁点も 1 文字にまとめる）
QM_HalfKanaToFull(s) {
    out := "", pos := 1
    while RegExMatch(s, "[\x{FF61}-\x{FF9F}]+", &m, pos) {
        out .= SubStr(s, pos, m.Pos - pos) . QM_LCMap(m[0], 0x00800000)   ; LCMAP_FULLWIDTH
        pos := m.Pos + m.Len
    }
    return out . SubStr(s, pos)
}

; 改行を削除して 1 行に（英単語どうしの間には半角スペースを入れる）
QM_JoinLinesText(s) {
    s := RegExReplace(s, "(?<=[!-~])[ \t]*\R+[ \t]*(?=[!-~])", " ")
    return RegExReplace(s, "[ \t]*\R+[ \t]*")
}

QM_JoinArray(arr) {
    out := ""
    for i, v in arr
        out .= (i > 1 ? "`r`n" : "") v
    return out
}

QM_TrimLines(s) {
    arr := []
    loop parse s, "`n", "`r" {
        t := Trim(A_LoopField, " `t　")
        if (t != "")
            arr.Push(t)
    }
    return QM_JoinArray(arr)
}

QM_Bullets(s) {
    arr := []
    loop parse s, "`n", "`r" {
        t := A_LoopField
        if (Trim(t, " `t　") != "" && SubStr(LTrim(t, " `t　"), 1, 1) != "・")
            t := "・" t
        arr.Push(t)
    }
    return QM_JoinArray(arr)
}

QM_SortLines(s) {
    s := RTrim(StrReplace(s, "`r`n", "`n"), "`n")
    return StrReplace(Sort(s), "`n", "`r`n")
}

QM_DedupLines(s) {
    seen := Map(), arr := []
    loop parse s, "`n", "`r" {
        if !seen.Has(A_LoopField) {
            seen[A_LoopField] := true
            arr.Push(A_LoopField)
        }
    }
    return QM_JoinArray(arr)
}

QM_Unquote(s)          => StrReplace(Trim(s), '"')
QM_BackslashToSlash(s) => StrReplace(s, "\", "/")

QM_CountSelection() {
    if !QM_CopySelection(&t) {
        QM_Tip("文字が選択されていません")
        return
    }
    t := RTrim(StrReplace(t, "`r`n", "`n"), "`n")
    lines   := StrSplit(t, "`n").Length
    all     := StrLen(StrReplace(t, "`n"))
    noSpace := StrLen(RegExReplace(t, "[\s　]"))
    QM_Tip(Format("文字数　　：{}`n空白を除く：{}`n行数　　　：{}", all, noSpace, lines), 4000)
}

;--- 検索・翻訳 ---------------------------------------------------------------
QM_UriEncode(s) {
    buf := Buffer(StrPut(s, "UTF-8"))
    StrPut(s, buf, "UTF-8")
    out := ""
    loop buf.Size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        out .= ((b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
            || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E) ? Chr(b) : Format("%{:02X}", b)
    }
    return out
}

QM_WebSelection(baseUrl) {
    if !QM_CopySelection(&t) {
        QM_Tip("文字が選択されていません")
        return
    }
    Run(baseUrl . QM_UriEncode(Trim(t)))
}

;--- ウィンドウ ---------------------------------------------------------------
QM_ToggleTopmost() {
    WinSetAlwaysOnTop(-1, "A")
    QM_Tip((WinGetExStyle("A") & 0x8) ? "常に最前面：ON" : "常に最前面：OFF")
}

QM_ToggleTransparent() {
    cur := WinGetTransparent("A")
    WinSetTransparent((cur = "") ? 200 : "Off", "A")
    QM_Tip((cur = "") ? "半透明：ON" : "半透明：OFF")
}

QM_CenterWindow() {
    if !(hwnd := WinExist("A"))
        return
    if (WinGetMinMax(hwnd) = 1)
        WinRestore(hwnd)
    WinGetPos(&x, &y, &w, &h, hwnd)
    MonitorGetWorkArea(QM_MonitorFromPoint(x + w // 2, y + h // 2), &l, &t, &r, &b)
    WinMove(l + (r - l - w) // 2, t + (b - t - h) // 2, , , hwnd)
}

QM_CopyWindowInfo() {
    if !WinExist("A")
        return
    text := Format("Title: {}`r`nClass: ahk_class {}`r`nExe:   ahk_exe {}`r`nPath:  {}"
        , WinGetTitle("A"), WinGetClass("A"), WinGetProcessName("A"), WinGetProcessPath("A"))
    A_Clipboard := text
    QM_Tip("ウィンドウ情報をコピーしました`n`n" text, 3000)
}

;--- システム・アプリ ---------------------------------------------------------
QM_ShowClipboard() {
    t := A_Clipboard
    MsgBox((t = "") ? "（文字なし）" : SubStr(t, 1, 2000) (StrLen(t) > 2000 ? "`n…（以下省略）" : "")
        , "クリップボードの内容")
}

QM_DisplayOff() {
    Sleep(500)                                                   ; キーを離した信号で再点灯しないよう待つ
    DllCall("PostMessage", "Ptr", 0xFFFF, "UInt", 0x0112, "Ptr", 0xF170, "Ptr", 2)  ; SC_MONITORPOWER
}

QM_OpenScriptInCode() {
    try Run('code "' A_ScriptDir '"', , "Hide")
    catch
        Run(A_ScriptDir)
}

;--- VS Code ------------------------------------------------------------------
; Ctrl+K に続けて key を送る（VS Code の 2 段階ショートカット）
QM_VSCodeChord(key, waitMs := 200) {
    SendInput("^k")
    Sleep(waitMs)
    SendInput(key)
}

;--- 仮想デスクトップ ---------------------------------------------------------
; 現在の番号と総数をレジストリから読む（現在の番号が分からなければ false）
QM_DesktopState(&cur, &count) {
    key := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"
    cur := 1, count := 1
    ids := ""
    try ids := RegRead(key "\VirtualDesktops", "VirtualDesktopIDs")
    if (StrLen(ids) < 32)                                        ; 一度も追加していないときは値がない
        return true
    count := StrLen(ids) // 32                                   ; GUID 1 個 = 16 バイト = 16 進 32 文字

    curId := ""
    try curId := RegRead(key "\VirtualDesktops", "CurrentVirtualDesktop")          ; Windows 11
    if (curId = "") {                                            ; Windows 10
        sid := 0
        DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId", "UInt"), "UInt*", &sid)
        try curId := RegRead(key "\SessionInfo\" sid "\VirtualDesktops", "CurrentVirtualDesktop")
    }
    loop count
        if (SubStr(ids, (A_Index - 1) * 32 + 1, 32) = curId) {
            cur := A_Index
            return true
        }
    return false
}

QM_DesktopMoveBy(d) {
    keys := (d > 0) ? "^#{Right}" : "^#{Left}"
    loop Abs(d) {
        SendInput(keys)
        Sleep(100)
    }
}

; 隣のデスクトップへ（carry = true ならアクティブなウィンドウも一緒に移動）
QM_DesktopStep(d, carry := false) {
    known := QM_DesktopState(&cur, &count)
    n := cur + d
    if (known && (n < 1 || n > count)) {
        QM_Tip((d > 0) ? "右側にデスクトップはありません" : "左側にデスクトップはありません")
        return
    }
    if carry
        QM_CarryWindow(() => QM_DesktopMoveBy(d))
    else
        QM_DesktopMoveBy(d)
    if known
        QM_Tip("デスクトップ " n " / " count)
}

; 番号を指定して切り替える
QM_DesktopGo(n) {
    if !QM_DesktopState(&cur, &count) {
        QM_Tip("仮想デスクトップの状態を取得できませんでした")
        return
    }
    if (n > count) {
        QM_Tip("デスクトップ " n " はありません（全 " count " 個）")
        return
    }
    if (n != cur)
        QM_DesktopMoveBy(n - cur)
    QM_Tip("デスクトップ " n " / " count)
}

; 新しいデスクトップを右端に作って切り替える（carry = true ならウィンドウも移動）
QM_DesktopNew(carry := false) {
    QM_DesktopState(&cur, &count)
    if carry
        QM_CarryWindow(() => SendInput("^#d"))
    else
        SendInput("^#d")
    QM_Tip("デスクトップを作成しました（" count + 1 " / " count + 1 "）")
}

; 今のデスクトップを閉じる（開いていたウィンドウは隣のデスクトップへ移る）
QM_DesktopClose() {
    if (QM_DesktopState(&cur, &count) && count <= 1) {
        QM_Tip("デスクトップが 1 つしかないため閉じられません")
        return
    }
    SendInput("^#{F4}")
    QM_Tip("デスクトップ " cur " を閉じました（残り " count - 1 " 個）")
}

QM_DesktopInfo() {
    if QM_DesktopState(&cur, &count)
        QM_Tip("現在のデスクトップ：" cur " / " count, 2500)
    else
        QM_Tip("仮想デスクトップの状態を取得できませんでした")
}

; アクティブなウィンドウを隠してから切り替え、切り替え先で表示し直す（表示した側のデスクトップに移る）
QM_CarryWindow(switchFn) {
    hwnd := WinExist("A")
    if (!hwnd || RegExMatch(WinGetClass(hwnd), "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$")) {
        QM_Tip("移動できるウィンドウがありません")
        return
    }
    WinHide(hwnd)
    try {
        Sleep(50)
        switchFn()
        Sleep(250)
    } finally {
        WinShow(hwnd)
        try WinActivate(hwnd)
    }
}
