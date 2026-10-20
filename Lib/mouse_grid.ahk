#Requires AutoHotkey v2.0
;==============================================================================
; mouse_grid.ahk
; カーソル移動モード（グリッドジャンプ）：キーボードの配置を画面の地図にして、マウスカーソルを大まかに飛ばす
;   keymap\leader_keys.ahk から呼ぶ。設計の経緯は docs\ideas.md の「カーソル移動モード」
;
; 操作
;   上段・中段・下段の 10 × 3 のキー … 領域をその位置のマスに絞り、中央へカーソルを飛ばす（MOUSEGRID_MAX_DEPTH 回選んだら自動終了。既定は 1）
;   BackSpace                  … 1 段戻る（MOUSEGRID_MAX_DEPTH が 2 以上のとき。やり直す）。変換+g や Space+s など、BackSpace を送る割り当ても同じ
;   Space+A → キー            … 左手だけで右手側のマスを指す（Space+A の表で右手側の文字に直し、そのマスへ。Q → P など）
;   Tab                        … 領域を替える（モニター → … → アクティブウィンドウ）
;   半角/全角                  … 開始位置へ戻って終わる
;   Esc / Caps / Space+Caps / カタカナひらがな … その場で終わる
;   赤ポチ・マウスの操作（飛んだ位置からカーソルがずれる、物理のボタンを押す）でも終わる
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\key_mode.ahk
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\mouse_cursor.ahk

MOUSEGRID_AUTO_END := true                   ; 赤ポチ・マウスの操作でモードを終える
MOUSEGRID_MANUAL_PX := 3                     ; 飛んだ位置からこの px 以上ずれたら、マウスの操作とみなす
MOUSEGRID_LINE_COLOR := "F0A0A0"             ; 枠・区切り線の色（薄い赤）
MOUSEGRID_LABEL_BG := "FFE066"               ; ラベルの背景色
MOUSEGRID_LABEL_FG := "000000"               ; ラベルの文字色
MOUSEGRID_ALPHA := 200                       ; 表示の不透明度（0〜255。小さいほど下の画面が見える）
MOUSEGRID_TIP := "corner"                    ; 案内の出し方（"corner"：左下に状態だけ、手が止まったら説明も / "hidden" / "cursor"。Lib\key_mode.ahk）
MouseGrid_session := ""                      ; 実行中のモードの状態（動作確認用。実行していなければ ""）

; 行ごとのキー（左から 10 個）と、その先頭のスキャンコード
MOUSEGRID_ROW_KEYS := ["qwertyuiop", "asdfghjkl;", "zxcvbnm,./"]   ; 数字列はホームポジションから遠いので使わない
MOUSEGRID_ROW_SC   := [0x10, 0x1E, 0x2C]
MOUSEGRID_COLS := 10
MOUSEGRID_ROWS := 3
MOUSEGRID_MAX_DEPTH := 1                     ; この回数だけマスを選んだら自動で終わる（2 以上にすると、そのマスの中をさらに分けて選べる）

;------------------------------------------------------------------------------
; モード本体
;------------------------------------------------------------------------------
MouseGrid_Start() {
    global MouseGrid_session
    InstallMouseHook()                              ; 物理のボタンの判定に必要
    MouseNav._GetPos(&x, &y)
    st := {roots: [], root: 1, area: 0, stack: [], start: {x: x, y: y}, last: {x: x, y: y}, ov: 0}
    st.poll := _MG_Poll.Bind(st)
    MouseGrid_session := st
    IHM_Run(st, {message: _MG_Message, onKey: _MG_OnKey, onTip: _MG_Tip, onStart: _MG_OnStart, onEnd: _MG_OnEnd
        , critical: true                            ; 位置の判定のタイマーに割り込まれないように
        , tip: MOUSEGRID_TIP
        , keep: [0x29, 0x70]})                      ; 半角/全角・カタカナひらがなは Space+A の待ちでもそのまま効かせる
}

_MG_OnStart(st) {
    _MG_SetRoots(st, st.start.x, st.start.y)
    _MG_CreateOverlay(st)
    _MG_Tip(st)
    if MOUSEGRID_AUTO_END
        SetTimer(st.poll, 50)
}

_MG_OnEnd(st) {
    global MouseGrid_session
    SetTimer(st.poll, 0)
    if st.ov
        try st.ov.Destroy()
    MouseGrid_session := ""
    if (st.result = "back")
        DllCall("SetCursorPos", "Int", st.start.x, "Int", st.start.y)
}

_MG_Message(st) {
    switch st.result {
        case "back":    return "✅ [カーソル移動] 開始位置へ戻りました"
        case "picked":  return "✅ [カーソル移動] " MOUSEGRID_MAX_DEPTH " 打鍵で移動しました"
        case "manual":  return "✅ [カーソル移動] マウスの操作で終了"
        case "timeout": return "❌ [カーソル移動] タイムアウト"
        case "error":   return "⚠️ [カーソル移動] 失敗：" st.err
        default:        return "✅ [カーソル移動] 終了"
    }
}

; 最初に選べる領域：各モニター（左から順）と、アクティブウィンドウ。最初はカーソルのあるモニター
_MG_SetRoots(st, x, y) {
    for i, m in MouseNav._Monitors() {
        st.roots.Push({name: "モニター " i, l: m.L, t: m.T, r: m.R, b: m.B})
        if (x >= m.L && x < m.R && y >= m.T && y < m.B)
            st.root := i
    }
    hwnd := DllCall("GetForegroundWindow", "Ptr")
    if MouseNav._IsWarpTarget(hwnd) {
        rc := UI_VisibleRect(hwnd)
        mr := MouseNav._MonitorRect((rc.l + rc.r) // 2, (rc.t + rc.b) // 2)
        w := {name: "ウィンドウ", l: Max(rc.l, mr.L), t: Max(rc.t, mr.T), r: Min(rc.r, mr.R), b: Min(rc.b, mr.B)}
        if (w.r - w.l >= 40 && w.b - w.t >= 40)
            st.roots.Push(w)
    }
    st.area := _MG_Copy(st.roots[st.root])
}

_MG_Copy(a) => {name: a.name, l: a.l, t: a.t, r: a.r, b: a.b}

; キーが来たとき（リピートの無視、親指キーの読み替え、Space+A は骨組み key_mode.ahk）
_MG_OnKey(st, k) {
    real := k.sc
    if k.left {                                     ; Space+A のあとのキー：右手側の文字のマス
        real := _MG_CharSc(k.name)
        if !real {
            _MG_Tip(st)
            return
        }
    }
    switch real {
        case 0x01, 0x3A, 0x70:                      ; Esc / Caps / カタカナひらがな
            IHM_Finish(st, "end")
        case 0x29:                                  ; 半角/全角
            IHM_Finish(st, "back")
        case 0x0E:                                  ; BackSpace
            _MG_Back(st)
        case 0x0F:                                  ; Tab
            _MG_NextRoot(st)
        default:
            for row, base in MOUSEGRID_ROW_SC {
                if (real >= base && real < base + MOUSEGRID_COLS) {
                    _MG_Pick(st, real - base, row - 1)
                    break
                }
            }
    }
}

; 文字 ch のマスのスキャンコード。マスにない文字は 0
_MG_CharSc(ch) {
    if (StrLen(ch) != 1)
        return 0
    for row, keys in MOUSEGRID_ROW_KEYS {
        pos := InStr(keys, ch)
        if pos
            return MOUSEGRID_ROW_SC[row] + pos - 1
    }
    return 0
}

; 飛んだ位置からカーソルがずれた（赤ポチなど）、または物理のボタンが押されたら終える
_MG_Poll(st) {
    if (st.result != "")
        return
    MouseNav._GetPos(&x, &y)
    if (Abs(x - st.last.x) >= MOUSEGRID_MANUAL_PX || Abs(y - st.last.y) >= MOUSEGRID_MANUAL_PX
        || GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P"))
        IHM_Finish(st, "manual")
}

; 領域 a の col 列・row 行（0 始まり）のマス
_MG_Cell(a, col, row) {
    w := a.r - a.l, h := a.b - a.t
    l := a.l + col * w // MOUSEGRID_COLS
    t := a.t + row * h // MOUSEGRID_ROWS
    r := Max(a.l + (col + 1) * w // MOUSEGRID_COLS, l + 1)
    b := Max(a.t + (row + 1) * h // MOUSEGRID_ROWS, t + 1)
    return {name: a.name, l: l, t: t, r: r, b: b}
}

; カーソルを移す（飛んだ位置を覚え、マウスの操作との区別に使う）
_MG_Warp(st, x, y) {
    st.last := {x: x, y: y}
    DllCall("SetCursorPos", "Int", x, "Int", y)
}

_MG_WarpCenter(st) => _MG_Warp(st, (st.area.l + st.area.r) // 2, (st.area.t + st.area.b) // 2)

_MG_Pick(st, col, row) {
    st.stack.Push({area: st.area, x: st.last.x, y: st.last.y})
    st.area := _MG_Cell(st.area, col, row)
    _MG_WarpCenter(st)
    if (st.stack.Length >= MOUSEGRID_MAX_DEPTH) {
        IHM_Finish(st, "picked")
        return
    }
    _MG_Draw(st)
    _MG_Tip(st)
}

_MG_Back(st) {
    if !st.stack.Length
        return
    p := st.stack.Pop()
    st.area := p.area
    _MG_Warp(st, p.x, p.y)
    _MG_Draw(st)
    _MG_Tip(st)
}

_MG_NextRoot(st) {
    if (st.roots.Length < 2)
        return
    st.root := Mod(st.root, st.roots.Length) + 1
    st.area := _MG_Copy(st.roots[st.root])
    st.stack := []
    _MG_WarpCenter(st)
    _MG_Draw(st)
    _MG_Tip(st)
}

; 案内（出し方は MOUSEGRID_TIP。既定はモニターの左下に状態だけを出し、手が止まったら説明も出す）
_MG_Tip(st) {
    a := st.area
    IHM_Tip(st, "🧭 [カーソル移動：" a.name "] 領域 " (a.r - a.l) "×" (a.b - a.t) (MOUSEGRID_MAX_DEPTH > 1 ? "　段 " (st.stack.Length + 1) : "")
            . (st.leftHand ? "　左手入力：次のキーを右手側のマスに" : "")
        , "キーの位置 = 画面の位置　" (MOUSEGRID_MAX_DEPTH > 1 ? "BS：1 段戻る　" : "") "Tab：領域を替える（" st.roots.Length " 件）"
            . "`nSpace+A → キー：左手だけで右手側のマスを指す"
            . "`n半角/全角：開始位置へ戻る　Esc / Caps / Space+Caps / かな：終了　赤ポチの操作でも終了")
}

;------------------------------------------------------------------------------
; 表示（クリックを通すウィンドウを、枠・区切り線・ラベルの形だけに切り抜く）
; 全画面のウィンドウを色抜きで透かす方式は、表示の直後に画面全体が一瞬暗くなるので使わない
;------------------------------------------------------------------------------
_MG_CreateOverlay(st) {
    scale := A_ScreenDPI / 96
    vx := SysGet(76), vy := SysGet(77)
    ov := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +E0x08000000")   ; クリックを通す・アクティブにならない
    ov.MarginX := 0, ov.MarginY := 0
    ov.SetFont("s9 bold c" MOUSEGRID_LABEL_FG, "Segoe UI")
    st.ov := ov
    st.lw := Round(16 * scale), st.lh := Round(16 * scale)
    st.lineW := Max(1, Round(scale)), st.frameW := Max(1, Round(scale))
    ; 重なりの順：枠・区切り線の上にラベル
    st.frame := [], st.vlines := [], st.hlines := [], st.labels := []
    line := "x0 y0 w1 h1 Background" MOUSEGRID_LINE_COLOR
    loop 4
        st.frame.Push(ov.AddText(line))
    loop MOUSEGRID_COLS - 1
        st.vlines.Push(ov.AddText(line))
    loop MOUSEGRID_ROWS - 1
        st.hlines.Push(ov.AddText(line))
    for row in MOUSEGRID_ROW_KEYS
        for ch in StrSplit(row)
            st.labels.Push(ov.AddText(Format("x0 y0 w{} h{} 0x201 Border Background{}", st.lw, st.lh, MOUSEGRID_LABEL_BG), StrUpper(ch)))
    _MG_Draw(st)
    WinSetTransparent(MOUSEGRID_ALPHA, ov)
    ov.Show("NA x" vx " y" vy " w" SysGet(78) " h" SysGet(79))
}

; 現在の領域に合わせて、部品を動かし、見せる形に切り抜く
_MG_Draw(st) {
    a := st.area
    vx := SysGet(76), vy := SysGet(77)
    w := a.r - a.l, h := a.b - a.t
    shown := []                                     ; 見せる矩形 [l, t, r, b]（ウィンドウの座標）
    Put(ctrl, l, t, cw, ch) {
        ctrl.Move(l - vx, t - vy, cw, ch)
        shown.Push([l - vx, t - vy, l - vx + cw, t - vy + ch])
    }
    f := Min(st.frameW, Max(1, Min(w, h) // 2))
    Put(st.frame[1], a.l, a.t, w, f)
    Put(st.frame[2], a.l, a.b - f, w, f)
    Put(st.frame[3], a.l, a.t, f, h)
    Put(st.frame[4], a.r - f, a.t, f, h)
    if (w // MOUSEGRID_COLS >= 6)                   ; マスが小さいうちは区切り線を出さない
        for i, c in st.vlines
            Put(c, a.l + i * w // MOUSEGRID_COLS, a.t, st.lineW, h)
    if (h // MOUSEGRID_ROWS >= 6)
        for i, c in st.hlines
            Put(c, a.l, a.t + i * h // MOUSEGRID_ROWS, w, st.lineW)
    for i, c in st.labels {
        cell := _MG_Cell(a, Mod(i - 1, MOUSEGRID_COLS), (i - 1) // MOUSEGRID_COLS)
        if (cell.r - cell.l >= st.lw && cell.b - cell.t >= st.lh)
            Put(c, (cell.l + cell.r - st.lw) // 2, (cell.t + cell.b - st.lh) // 2, st.lw, st.lh)
    }
    rgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
    for r in shown {
        one := DllCall("CreateRectRgn", "Int", r[1], "Int", r[2], "Int", r[3], "Int", r[4], "Ptr")
        DllCall("CombineRgn", "Ptr", rgn, "Ptr", rgn, "Ptr", one, "Int", 2)   ; RGN_OR
        DllCall("DeleteObject", "Ptr", one)
    }
    DllCall("SetWindowRgn", "Ptr", st.ov.Hwnd, "Ptr", rgn, "Int", true)       ; 領域の所有権は窓に移る
}
