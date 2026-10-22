#Requires AutoHotkey v2.0
;==============================================================================
; ui_common.ahk
; 画面の表示まわりで、いくつかの部品が共通で使うもの
;   ツールチップ（UI_Tip / UI_TipFlash / UI_TipClear）、小窓の位置、モニター（番号・矩形）、ウィンドウの矩形、
;   デスクトップ・タスクバーの判定（UI_IsShellWindow）、UI Automation の生成（UI_Uia）
;   quick_menu.ahk から分けた。関数は UI_ で始める
;==============================================================================
#Include %A_LineFile%\..\config.ahk

; ToolTip と同じ引数・戻り値で、文字を TOOLTIP_FONT_SIZE にして出す
UI_ToolTip(text := "", x?, y?, id?) {
    static hFont := DllCall("CreateFontW", "Int", -Round(TOOLTIP_FONT_SIZE * A_ScreenDPI / 72), "Int", 0, "Int", 0, "Int", 0
        , "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0, "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 5, "UInt", 0, "Str", "Yu Gothic UI", "Ptr")
    hwnd := ToolTip(text, x?, y?, id?)
    if (hwnd && text != "" && SendMessage(0x31, 0, 0, , hwnd) != hFont) {   ; WM_GETFONT
        SendMessage(0x30, hFont, 0, , hwnd)                                 ; WM_SETFONT
        ToolTip(text, x?, y?, id?)                                          ; 大きさを測り直させる
    }
    return hwnd
}

; ツールチップを一定時間表示する（InputHook 側のツールチップと干渉しないよう TIP_ID_UI を使う）
UI_Tip(msg, ms := 1500) {
    static clear := () => UI_ToolTip(, , , TIP_ID_UI)      ; 同じ関数にして、前の消去の予約を上書きする
    UI_ToolTip(msg, , , TIP_ID_UI)
    SetTimer(clear, -ms)
}

; 既定のツールチップ（1 番。入力待ちやモードの表示と共通）を ms 後に消す。
; 消す関数を 1 つにしているので、新しい表示や SetTimer(UI_TipClear, 0) で、前の消去の予約が取り消される
UI_TipFlash(msg, ms := TOOLTIP_DURATION_MS) {
    UI_ToolTip(msg)
    SetTimer(UI_TipClear, -ms)
}

UI_TipClear() => ToolTip()

; UI Automation（IUIAutomation）のポインタ。COM オブジェクトは 1 つだけ作って持ち続ける（解放されないように）
;   使う部品：screen_capture.ahk（CapUIA）、vimium_c_hints.ahk（VimiumCUIA）。仮想関数表の番号はそれぞれの部品に書く
UI_Uia() {
    static com := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")
    return ComObjValue(com)
}

; ウィンドウの大きさ（非表示でも取得できる）
UI_GetWinSize(hwnd, &w, &h) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    w := NumGet(rc, 8, "Int") - NumGet(rc, 0, "Int")
    h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")
}

; 小窓の表示位置：文字カーソルの下（取れなければマウスの位置）
UI_PopupPos(&x, &y) {
    CoordMode("Caret", "Screen"), CoordMode("Mouse", "Screen")
    if CaretGetPos(&x, &y)
        y += 24
    else
        MouseGetPos(&x, &y)
}

; 窓が画面からはみ出さないよう x, y を調整する
UI_ClampToMonitor(hwnd, &x, &y) {
    UI_GetWinSize(hwnd, &w, &h)
    MonitorGetWorkArea(UI_MonitorFromPoint(x, y), &l, &t, &r, &b)
    x := Max(l, Min(x, r - w)), y := Max(t, Min(y, b - h))
}

; 一覧の高さを行数に合わせ、その下の文字（foot）を詰める
UI_FitListView(lv, rows, foot) {
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
UI_RealVk(wParam, lParam) {
    if (wParam = 0xE5)
        return DllCall("MapVirtualKey", "UInt", (lParam >> 16) & 0xFF, "UInt", 1, "UInt")
    return wParam
}

; 点 (x, y) を含むモニターの番号（どのモニターにもなければメインのモニター）
UI_MonitorFromPoint(x, y) {
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; モニター（ハンドル hMon）の矩形 {L, T, R, B}（タスクバーも含む全体）
UI_MonitorRectOf(hMon) {
    mi := Buffer(40, 0), NumPut("UInt", 40, mi)
    DllCall("GetMonitorInfo", "Ptr", hMon, "Ptr", mi)
    return {L: NumGet(mi, 4, "Int"), T: NumGet(mi, 8, "Int"), R: NumGet(mi, 12, "Int"), B: NumGet(mi, 16, "Int")}
}

; 点 (x, y) にいちばん近いモニターの矩形
UI_MonitorRectFromPoint(x, y) => UI_MonitorRectOf(DllCall("MonitorFromPoint", "Int64", (y << 32) | (x & 0xFFFFFFFF), "UInt", 2, "Ptr"))

; ウィンドウといちばん多く重なるモニターの矩形
UI_MonitorRectFromWindow(hwnd) => UI_MonitorRectOf(DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr"))

; デスクトップかタスクバーのウィンドウか（ウィンドウ操作の対象から外すため。なくなったウィンドウでも例外にならない）
UI_IsShellWindow(hwnd) {
    cls := Buffer(512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", cls, "Int", 256)
    return RegExMatch(StrGet(cls), "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$") > 0
}

; ウィンドウの見た目どおりの矩形 {l, t, r, b}（影を含まない。取れなければ GetWindowRect）
UI_VisibleRect(hwnd) {
    rc := Buffer(16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rc, "UInt", 16) != 0)   ; DWMWA_EXTENDED_FRAME_BOUNDS
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    return {l: NumGet(rc, 0, "Int"), t: NumGet(rc, 4, "Int"), r: NumGet(rc, 8, "Int"), b: NumGet(rc, 12, "Int")}
}
