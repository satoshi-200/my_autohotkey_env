#Requires AutoHotkey v2.0
;==============================================================================
; screen_capture.ahk
; 画面キャプチャ（Snipping Tool 相当）。quick_menu.ahk の「C 画面キャプチャ」から呼ぶ
;
; 種類
;   Cap_Region()     … ドラッグで範囲を指定（画面を暗くし、選んだ範囲だけ明るく表示）
;   Cap_Window()     … 枠が出るウィンドウをクリックして、そのウィンドウ全体
;   Cap_Area()       … ウィンドウ内のクリックした部品・領域だけ（UI Automation）
;   Cap_Focus()      … いまフォーカスしている部品だけ。フォーカスを動かすと、枠も付いてくる（ホームポジションからでも押せるキーを下に割り当てている）
;   Cap_Active()     … いまのウィンドウ全体
;   Cap_Monitor()    … マウスがあるモニター全体
;   Cap_AllScreens() … すべてのモニター
;
; 操作（範囲・ウィンドウ・領域・フォーカスの選択中）
;   左クリック / ドラッグ / Enter / G / H … 決定（範囲はドラッグ）　　右クリック・Esc・Caps … 取り消し
;   ホイール↑ / K … 外側（親）の部品へ　　ホイール↓ / L … 内側（子）の部品へ（領域・フォーカス）
;   フォーカスの選択中だけ：F → Tab　A → Shift+Tab　D / E → F6　S / W → Shift+F6（矢印キーはそのまま使える）
;
; 結果は PNG で保存し（CAP_SAVE_DIR）、クリップボードにも画像でコピーする（CAP_COPY）
; QM_Tip / QM_MonitorFromPoint（quick_menu.ahk）を使う
;==============================================================================
#Include %A_LineFile%\..\config.ahk

CAP_SAVE_DIR    := EnvGet("USERPROFILE") "\Pictures\Screenshots"   ; 保存先（"" なら保存しない）
CAP_COPY        := true                    ; クリップボードにコピーするか
CAP_DELAY_MS    := 250                     ; 実行前の待ち時間（メニューが消えて画面が描き直されるのを待つ）
CAP_DIM_ALPHA   := 110                     ; 範囲選択中に画面を暗くする濃さ（0〜255）
CAP_FRAME_COLOR := "FF3B30"                ; 選択中の枠の色
CAP_FRAME_PX    := 3                       ; 枠の太さ
Cap_session     := ""                      ; 選択中の状態（選択中でなければ ""）

OnMessage(0x20, _Cap_OnSetCursor)          ; WM_SETCURSOR

#HotIf IsObject(Cap_session)
LButton::    _Cap_OnDown()
Enter::      _Cap_OnEnter()
g::          _Cap_OnEnter()
h::          _Cap_OnEnter()
RButton::    Cap_session.cancel := true
Esc::        Cap_session.cancel := true
sc03A::      Cap_session.cancel := true
WheelUp::    Cap_session.wheel++
WheelDown::  Cap_session.wheel := Max(0, Cap_session.wheel - 1)
k::          Cap_session.wheel++
l::          Cap_session.wheel := Max(0, Cap_session.wheel - 1)
#HotIf

; フォーカスをホームポジションから動かす
#HotIf IsObject(Cap_session) && Cap_session.mode = "focus"
f::          SendInput("{Tab}")
a::          SendInput("+{Tab}")
d::          SendInput("{F6}")
e::          SendInput("{F6}")
s::          SendInput("+{F6}")
w::          SendInput("+{F6}")
#HotIf

;------------------------------------------------------------------------------
; 呼び出し口
;------------------------------------------------------------------------------
Cap_Region()  => _Cap_Run("region")
Cap_Window()  => _Cap_Run("window")
Cap_Area()    => _Cap_Run("area")
Cap_Focus()   => _Cap_Run("focus")

Cap_Active() {
    if !(hwnd := WinExist("A"))
        return
    Sleep(CAP_DELAY_MS)
    _Cap_Finish(_Cap_Clamp(_Cap_WinRect(hwnd)))
}

Cap_Monitor() {
    MouseGetPos(&x, &y)
    MonitorGet(QM_MonitorFromPoint(x, y), &l, &t, &r, &b)
    Sleep(CAP_DELAY_MS)
    _Cap_Finish({l: l, t: t, r: r, b: b})
}

Cap_AllScreens() {
    vx := SysGet(76), vy := SysGet(77)
    Sleep(CAP_DELAY_MS)
    _Cap_Finish({l: vx, t: vy, r: vx + SysGet(78), b: vy + SysGet(79)})
}

;------------------------------------------------------------------------------
; 範囲の選択（region / window / area / focus）
;------------------------------------------------------------------------------
_Cap_Run(mode) {
    global Cap_session
    if IsObject(Cap_session)
        return
    CoordMode("ToolTip", "Screen")
    Sleep(CAP_DELAY_MS)
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    live := (mode = "window" || mode = "focus")                 ; 選ぶ間に画面が変わるモードは、決定後に撮り直す
    snap := live ? 0 : _Cap_Grab(vx, vy, vw, vh)                ; それ以外は、見ていた状態を撮る
    st := {mode: mode, down: false, cancel: false, wheel: 0, x0: 0, y0: 0, hwnd: 0, dim: 0, frame: _Cap_FrameNew()}
    Cap_session := st
    rc := 0
    try {
        switch mode {
            case "region": rc := _Cap_PickRegion(st, vx, vy, vw, vh)
            case "window": rc := _Cap_PickHover(st, _Cap_KeyMouse, _Cap_HoverWindow
                , "クリック / Enter / G / H：このウィンドウを撮影")
            case "area":   rc := _Cap_PickHover(st, _Cap_KeyMouse, _Cap_HoverArea
                , "クリック / Enter / G / H：この領域を撮影　K / ホイール↑：外側へ　L / ホイール↓：内側へ")
            case "focus":  rc := _Cap_PickHover(st, _Cap_KeyFocus, _Cap_HoverFocus
                , "F：Tab　A：Shift+Tab　D / E：F6　S / W：Shift+F6　　K / ホイール↑：外側へ　L / ホイール↓：内側へ　　クリック / Enter / G / H：撮影")
        }
    } finally {
        Cap_session := ""
        ToolTip(, , , 19)
        for g in [st.dim, st.frame]
            if g
                g.Destroy()
    }

    if (rc && mode = "window") {                                ; 隠れた部分も撮れるよう、前面に出して撮り直す
        if !(WinGetClass(st.hwnd) ~= "^(Shell_TrayWnd|Progman|WorkerW)$")
            try WinActivate(st.hwnd)
        Sleep(CAP_DELAY_MS)
        rc := _Cap_Clamp(_Cap_WinRect(st.hwnd))
    } else if (rc && live)
        Sleep(CAP_DELAY_MS)                                     ; 枠とツールチップが消えるのを待つ
    _Cap_Finish(rc, snap, vx, vy)
}

_Cap_OnDown() {
    st := Cap_session
    if st.down
        return
    MouseGetPos(&x, &y)
    st.x0 := x, st.y0 := y, st.down := true
}

_Cap_OnEnter() {
    if (Cap_session.mode != "region")                           ; 範囲指定はドラッグで決める
        Cap_session.down := true
}

; ドラッグで範囲を選ぶ
_Cap_PickRegion(st, vx, vy, vw, vh) {
    st.dim := dim := _Cap_Layer("000000")
    WinSetTransparent(CAP_DIM_ALPHA, dim)
    dim.Show("NA x" vx " y" vy " w" vw " h" vh)
    MouseGetPos(&mx, &my)
    ToolTip("ドラッグで範囲を選択　右クリック / Esc：取消", mx + 16, my + 16, 19)
    while (!st.down && !st.cancel)
        Sleep(15)
    if st.cancel
        return 0

    last := ""
    rc := 0
    while (GetKeyState("LButton", "P") && !st.cancel) {
        MouseGetPos(&x, &y)
        rc := {l: Min(st.x0, x), t: Min(st.y0, y), r: Max(st.x0, x), b: Max(st.y0, y)}
        key := rc.l "," rc.t "," rc.r "," rc.b
        if (key != last) {
            last := key
            _Cap_Hole(dim, rc, vx, vy, vw, vh)
            _Cap_FrameSet(st.frame, rc)
            ToolTip((rc.r - rc.l) "×" (rc.b - rc.t), x + 16, y + 16, 19)
        }
        Sleep(10)
    }
    return (st.cancel || !rc) ? 0 : _Cap_Clamp(rc)
}

; 候補の矩形（rectFn が返す）に枠を出し、クリック・Enter で決定する
; keyFn が返す文字列（マウスやフォーカスの位置）が変わったら、親をたどる段数を 0 に戻す
_Cap_PickHover(st, keyFn, rectFn, hint) {
    lkey := lw := ""
    rc := 0
    while (!st.down && !st.cancel) {
        key := keyFn()
        if (key != lkey) {
            lkey := key, st.wheel := 0, lw := ""
        }
        if (st.wheel != lw) {
            rc := rectFn(st)
            lw := st.wheel
            if rc
                _Cap_FrameSet(st.frame, rc)
            else
                st.frame.Hide()
            if (st.mode = "focus" && rc)
                tx := rc.l + 8, ty := rc.t + 8
            else {
                MouseGetPos(&tx, &ty)
                tx += 16, ty += 16
            }
            ToolTip((rc ? (rc.r - rc.l) "×" (rc.b - rc.t) "`n" : "") hint, tx, ty, 19)
        }
        Sleep(40)
    }
    if (st.cancel || !rc)
        return 0
    while (GetKeyState("LButton", "P") && !st.cancel)           ; クリックを最後まで消費する
        Sleep(10)
    return st.cancel ? 0 : rc
}

_Cap_KeyMouse() {
    MouseGetPos(&x, &y)
    return x "," y
}

_Cap_KeyFocus() {
    try {
        rc := CapUIA.Focus(0, &used)
        return rc ? rc.l "," rc.t "," rc.r "," rc.b : ""
    }
    return ""
}

_Cap_HoverWindow(st) {
    MouseGetPos(, , &hwnd)
    if (!hwnd || hwnd = st.frame.Hwnd)
        return 0
    st.hwnd := hwnd
    return _Cap_Clamp(_Cap_WinRect(hwnd))
}

_Cap_HoverArea(st) {
    MouseGetPos(&x, &y)
    try {
        rc := CapUIA.Rect(x, y, st.wheel, &used)
        st.wheel := used
        return _Cap_Clamp(rc)
    }
    return 0
}

_Cap_HoverFocus(st) {
    try {
        rc := CapUIA.Focus(st.wheel, &used)
        st.wheel := used
        return _Cap_Clamp(rc)
    }
    return 0
}

;------------------------------------------------------------------------------
; 表示用のウィンドウ
;------------------------------------------------------------------------------
_Cap_Layer(color) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")   ; アクティブにならない
    g.BackColor := color
    return g
}

_Cap_FrameNew() {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +E0x08000000")   ; クリックを通す
    g.BackColor := CAP_FRAME_COLOR
    WinSetTransparent(250, g)                                   ; 透過属性を付けないとクリックが通らない
    return g
}

; rc の内側に沿った枠を表示する
_Cap_FrameSet(g, rc) {
    w := rc.r - rc.l, h := rc.b - rc.t, b := CAP_FRAME_PX
    g.Show("NA x" rc.l " y" rc.t " w" w " h" h)
    rgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr")
    if (w > 2 * b && h > 2 * b) {
        inner := DllCall("CreateRectRgn", "Int", b, "Int", b, "Int", w - b, "Int", h - b, "Ptr")
        DllCall("CombineRgn", "Ptr", rgn, "Ptr", rgn, "Ptr", inner, "Int", 4)   ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", inner)
    }
    DllCall("SetWindowRgn", "Ptr", g.Hwnd, "Ptr", rgn, "Int", true)   ; 領域の所有権は窓に移る
}

; 暗くする窓に、rc の部分だけ穴を開ける
_Cap_Hole(g, rc, vx, vy, vw, vh) {
    rgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", vw, "Int", vh, "Ptr")
    hole := DllCall("CreateRectRgn", "Int", rc.l - vx, "Int", rc.t - vy, "Int", rc.r - vx, "Int", rc.b - vy, "Ptr")
    DllCall("CombineRgn", "Ptr", rgn, "Ptr", rgn, "Ptr", hole, "Int", 4)
    DllCall("DeleteObject", "Ptr", hole)
    DllCall("SetWindowRgn", "Ptr", g.Hwnd, "Ptr", rgn, "Int", true)
}

; 範囲選択中は十字カーソルにする
_Cap_OnSetCursor(wParam, lParam, msg, hwnd) {
    if (IsObject(Cap_session) && Cap_session.dim && hwnd = Cap_session.dim.Hwnd) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32515, "Ptr"))   ; IDC_CROSS
        return true
    }
}

;------------------------------------------------------------------------------
; 矩形まわり
;------------------------------------------------------------------------------
; ウィンドウの見た目どおりの矩形（影・見えない枠を除く）
_Cap_WinRect(hwnd) {
    rc := Buffer(16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rc, "UInt", 16) != 0)   ; DWMWA_EXTENDED_FRAME_BOUNDS
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    return {l: NumGet(rc, 0, "Int"), t: NumGet(rc, 4, "Int"), r: NumGet(rc, 8, "Int"), b: NumGet(rc, 12, "Int")}
}

; 画面の外にはみ出した分を削る（小さすぎるときは 0）
_Cap_Clamp(rc) {
    vx := SysGet(76), vy := SysGet(77)
    l := Max(rc.l, vx), t := Max(rc.t, vy)
    r := Min(rc.r, vx + SysGet(78)), b := Min(rc.b, vy + SysGet(79))
    return (r - l >= 2 && b - t >= 2) ? {l: l, t: t, r: r, b: b} : 0
}

;------------------------------------------------------------------------------
; 画像の取得・出力
;------------------------------------------------------------------------------
; rc の部分を画像にして出力する。snap を渡すと、その画面全体の画像（原点 vx, vy）から切り出す
_Cap_Finish(rc, snap := 0, vx := 0, vy := 0) {
    if !rc {
        if snap
            DllCall("DeleteObject", "Ptr", snap)
        QM_Tip("キャプチャを取り消しました")
        return
    }
    w := rc.r - rc.l, h := rc.b - rc.t
    if snap {
        hbm := _Cap_Crop(snap, rc.l - vx, rc.t - vy, w, h)
        DllCall("DeleteObject", "Ptr", snap)
    } else
        hbm := _Cap_Grab(rc.l, rc.t, w, h)

    msg := "キャプチャしました（" w "×" h "）"
    if (CAP_SAVE_DIR != "") {
        path := CAP_SAVE_DIR "\Capture_" FormatTime(, "yyyyMMdd_HHmmss") ".png"
        try {
            DirCreate(CAP_SAVE_DIR)
            if _Cap_SavePng(hbm, path)
                msg .= "`n保存：" path
            else
                msg .= "`n保存できませんでした"
        } catch
            msg .= "`n保存できませんでした"
    }
    if (CAP_COPY && _Cap_CopyToClipboard(hbm))
        hbm := 0                                                ; クリップボードが所有する
    if hbm
        DllCall("DeleteObject", "Ptr", hbm)
    QM_Tip(msg (CAP_COPY ? "`nクリップボードにコピー" : ""), 2500)
}

; 画面の (x, y, w, h) を画像（HBITMAP）にする
_Cap_Grab(x, y, w, h) {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    hbm := _Cap_Blt(hdc, x, y, w, h)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return hbm
}

; 画像 snap の (x, y, w, h) を切り出す
_Cap_Crop(snap, x, y, w, h) {
    hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
    old := DllCall("SelectObject", "Ptr", hdc, "Ptr", snap, "Ptr")
    hbm := _Cap_Blt(hdc, x, y, w, h)
    DllCall("SelectObject", "Ptr", hdc, "Ptr", old)
    DllCall("DeleteDC", "Ptr", hdc)
    return hbm
}

_Cap_Blt(srcDc, x, y, w, h) {
    scr := DllCall("GetDC", "Ptr", 0, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", scr, "Int", w, "Int", h, "Ptr")
    mem := DllCall("CreateCompatibleDC", "Ptr", scr, "Ptr")
    old := DllCall("SelectObject", "Ptr", mem, "Ptr", hbm, "Ptr")
    DllCall("BitBlt", "Ptr", mem, "Int", 0, "Int", 0, "Int", w, "Int", h
        , "Ptr", srcDc, "Int", x, "Int", y, "UInt", 0x40CC0020)   ; SRCCOPY | CAPTUREBLT
    DllCall("SelectObject", "Ptr", mem, "Ptr", old)
    DllCall("DeleteDC", "Ptr", mem)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", scr)
    return hbm
}

_Cap_SavePng(hbm, path) {
    static token := 0
    if !token {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)                                   ; GdiplusVersion
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
    }
    if DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &bmp := 0)
        return false
    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "Str", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "Ptr", clsid)   ; PNG
    status := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bmp, "WStr", path, "Ptr", clsid, "Ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bmp)
    return status = 0
}

_Cap_CopyToClipboard(hbm) {
    loop 10 {
        if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) {
            DllCall("EmptyClipboard")
            ok := DllCall("SetClipboardData", "UInt", 2, "Ptr", hbm, "Ptr")   ; CF_BITMAP
            DllCall("CloseClipboard")
            return !!ok
        }
        Sleep(20)
    }
    return false
}

;------------------------------------------------------------------------------
; UI Automation：マウスの下・フォーカス中の部品の矩形（COM を直接呼ぶ最小実装）
;   仮想関数表の番号：IUIAutomation 7 ElementFromPoint　8 GetFocusedElement　14 get_ControlViewWalker
;                     IUIAutomationTreeWalker 3 GetParentElement
;                     IUIAutomationElement 43 CurrentBoundingRectangle
;------------------------------------------------------------------------------
class CapUIA {
    static _com := 0                ; 解放されないよう保持する
    static _ptr := 0
    static _walkerCom := 0
    static _walker := 0

    static _Init() {
        if this._ptr
            return
        this._com := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
        this._ptr := ComObjValue(this._com)
        ComCall(14, this._ptr, "ptr*", &w := 0)
        this._walkerCom := ComValue(13, w)
        this._walker := w
    }

    ; (x, y) の部品から up 段だけ親をたどった部品の矩形。たどれた段数を used に返す
    static Rect(x, y, up, &used) {
        this._Init()
        ComCall(7, this._ptr, "int64", (y << 32) | (x & 0xFFFFFFFF), "ptr*", &el := 0)
        return this._Climb(el, up, &used)
    }

    ; フォーカス中の部品から up 段だけ親をたどった部品の矩形
    static Focus(up, &used) {
        this._Init()
        ComCall(8, this._ptr, "ptr*", &el := 0)
        return this._Climb(el, up, &used)
    }

    ; el（ここで解放する）から up 段だけ親をたどり、その矩形を返す
    static _Climb(el, up, &used) {
        used := 0
        if !el
            return 0
        try {
            loop up {
                ComCall(3, this._walker, "ptr", el, "ptr*", &parent := 0)
                if !parent
                    break
                ObjRelease(el)
                el := parent
                used++
            }
            rc := Buffer(16, 0)
            ComCall(43, el, "ptr", rc)
            return {l: NumGet(rc, 0, "Int"), t: NumGet(rc, 4, "Int"), r: NumGet(rc, 8, "Int"), b: NumGet(rc, 12, "Int")}
        } finally
            ObjRelease(el)
    }
}
