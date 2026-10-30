#Requires AutoHotkey v2.0
;==============================================================================
; vimium_c_hints.ahk
; Vimium C 風ヒント：ブラウザ拡張の Vimium C（リンクヒント）と同じ操作を、デスクトップのアプリで行う。
; いまのウィンドウの操作できる部品（ボタン・タブ・入力欄・リスト項目など）に
; 英字のラベルを重ねて表示し、ラベルを打つとその部品をクリックする
;   keymap\leader_keys.ahk から呼ぶ
;
; Vimium C との対応
;   リンクヒントを出してラベルを打つ（f）→ VimiumC_ShowHints（通常のクリック）
;   ラベルは 1・2 文字で絞り込み、BackSpace で戻す、Esc で取り消す、という点も同じ
;   Vimium C では f / F / yf など別のコマンドでクリックの種類を選ぶ。ここでは、ラベルを打つ前にキーで選ぶ（下の「操作」）。
;
; 操作
;   ラベルの英字     … 1 〜 2 文字で決定（打つごとに候補が絞られる）。そのときのクリックの種類で動く（既定は左クリック）
;   クリックの種類   … ラベルを打つ前に切り替える。同じキーをもう一度押すと左クリックに戻る
;                       Caps → Ctrl+クリック　変換 → 右クリック　Space → 移動だけ　無変換 → ダブルクリック
;                       変換・Space・無変換は短押し（IHM_TAP_MS）だけ受ける。押したままにしたり、押している間に別のキーを打ったときは
;                       切り替えない（Space+A、変換+g などの組み合わせとぶつからない）
;   Space+A → キー   … 左手だけで右手側の文字を入力（keymap\leader_keys.ahk の Leader_SpaceA の表を読む。Q → P など）。
;                       Space+A を押したあとの次の 1 キーだけが対象
;   変換+g や Space+s など … BackSpace などを送る割り当ても、そのキーとして扱う（IH_LayerSc）
;   Tab              … 対象を「ウィンドウ ↔ タスクバー」で切り替え
;   BackSpace        … 1 文字戻す
;   Esc / Space+Caps        … キャンセル（IH_TIMEOUT_SEC 秒操作がなくてもキャンセル）
;   LShift                  … カーソル移動モード（Lib\mouse_grid.ahk）へ切り替え（Caps → Caps → LShift）
;
; 仕組み
;   部品の一覧は UI Automation（COM を直接呼ぶ最小実装 VimiumCUIA）で取る。
;   ・取るのは、クリック・選択・切り替え・展開・値の入力ができる部品だけ
;   ・Web ページの中身は対象外（ブラウザの拡張機能を使う想定）。Electron 系は最初の問い合わせで中身が
;     返らないことがあるので、少なければ一度だけ取り直す
;   ・ラベルは、クリックを送る位置に重ねる。位置は部品の中央（横長の部品は左から最大 120px）
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\key_mode.ahk
#Include %A_LineFile%\..\mouse_grid.ahk

VIMIUMC_ALPHABET := "asdfjklghweruio"        ; ラベルに使う文字（打ちやすいものから。多いほどラベルが短くなる。q・p は遠いので使わない）
VIMIUMC_LABEL_BG := "FFE066"                 ; ラベルの背景色
VIMIUMC_LABEL_BG_RIGHT := "7DD3FC"           ; 右クリックに切り替えている間のラベルの背景色
VIMIUMC_LABEL_BG_CTRL := "86EFAC"            ; Ctrl+クリック
VIMIUMC_LABEL_BG_DOUBLE := "F9A8D4"          ; ダブルクリック
VIMIUMC_LABEL_BG_HOVER := "C4B5FD"           ; 移動だけ
VIMIUMC_LABEL_FG := "000000"                 ; ラベルの文字色
VIMIUMC_LABEL_ALPHA := 255                   ; ラベルの不透明度（0〜255。小さいほど下の文字が見える）
VimiumC_session := ""                        ; 実行中のモードの状態（動作確認用。実行していなければ ""）
; 待っている間の案内の出し方（Lib\key_mode.ahk）。押したい部品を隠さないように、既定はモニターの左下に状態だけ（手が止まったら説明も）
;   "corner" / "hidden"（手が止まるまで出さない）/ "cursor"（以前のようにマウスカーソルの近く）
VIMIUMC_TIP := "corner"

; 部品を取得している間は InputHook がまだ無いので、Caps（Ctrl+クリック）と Shift（カーソル移動モード）はホットキーで受ける
#HotIf IsObject(VimiumC_session) && VimiumC_session.loading
sc03A:: _VimiumC_LoadCaps()
sc03A up:: VimiumC_session.capsDown := false
~*LShift:: VimiumC_session.gridPending := true
#HotIf

; 取得中に打った Caps。押しっぱなしのリピートでは動かすのを繰り返さない
_VimiumC_LoadCaps() {
    st := VimiumC_session
    if st.capsDown
        return
    st.capsDown := true
    st.mode := "ctrl"
}

;------------------------------------------------------------------------------
; モード本体
;------------------------------------------------------------------------------
VimiumC_ShowHints() {
    global VimiumC_session
    st := {scope: "window", items: [], ov: 0, typed: "", pick: 0, mode: "left", loading: true, gridPending: false, painted: ""
        , capsDown: true}                           ; 起動に使った Caps を離すまでは、リピートを無視する
    VimiumC_session := st
    IHM_Run(st, {message: _VimiumC_Message, onKey: _VimiumC_OnKey, onTip: _VimiumC_Tip, onStart: _VimiumC_OnStart
        , onEnd: _VimiumC_OnEnd, onKeyUp: _VimiumC_OnKeyUp, onThumbTap: _VimiumC_ThumbTap, tip: VIMIUMC_TIP})
    if (st.result = "grid")
        MouseGrid_Start()                           ; Caps → Caps → LShift
}

_VimiumC_OnStart(st) {
    found := _VimiumC_Load(st)
    st.loading := false
    _VimiumC_Recolor(st)                            ; 取得中に切り替えていた分
    if st.gridPending
        IHM_Finish(st, "grid")
    else if !found
        IHM_Finish(st, "none")
}

_VimiumC_OnEnd(st) {
    global VimiumC_session
    _VimiumC_Close(st)
    VimiumC_session := ""
}

; 終わったときの表示。選んだときはここでクリックする（ラベルの表示を消したあと）
_VimiumC_Message(st) {
    switch st.result {
        case "pick":    return _VimiumC_Act(st.pick, st.mode)
        case "grid":    return ""
        case "timeout": return "❌ [Vimium C ヒント] タイムアウト"
        case "none":    return "❌ [Vimium C ヒント] 操作できる部品が見つかりません"
        case "error":   return "⚠️ [Vimium C ヒント] 取得に失敗：" st.err
        default:        return "❌ [Vimium C ヒント] キャンセル"
    }
}

; キーが来たとき（リピートの無視、親指キーの読み替え、Space+A は骨組み key_mode.ahk）
_VimiumC_OnKey(st, k) {
    switch k.sc {
        case 0x3A:                                  ; Caps：Ctrl+クリックの切り替え（Space+Caps はキャンセル。Caps はリピートも届くので capsDown で止める）
            if st.held.Has(0x39)
                IHM_Finish(st, "cancel")
            else if !st.capsDown {
                st.capsDown := true
                _VimiumC_SetMode(st, "ctrl")
            }
        case 0x01:                                  ; Esc
            IHM_Finish(st, "cancel")
        case 0x2A:                                  ; LShift：カーソル移動モードへ
            IHM_Finish(st, "grid")
        case 0x0F:                                  ; Tab
            st.scope := (st.scope = "window") ? "taskbar" : "window"
            try
                _VimiumC_Load(st)
            catch as e {
                st.err := e.Message
                IHM_Finish(st, "error")
            }
        case 0x0E:                                  ; BackSpace
            if (st.typed != "") {
                st.typed := SubStr(st.typed, 1, -1)
                _VimiumC_Refresh(st)
            }
        default:
            _VimiumC_TypeLabel(st, k.name)
    }
}

; ラベルの文字を 1 つ打つ（合うラベルがなければ知らせる。1 つに決まればクリックへ）
_VimiumC_TypeLabel(st, name) {
    if (StrLen(name) != 1 || !InStr(VIMIUMC_ALPHABET, name))
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
        IHM_Tip(st, "🎯 [Vimium C ヒント] 「" StrUpper(typed) "」のラベルはありません")
        SetTimer(_VimiumC_Tip.Bind(st), -700)
        return
    }
    st.typed := typed
    if pick {
        st.pick := pick
        IHM_Finish(st, "pick")
        return
    }
    _VimiumC_Refresh(st)
}

_VimiumC_OnKeyUp(st, vk, sc) {
    if (sc = 0x3A)
        st.capsDown := false
}

; 親指キーの短押し（key_mode.ahk が、長押し・他のキーとの組み合わせを除いて呼ぶ）でクリックの種類を切り替える
_VimiumC_ThumbTap(st, sc) {
    static modes := Map(0x39, "hover", 0x79, "right", 0x7B, "double")
    _VimiumC_SetMode(st, modes[sc])
}

; クリックの種類を切り替える（同じ種類をもう一度で左クリックに戻す）
_VimiumC_SetMode(st, mode) {
    st.mode := (st.mode = mode) ? "left" : mode
    _VimiumC_Recolor(st)
    _VimiumC_Tip(st)
}

; 対象から部品を集めてラベルを重ねる。見つかった数を返す
_VimiumC_Load(st) {
    _VimiumC_Close(st)
    st.typed := ""
    IHM_Tip(st, "🎯 [Vimium C ヒント] 部品を取得中...")           ; 初めて開くアプリは数秒かかることがある
    st.items := _VimiumC_Gather(st.scope)
    if st.items.Length {
        st.painted := _VimiumC_Color(st)
        st.ov := _VimiumC_Overlay(st.items, st.painted)
    }
    _VimiumC_Tip(st)
    return st.items.Length
}

_VimiumC_Close(st) {
    if st.ov {
        try st.ov.Destroy()
        st.ov := 0
    }
}

; 入力した文字に合うラベルだけ残し、打った分を除いて表示する
_VimiumC_Refresh(st) {
    n := StrLen(st.typed)
    for it in st.items {
        if (SubStr(it.label, 1, n) = st.typed) {
            it.ctrl.Text := StrUpper(SubStr(it.label, n + 1))
            it.ctrl.Visible := true
        }
        else
            it.ctrl.Visible := false
    }
    _VimiumC_SetShape(st.ov, st.items)
    _VimiumC_Tip(st)
}

; 案内（出し方は VIMIUMC_TIP。既定はモニターの左下に状態だけを出し、手が止まったら説明も出す）
_VimiumC_Tip(st) {
    if !st.hook.InProgress && st.result != ""
        return
    now := (st.scope = "window") ? "ウィンドウ" : "タスクバー"
    other := (st.scope = "window") ? "タスクバー" : "ウィンドウ"
    typed := (st.typed != "") ? "　入力：" StrUpper(st.typed) : ""
    cancel := "`nBS：1 文字戻す　Esc：キャンセル　LShift：カーソル移動モード（" IH_TIMEOUT_SEC " 秒で自動キャンセル）"
    static names := Map("ctrl", "Ctrl+クリック", "double", "ダブルクリック", "right", "右クリック", "hover", "移動だけ")
    IHM_Tip(st, "🎯 [Vimium C ヒント：" now "] " st.items.Length " 件" typed (names.Has(st.mode) ? "　動作：" names[st.mode] : "")
            . (st.leftHand ? "　左手入力：次のキーを右手側の文字に" : "")
        , "Caps：Ctrl+クリック　変換：右クリック　Space：移動だけ　無変換：ダブルクリック（変換・Space・無変換は短押し）`nSpace+A → キー：左手だけで右手側の文字を入力　Tab：" other "へ" cancel)
}

_VimiumC_Act(it, mode) {
    switch mode {
        case "right":
            MouseClick("Right", it.x, it.y, 1, 0)
            tip := "右クリック"
        case "double":
            MouseClick("Left", it.x, it.y, 2, 0)
            tip := "ダブルクリック"
        case "ctrl":
            SendInput("{Ctrl down}")
            try MouseClick("Left", it.x, it.y, 1, 0)
            SendInput("{Ctrl up}")
            tip := "Ctrl+クリック"
        case "hover":
            MouseMove(it.x, it.y, 0)
            tip := "カーソル移動"
        default:
            MouseClick("Left", it.x, it.y, 1, 0)
            tip := "クリック"
    }
    return "✅ [Vimium C ヒント] " tip
}

;------------------------------------------------------------------------------
; 部品の収集・ラベルの割り当て
;------------------------------------------------------------------------------
; scope が "window" なら前面のウィンドウ、"taskbar" ならタスクバーの部品を、上から下・左から右の順で返す
_VimiumC_Gather(scope) {
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
        rects := VimiumCUIA.Collect(hwnd)
        if (rects.Length < 6 && InStr(WinGetClass(hwnd), "Chrome_WidgetWin")) {
            Sleep(250)
            rects := VimiumCUIA.Collect(hwnd)
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
    labels := _VimiumC_MakeLabels(ordered.Length)
    for i, it in ordered
        it.label := labels[i]
    return ordered
}

; 個数 n 分のラベルを作る（どのラベルも別のラベルの先頭にならない。1 文字と 2 文字が混ざる）
_VimiumC_MakeLabels(n) {
    queue := [""], off := 0
    while (queue.Length - off < n || queue.Length = 1) {
        base := queue[++off]
        loop parse VIMIUMC_ALPHABET
            queue.Push(base A_LoopField)
    }
    labels := []
    loop n
        labels.Push(queue[off + A_Index])
    return labels
}

;------------------------------------------------------------------------------
; ラベルの表示（クリックを通すウィンドウを、ラベルの形だけに切り抜いて部品の位置へ並べる）
; 全画面のウィンドウを色抜きで透かす方式は、表示の直後に画面全体が一瞬暗くなるので使わない
;------------------------------------------------------------------------------
_VimiumC_Overlay(items, bg) {
    scale := A_ScreenDPI / 96
    vx := SysGet(76), vy := SysGet(77)
    ov := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +E0x08000000")   ; クリックを通す・アクティブにならない
    ov.MarginX := 0, ov.MarginY := 0
    ov.SetFont("s9 bold c" VIMIUMC_LABEL_FG, "Segoe UI")
    lh := Round(18 * scale)
    for it in items {
        lw := Round((StrLen(it.label) * 9 + 8) * scale)
        it.rc := {l: it.x - vx - lw // 2, t: it.y - vy - lh // 2, w: lw, h: lh}
        it.ctrl := ov.AddText(Format("x{} y{} w{} h{} 0x201 Border Background{}"
            , it.rc.l, it.rc.t, lw, lh, bg), StrUpper(it.label))
    }
    _VimiumC_SetShape(ov, items)
    WinSetTransparent(VIMIUMC_LABEL_ALPHA, ov)
    ov.Show("NA x" vx " y" vy " w" SysGet(78) " h" SysGet(79))
    return ov
}

_VimiumC_Color(st) {
    switch st.mode {
        case "right":  return VIMIUMC_LABEL_BG_RIGHT
        case "ctrl":   return VIMIUMC_LABEL_BG_CTRL
        case "double": return VIMIUMC_LABEL_BG_DOUBLE
        case "hover":  return VIMIUMC_LABEL_BG_HOVER
        default:       return VIMIUMC_LABEL_BG
    }
}

; モードに合わせて、表示中のラベルの背景色を変える（透明度などは共通）
_VimiumC_Recolor(st) {
    color := _VimiumC_Color(st)
    if (!st.ov || color = st.painted)
        return
    st.painted := color
    for it in st.items {
        it.ctrl.Opt("Background" color)
        it.ctrl.Redraw()
    }
}

; 表示中のラベルの矩形だけを、ウィンドウの形にする
_VimiumC_SetShape(ov, items) {
    rgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
    for it in items {
        if !it.ctrl.Visible
            continue
        r := it.rc
        one := DllCall("CreateRectRgn", "Int", r.l, "Int", r.t, "Int", r.l + r.w, "Int", r.t + r.h, "Ptr")
        DllCall("CombineRgn", "Ptr", rgn, "Ptr", rgn, "Ptr", one, "Int", 2)   ; RGN_OR
        DllCall("DeleteObject", "Ptr", one)
    }
    DllCall("SetWindowRgn", "Ptr", ov.Hwnd, "Ptr", rgn, "Int", true)   ; 領域の所有権は窓に移る
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
class VimiumCUIA {
    static _ptr   := 0              ; IUIAutomation（UI_Uia() が持ち続けるものを借りる）
    static _cache := 0              ; 先に取っておくプロパティの指定
    ; 操作できる部品が持つパターン：Invoke / ExpandCollapse / SelectionItem / Toggle / Value
    static _PATTERNS := [30031, 30028, 30036, 30041, 30043]

    static _Init() {
        if this._ptr
            return
        this._ptr := UI_Uia()
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
