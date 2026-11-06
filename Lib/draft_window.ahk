#Requires AutoHotkey v2.0
;==============================================================================
; draft_window.ahk
; AI チャットへの指示などを書くための下書きウィンドウ（Caps → m、クイックメニューの P → D）
;   画面は WebView2（Lib\draft_window.html）。ブラウザの入力欄なので、IME の変換中の文字がチャットの入力欄と同じように、その場に出る
;   Enter は改行。Ctrl+Enter で DRAFT_CONFIRM の動き（元のウィンドウへ貼り付け / コピーだけ）、Ctrl+Shift+Enter でもう一方。送信は自分で行う
;   Esc・×：閉じる（内容は残る。次に開くと続きから書ける）。Ctrl+P / Ctrl+N（Ctrl+↑ / Ctrl+↓ も可）：確定した下書きの履歴をさかのぼる
;   書きかけと履歴はメモリ上だけに持つ（ファイルには書かない。スクリプトの再読み込み・終了で消える）
; 呼び出し口は Draft_Show()。窓は開くたびに作り、閉じるたびに壊す（WebView2 は常駐させるとメモリを約 330 MB 使うため。開くときに 1 秒ほどかかる）
; キーは、ホットキーでなくページのキー入力で受ける（入力待ちの Ctrl+キーなど、自分の SendInput で送ったキーにも反応させるため）
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\text_ops.ahk
#Include %A_LineFile%\..\webview2\WebView2.ahk

DRAFT_CONFIRM := "paste"                         ; Ctrl+Enter の動き："paste"（元のウィンドウへ貼り付け）/ "copy"（クリップボードにコピーだけ）
DRAFT_HISTORY_MAX := 30                          ; 覚えておく確定済みの下書きの数

class DraftWin {
    static SEP := Chr(31)                        ; ページから届く文字列の区切り

    static _gui := 0, _wvc := 0, _wv := 0, _msgToken := 0, _navToken := 0
    static _ready := false                       ; ページの読み込みが終わった
    static _open := false                        ; 開いている（読み込み前なら、終わってから中身を渡す）
    static _target := 0                          ; 開く前に前面だったウィンドウ
    static _cur := ""                            ; 書きかけの内容（ページから届いた最新）
    static _hist := []                           ; 確定した下書き（新しい順）

    static IsActive() => this._gui && WinActive("ahk_id " this._gui.Hwnd)

    ; 開く。開いているときに呼ぶと、内容を残して閉じる
    static Show() {
        if this.IsActive() {
            this.RequestClose()
            return
        }
        hwnd := WinExist("A")
        this._target := (hwnd && !(this._gui && hwnd = this._gui.Hwnd)) ? hwnd : 0
        if !this._gui
            UI_Tip("下書きを開いています…", 2000)
        try
            this._Build()
        catch as e {
            UI_Tip("下書きウィンドウを開けませんでした：" e.Message, 4000)
            return
        }
        this._open := true
        this._gui.Show("Hide")
        UI_GetWinSize(this._gui.Hwnd, &w, &h)
        r := this._target ? UI_MonitorRectFromWindow(this._target) : UI_MonitorRectOf(DllCall("MonitorFromPoint", "Int64", 0, "UInt", 1, "Ptr"))
        this._gui.Show("x" (r.L + (r.R - r.L - w) // 2) " y" (r.T + (r.B - r.T - h) // 2))
        try this._wvc.IsVisible := true                              ; 隠したまま作った窓の WebView は、表示にしないと描かれない
        this._wvc.Fill()
        this._wvc.MoveFocus(0)
        if this._ready
            this._Init()
    }

    ; ページに、内容を持って閉じるよう頼む（変換中の文字は確定してから届く）。ページが応答しないときは、そのまま閉じる
    static RequestClose() {
        if (this._ready && this._wv)
            try {
                this._wv.ExecuteScriptAsync("DR_close()")
                return
            }
        this.Hide(true)
    }

    ; 閉じる（書きかけはメモリに残す）。restore = true なら元のウィンドウへ戻る
    static Hide(restore := true) {
        if !this._gui
            return
        this._open := false
        this._gui.Hide()
        this._Destroy()                                             ; 戻る前に壊す（あとで壊すと、前面が元のウィンドウから外れる）
        if restore
            this._Back()
    }

    ; 窓と WebView2 を壊す（メモリを空ける）
    static _Destroy() {
        this._msgToken := 0, this._navToken := 0
        try this._wvc.Close()
        this._wvc := 0, this._wv := 0
        try this._gui.Destroy()
        this._gui := 0, this._ready := false
    }

    ; 確定する。action："paste"（元のウィンドウへ貼り付け）/ "copy"（コピーだけ）。確定した内容は履歴に入れ、書く欄は空にする
    static Confirm(action, text) {
        text := RTrim(text, "`r`n `t")
        if (text = "") {
            UI_Tip("下書きが空です")
            return
        }
        text := StrReplace(StrReplace(text, "`r`n", "`n"), "`n", "`r`n")
        for k in ["Ctrl", "Shift", "Enter"]                          ; 押したままだと、貼り付けの Ctrl+V に混ざる
            KeyWait(k, "T1")
        this._PushHistory(text)
        this._cur := ""
        this.Hide(false)
        if (action = "copy") {
            A_Clipboard := text
            this._Back()
            UI_Tip("コピーしました（" StrLen(StrReplace(text, "`r`n", "`n")) " 文字）")
        } else {
            this._Back(50)
            QM_Paste(text)
        }
    }

    ;--- 内部 -----------------------------------------------------------------
    static _Build() {
        if this._gui
            return
        s := A_ScreenDPI / 96
        g := Gui("+AlwaysOnTop +Resize -DPIScale +MinSize" Round(480 * s) "x" Round(320 * s), "下書き（AI チャットへの指示など）　Ctrl+P / Ctrl+N：履歴")
        g.OnEvent("Size", (o, minMax, w, h) => (minMax != -1 && this._wvc) ? this._wvc.Fill() : 0)
        g.OnEvent("Close", (*) => (this.RequestClose(), true))
        g.OnEvent("Escape", (*) => this.RequestClose())
        g.Show("Hide w" Round(780 * s) " h" Round(560 * s))
        try {
            dataDir := EnvGet("LOCALAPPDATA") "\my_autohotkey_env\webview2"
            wvc := WebView2.CreateControllerAsync(g.Hwnd, 0, dataDir).await2(20000)
        } catch as e {
            g.Destroy()
            throw e
        }
        this._gui := g, this._wvc := wvc, this._wv := wvc.CoreWebView2
        try this._wv.Settings.AreBrowserAcceleratorKeysEnabled := false   ; Ctrl+P（印刷）などの既定の操作を止める
        try this._wv.Settings.AreDevToolsEnabled := false
        wvc.Fill()
        this._msgToken := this._wv.WebMessageReceived((sender, args) => this._OnMessage(args.TryGetWebMessageAsString()))
        this._navToken := this._wv.NavigationCompleted((sender, args) => this._OnNavDone())
        this._wv.Navigate("file:///" StrReplace(A_LineFile "\..\draft_window.html", "\", "/"))
    }

    static _OnNavDone() {
        if this._ready
            return
        this._ready := true
        if this._open
            SetTimer(() => this._Init(), -1)
    }

    ; ページに、書きかけと履歴と、Ctrl+Enter の動きを渡す
    static _Init() {
        h := ""
        for s in this._hist
            h .= (h != "" ? "," : "") DraftWin.Q(s)
        this._wv.ExecuteScriptAsync("DR_open({text:" DraftWin.Q(this._cur) ",main:" DraftWin.Q(DRAFT_CONFIRM) ",hist:[" h "]})")
        if WinActive("ahk_id " this._gui.Hwnd)
            this._wvc.MoveFocus(0)
    }

    ; ページからのメッセージ（confirm / close / save / tip）。重い処理をこの通知の中でしないよう、タイマーに回す
    static _OnMessage(msg) {
        SetTimer(this._Handle.Bind(this, msg), -1)
    }

    static _Handle(msg) {
        p := StrSplit(msg, this.SEP)
        switch p[1] {
            case "ready":
                this._OnNavDone()
            case "confirm":
                if (p.Length >= 3)
                    this.Confirm(p[2], p[3])
            case "close":
                this._cur := p.Length >= 2 ? p[2] : this._cur
                this.Hide(true)
            case "save":
                if (p.Length >= 2)
                    this._cur := p[2]
            case "tip":
                if (p.Length >= 2)
                    UI_Tip(p[2])
        }
    }

    static _PushHistory(text) {
        for i, s in this._hist
            if (s == text) {
                this._hist.RemoveAt(i)                              ; 同じ内容は新しい方に 1 つだけ
                break
            }
        this._hist.InsertAt(1, text)
        while (this._hist.Length > DRAFT_HISTORY_MAX)
            this._hist.Pop()
    }

    ; 元のウィンドウへ戻る（最大 0.5 秒待ち、さらに ms 待つ）
    static _Back(ms := 0) {
        t := this._target
        if (t && WinExist("ahk_id " t)) {
            try WinActivate("ahk_id " t)
            try WinWaitActive("ahk_id " t, , 0.5)
        }
        if ms
            Sleep(ms)
    }

    ; JavaScript の文字列にする
    static Q(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`r")
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`t", "\t")
        s := StrReplace(s, "<", "\u003c")
        return '"' s '"'
    }
}

Draft_Show() => DraftWin.Show()
