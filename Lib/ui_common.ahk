#Requires AutoHotkey v2.0
;==============================================================================
; ui_common.ahk
; 画面の表示まわりで、いくつかの部品が共通で使うもの（ツールチップ、小窓の位置、モニター、ウィンドウの矩形）
;   quick_menu.ahk から分けた。関数は UI_ で始める
;==============================================================================
#Include %A_LineFile%\..\config.ahk

; ツールチップを一定時間表示する（InputHook 側のツールチップと干渉しないよう TIP_ID_UI を使う）
UI_Tip(msg, ms := 1500) {
    ToolTip(msg, , , TIP_ID_UI)
    SetTimer(() => ToolTip(, , , TIP_ID_UI), -ms)
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

UI_MonitorFromPoint(x, y) {
    loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x < r && y >= t && y < b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; ウィンドウの見た目どおりの矩形 {l, t, r, b}（影を含まない。取れなければ GetWindowRect）
UI_VisibleRect(hwnd) {
    rc := Buffer(16, 0)
    if (DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rc, "UInt", 16) != 0)   ; DWMWA_EXTENDED_FRAME_BOUNDS
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rc)
    return {l: NumGet(rc, 0, "Int"), t: NumGet(rc, 4, "Int"), r: NumGet(rc, 8, "Int"), b: NumGet(rc, 12, "Int")}
}
