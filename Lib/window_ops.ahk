#Requires AutoHotkey v2.0
;==============================================================================
; window_ops.ahk
; ウィンドウ・仮想デスクトップ・システムの操作（クイックメニューの W / D / S / V から呼ぶ）
;   quick_menu.ahk から分けた。関数名の QM_ はそのまま
;   Window_CloseAndFocus（Space+F → [ / ]）もここにある
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\mouse_cursor.ahk

;--- ウィンドウ ---------------------------------------------------------------
QM_ToggleTopmost() {
    WinSetAlwaysOnTop(-1, "A")
    UI_Tip((WinGetExStyle("A") & 0x8) ? "常に最前面：ON" : "常に最前面：OFF")
}

QM_ToggleTransparent() {
    cur := WinGetTransparent("A")
    WinSetTransparent((cur = "") ? 200 : "Off", "A")
    UI_Tip((cur = "") ? "半透明：ON" : "半透明：OFF")
}

QM_CenterWindow() {
    if !(hwnd := WinExist("A"))
        return
    if (WinGetMinMax(hwnd) = 1)
        WinRestore(hwnd)
    WinGetPos(&x, &y, &w, &h, hwnd)
    MonitorGetWorkArea(UI_MonitorFromPoint(x + w // 2, y + h // 2), &l, &t, &r, &b)
    WinMove(l + (r - l - w) // 2, t + (b - t - h) // 2, , , hwnd)
}

QM_CopyWindowInfo() {
    if !WinExist("A")
        return
    text := Format("Title: {}`r`nClass: ahk_class {}`r`nExe:   ahk_exe {}`r`nPath:  {}"
        , WinGetTitle("A"), WinGetClass("A"), WinGetProcessName("A"), WinGetProcessPath("A"))
    A_Clipboard := text
    UI_Tip("ウィンドウ情報をコピーしました`n`n" text, 3000)
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
        UI_Tip((d > 0) ? "右側にデスクトップはありません" : "左側にデスクトップはありません")
        return
    }
    if carry
        QM_CarryWindow(() => QM_DesktopMoveBy(d))
    else
        QM_DesktopMoveBy(d)
    if known
        UI_Tip("デスクトップ " n " / " count)
}

; 新しいデスクトップを右端に作って切り替える（carry = true ならウィンドウも移動）
QM_DesktopNew(carry := false) {
    QM_DesktopState(&cur, &count)
    if carry
        QM_CarryWindow(() => SendInput("^#d"))
    else
        SendInput("^#d")
    UI_Tip("デスクトップを作成しました（" count + 1 " / " count + 1 "）")
}

; 今のデスクトップを閉じる（開いていたウィンドウは隣のデスクトップへ移る）
QM_DesktopClose() {
    if (QM_DesktopState(&cur, &count) && count <= 1) {
        UI_Tip("デスクトップが 1 つしかないため閉じられません")
        return
    }
    SendInput("^#{F4}")
    UI_Tip("デスクトップ " cur " を閉じました（残り " count - 1 " 個）")
}

QM_DesktopInfo() {
    if QM_DesktopState(&cur, &count)
        UI_Tip("現在のデスクトップ：" cur " / " count, 2500)
    else
        UI_Tip("仮想デスクトップの状態を取得できませんでした")
}

; アクティブなウィンドウを隠してから切り替え、切り替え先で表示し直す（表示した側のデスクトップに移る）
QM_CarryWindow(switchFn) {
    hwnd := WinExist("A")
    if (!hwnd || RegExMatch(WinGetClass(hwnd), "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$")) {
        UI_Tip("移動できるウィンドウがありません")
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

; アクティブなウィンドウを閉じ、カーソル下のウィンドウにフォーカスする
Window_CloseAndFocus() {
    SendInput("!{F4}")
    Mouse_FocusUnderCursor()
}
