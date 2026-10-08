#Requires AutoHotkey v2.0
;==============================================================================
; hint_mode.ahk
; ヒントモード：いまのウィンドウの操作できる部品（ボタン・タブ・入力欄・リスト項目など）に
; 英字のラベルを重ねて表示し、ラベルを打つとその部品をクリックする（Vimium のデスクトップ版）
;   keymap\leader_keys.ahk（Caps → :）から呼ぶ
;
; 操作
;   ラベルの英字     … 1〜2 文字で決定（打つごとに候補が絞られる）
;   変換 ＋ ラベル   … 右クリック（変換を押しながら、最後の 1 文字を打つ）
;   Space ＋ ラベル  … ダブルクリック
;   Tab              … 対象を「ウィンドウ ↔ タスクバー」で切り替え
;   BackSpace        … 1 文字戻す
;   Esc / Caps       … キャンセル（IH_TIMEOUT_SEC 秒操作がなくてもキャンセル）
;
; 仕組み
;   部品の一覧は UI Automation（COM を直接呼ぶ最小実装 HintUIA）で取る。
;   ・取るのは、クリック・選択・切り替え・展開・値の入力ができる部品だけ
;   ・Web ページの中身は対象外（ブラウザの拡張機能を使う想定）。Electron 系は最初の問い合わせで中身が
;     返らないことがあるので、少なければ一度だけ取り直す
;   ・ラベルは、クリックを送る位置に重ねる。位置は部品の中央（横長の部品は左から最大 120px）
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\key_wait.ahk

HINT_ALPHABET := "asdfjklghqweruiop"      ; ラベルに使う文字（打ちやすいものから。多いほどラベルが短くなる）
HINT_LABEL_BG := "FFE066"                 ; ラベルの背景色
HINT_LABEL_FG := "000000"                 ; ラベルの文字色
HINT_LABEL_ALPHA := 140                   ; ラベルの不透明度（0〜255。小さいほど下の文字が見える）
Hint_session := ""                        ; 実行中のモードの状態（動作確認用。実行していなければ ""）

;------------------------------------------------------------------------------
; モード本体
;------------------------------------------------------------------------------
Hint_Show() {
    global Hint_session
    IH_ModeBegin()
    st := {scope: "window", items: [], ov: 0, typed: "", result: "", pick: 0, mode: "left", err: ""
        , mods: Map(), skip: Map(), hook: InputHook("L0")}
    st.idle := _Hint_Finish.Bind(st, "timeout")
    st.hook.KeyOpt("{All}", "NS")                   ; すべてのキーを通知し、アプリには渡さない
    st.hook.OnKeyDown := _Hint_OnKey.Bind(st)
    st.hook.OnKeyUp := _Hint_OnKeyUp.Bind(st)
    for vk in [0x20, 0x1C]                          ; 起動時にすでに押している親指キーは、離すまで無視する
        if GetKeyState(Format("vk{:X}", vk), "P")
            st.skip[vk] := true
    Hint_session := st
    try {
        if _Hint_Load(st) {
            SetTimer(st.idle, -IH_TIMEOUT_SEC * 1000)
            st.hook.Start()
            st.hook.Wait()
        }
        else
            st.result := "none"
    }
    catch as e {
        st.result := "error"
        st.err := e.Message
    }
    finally {
        SetTimer(st.idle, 0)
        st.hook.Stop()
        _Hint_Close(st)
        Hint_session := ""
    }

    switch st.result {
        case "pick":
            msg := _Hint_Act(st.pick, st.mode)
        case "timeout":
            msg := "❌ [ヒント] タイムアウト"
        case "none":
            msg := "❌ [ヒント] 操作できる部品が見つかりません"
        case "error":
            msg := "⚠️ [ヒント] 取得に失敗：" st.err
        default:
            msg := "❌ [ヒント] キャンセル"
    }
    IH_ModeEnd(msg)
}

; キーが押されたとき（InputHook の OnKeyDown）
_Hint_OnKey(st, h, vk, sc) {
    SetTimer(st.idle, -IH_TIMEOUT_SEC * 1000)       ; 待ち時間は押すたびに数え直す
    if (st.result != "")                            ; 決定後は、親指キーを離すのを待っているだけ
        return
    if (vk = 0x20 || vk = 0x1C) {                   ; Space / 変換
        if !st.skip.Has(vk)
            st.mods[vk] := true
        return
    }
    if (sc = 0x01 || sc = 0x3A) {                   ; Esc / Caps
        _Hint_Finish(st, "cancel")
        return
    }
    if (sc = 0x0F) {                                ; Tab
        st.scope := (st.scope = "window") ? "taskbar" : "window"
        try
            _Hint_Load(st)
        catch as e {
            st.err := e.Message
            _Hint_Finish(st, "error")
        }
        return
    }
    if (sc = 0x0E) {                                ; BackSpace
        if (st.typed != "") {
            st.typed := SubStr(st.typed, 1, -1)
            _Hint_Refresh(st)
        }
        return
    }

    name := StrLower(GetKeyName(Format("vk{:X}sc{:X}", vk, sc)))
    if (StrLen(name) != 1 || !InStr(HINT_ALPHABET, name))
        return
    typed := st.typed name
    pick := 0, hit := false
    for it in st.items {
        if (it.label = typed)
            pick := it
        if (SubStr(it.label, 1, StrLen(typed)) = typed)
            hit := true
    }
    if !hit {
        ToolTip("🎯 [ヒント] 「" StrUpper(typed) "」のラベルはありません")
        SetTimer(_Hint_Tip.Bind(st), -700)
        return
    }
    st.typed := typed
    if pick {
        st.pick := pick
        st.mode := _Hint_Mode(st)
        st.result := "pick"
        _Hint_Close(st)
        if !st.mods.Count                           ; 親指キーを押したままなら、離すまでフックを残す（リピートが漏れないように）
            st.hook.Stop()
        return
    }
    _Hint_Refresh(st)
}

_Hint_OnKeyUp(st, h, vk, sc) {
    if st.skip.Has(vk)
        st.skip.Delete(vk)
    if st.mods.Has(vk)
        st.mods.Delete(vk)
    if (st.result = "pick" && !st.mods.Count)
        st.hook.Stop()
}

; 押している親指キーから、クリックの種類を決める
_Hint_Mode(st) {
    if st.mods.Has(0x20)
        return "double"
    if st.mods.Has(0x1C)
        return "right"
    return "left"
}

; 結果を決めて待ちを終える（最初に決めた結果を残す）
_Hint_Finish(st, result) {
    if (st.result = "")
        st.result := result
    st.hook.Stop()
}

; 対象から部品を集めてラベルを重ねる。見つかった数を返す
_Hint_Load(st) {
    _Hint_Close(st)
    st.typed := ""
    ToolTip("🎯 [ヒント] 部品を取得中...")           ; 初めて開くアプリは数秒かかることがある
    st.items := _Hint_Gather(st.scope)
    if st.items.Length
        st.ov := _Hint_Overlay(st.items)
    _Hint_Tip(st)
    return st.items.Length
}

_Hint_Close(st) {
    if st.ov {
        try st.ov.Destroy()
        st.ov := 0
    }
}

; 入力した文字に合うラベルだけ残し、打った分を除いて表示する
_Hint_Refresh(st) {
    n := StrLen(st.typed)
    for it in st.items {
        if (SubStr(it.label, 1, n) = st.typed) {
            it.ctrl.Text := StrUpper(SubStr(it.label, n + 1))
            it.ctrl.Visible := true
        }
        else
            it.ctrl.Visible := false
    }
    _Hint_Tip(st)
}

_Hint_Tip(st) {
    if !st.hook.InProgress && st.result != ""
        return
    now := (st.scope = "window") ? "ウィンドウ" : "タスクバー"
    other := (st.scope = "window") ? "タスクバー" : "ウィンドウ"
    ToolTip("🎯 [ヒント：" now "] " st.items.Length " 件" (st.typed != "" ? "　入力：" StrUpper(st.typed) : "")
        . "`n変換＋ラベル：右クリック　Space＋ラベル：ダブルクリック　Tab：" other "へ"
        . "`nBS：1 文字戻す　Esc / Caps：キャンセル（" IH_TIMEOUT_SEC " 秒で自動キャンセル）")
}

_Hint_Act(it, mode) {
    switch mode {
        case "right":
            MouseClick("Right", it.x, it.y, 1, 0)
            tip := "右クリック"
        case "double":
            MouseClick("Left", it.x, it.y, 2, 0)
            tip := "ダブルクリック"
        default:
            MouseClick("Left", it.x, it.y, 1, 0)
            tip := "クリック"
    }
    return "✅ [ヒント] " tip
}

;------------------------------------------------------------------------------
; 部品の収集・ラベルの割り当て
;------------------------------------------------------------------------------
; scope が "window" なら前面のウィンドウ、"taskbar" ならタスクバーの部品を、上から下・左から右の順で返す
_Hint_Gather(scope) {
    hwnds := []
    if (scope = "taskbar") {
        for cls in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd"]
            for hwnd in WinGetList("ahk_class " cls)
                hwnds.Push(hwnd)
    }
    else if (hwnd := WinExist("A"))
        hwnds.Push(hwnd)

    vx := SysGet(76), vy := SysGet(77), vr := vx + SysGet(78), vb := vy + SysGet(79)
    seen := Map(), items := []
    for hwnd in hwnds {
        rects := HintUIA.Collect(hwnd)
        if (rects.Length < 6 && InStr(WinGetClass(hwnd), "Chrome_WidgetWin")) {
            Sleep(250)
            rects := HintUIA.Collect(hwnd)
        }
        for r in rects {
            w := r.r - r.l, ht := r.b - r.t
            if (w < 6 || ht < 6 || r.r <= vx || r.l >= vr || r.b <= vy || r.t >= vb)
                continue
            key := r.l "," r.t "," r.r "," r.b
            if seen.Has(key)                        ; 同じ位置・大きさの入れ子の部品は 1 つにする
                continue
            seen[key] := true
            items.Push({x: Min(Max(r.l + Min(w // 2, 120), vx), vr - 1), y: Min(Max(r.t + ht // 2, vy), vb - 1)
                , l: r.l, t: r.t, label: "", ctrl: 0})
        }
    }
    if !items.Length
        return items

    keys := ""
    for i, it in items
        keys .= Format("{:06d}{:06d}{:05d}`n", (it.t + 20000) // 12, it.l + 20000, i)
    ordered := []
    loop parse Sort(RTrim(keys, "`n")), "`n"
        ordered.Push(items[Integer(SubStr(A_LoopField, 13))])

    ; 先に並べたラベルと重なる位置の部品（行とその中のセルなど）は、ラベルを付けない
    scale := A_ScreenDPI / 96
    mw := 28 * scale, mh := 20 * scale
    shown := []
    for it in ordered {
        near := false
        for o in shown {
            if (Abs(o.x - it.x) < mw && Abs(o.y - it.y) < mh) {
                near := true
                break
            }
        }
        if !near
            shown.Push(it)
    }
    ordered := shown
    labels := _Hint_MakeLabels(ordered.Length)
    for i, it in ordered
        it.label := labels[i]
    return ordered
}

; 個数 n 分のラベルを作る（どのラベルも別のラベルの先頭にならない。1 文字と 2 文字が混ざる）
_Hint_MakeLabels(n) {
    queue := [""], off := 0
    while (queue.Length - off < n || queue.Length = 1) {
        base := queue[++off]
        loop parse HINT_ALPHABET
            queue.Push(base A_LoopField)
    }
    labels := []
    loop n
        labels.Push(queue[off + A_Index])
    return labels
}

;------------------------------------------------------------------------------
; ラベルの表示（クリックを通す透明なウィンドウに、ラベルを部品の位置へ並べる）
;------------------------------------------------------------------------------
_Hint_Overlay(items) {
    static TRANS := "010203"
    scale := A_ScreenDPI / 96
    vx := SysGet(76), vy := SysGet(77)
    ov := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +E0x08000000")   ; クリックを通す・アクティブにならない
    ov.BackColor := TRANS
    ov.MarginX := 0, ov.MarginY := 0
    ov.SetFont("s9 bold c" HINT_LABEL_FG, "Segoe UI")
    lh := Round(18 * scale)
    for it in items {
        lw := Round((StrLen(it.label) * 9 + 8) * scale)
        it.ctrl := ov.AddText(Format("x{} y{} w{} h{} 0x201 Border Background{}"
            , it.x - vx - lw // 2, it.y - vy - lh // 2, lw, lh, HINT_LABEL_BG), StrUpper(it.label))
    }
    ov.Show("NA x" vx " y" vy " w" SysGet(78) " h" SysGet(79))
    WinSetTransColor(TRANS " " HINT_LABEL_ALPHA, ov)
    return ov
}

;------------------------------------------------------------------------------
; UI Automation（COM を直接呼ぶ最小実装）
;   ウィンドウの部品の木を、必要なプロパティ付きで 1 回で取り（キャッシュ）、手元で絞り込む。
;   条件を付けて検索（FindAll）するより速い。
;   使うのは次のメソッドだけ（数字は仮想関数表の番号）
;     IUIAutomation             10 ElementFromHandleBuildCache　20 CreateCacheRequest
;     IUIAutomationElement      12 GetCachedPropertyValue　19 GetCachedChildren　70 CachedIsOffscreen
;                               75 CachedBoundingRectangle
;     IUIAutomationElementArray 3 Length　4 GetElement
;     IUIAutomationCacheRequest 3 AddProperty　7 TreeScope　11 AutomationElementMode
;------------------------------------------------------------------------------
class HintUIA {
    static _com   := 0              ; IUIAutomation（COM オブジェクト。解放されないよう保持する）
    static _ptr   := 0
    static _cache := 0              ; 先に取っておくプロパティの指定
    ; 操作できる部品が持つパターン：Invoke / ExpandCollapse / SelectionItem / Toggle / Value
    static _PATTERNS := [30031, 30028, 30036, 30041, 30043]

    static _Init() {
        if this._ptr
            return
        this._com := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        this._ptr := ComObjValue(this._com)
        ComCall(20, this._ptr, "ptr*", &cr := 0)
        ComCall(3, cr, "int", 30001)                ; BoundingRectangle
        ComCall(3, cr, "int", 30022)                ; IsOffscreen
        ComCall(3, cr, "int", 30046)                ; ValueIsReadOnly
        for id in this._PATTERNS
            ComCall(3, cr, "int", id)
        ComCall(7, cr, "int", 5)                    ; 対象の部品とその子孫すべて
        ComCall(11, cr, "int", 0)                   ; 部品そのものは持たない（取得が速くなる）
        this._cache := cr
    }

    ; hwnd のウィンドウにある操作できる部品の位置を、画面外のものを除いて [{l, t, r, b}, …] で返す
    static Collect(hwnd) {
        this._Init()
        out := []
        ComCall(10, this._ptr, "ptr", hwnd, "ptr", this._cache, "ptr*", &root := 0)
        if !root
            return out
        try
            this._Walk(root, out, Buffer(16), Buffer(24))
        finally
            ObjRelease(root)
        return out
    }

    ; el とその子孫を調べ、操作できて画面内にある部品の位置を out に足す（rc・v は作業用の領域）
    static _Walk(el, out, rc, v) {
        try {
            for id in this._PATTERNS {
                ComCall(12, el, "int", id, "ptr", v)    ; VARIANT_BOOL
                if (NumGet(v, 0, "ushort") = 11 && NumGet(v, 8, "short") != 0) {
                    if (id = 30043 && this._Bool(el, 30046, v))
                        continue                        ; 読み取り専用の値（表のセルなど）だけの部品は除く
                    ComCall(70, el, "int*", &off := 0)
                    if !off {
                        ComCall(75, el, "ptr", rc)
                        out.Push({l: NumGet(rc, 0, "int"), t: NumGet(rc, 4, "int")
                            , r: NumGet(rc, 8, "int"), b: NumGet(rc, 12, "int")})
                    }
                    break
                }
            }
        }
        ComCall(19, el, "ptr*", &kids := 0)
        if !kids
            return
        try {
            ComCall(3, kids, "int*", &n := 0)
            loop n {
                ComCall(4, kids, "int", A_Index - 1, "ptr*", &kid := 0)
                try
                    this._Walk(kid, out, rc, v)
                finally
                    ObjRelease(kid)
            }
        }
        finally
            ObjRelease(kids)
    }

    ; キャッシュした真偽値のプロパティを読む
    static _Bool(el, propId, v) {
        ComCall(12, el, "int", propId, "ptr", v)
        return NumGet(v, 0, "ushort") = 11 && NumGet(v, 8, "short") != 0
    }
}
