#Requires AutoHotkey v2.0
;==============================================================================
; screen_saver.ahk
; スクリーンセーバー回避：オンの間、マウスを小刻みに動かす
;   ScreenSaver_Toggle() を呼ぶたびにオン／オフを切り替える（Space + F1）。Esc でも解除。
;   状態はトレイアイコン・トレイのツールチップ・トレイメニューのチェックで表示する。
;==============================================================================
#Include %A_LineFile%\..\config.ahk

ScreenSaver_on := false
SCREENSAVER_MENU := "スクリーンセーバー回避"
A_TrayMenu.Add(SCREENSAVER_MENU, (*) => ScreenSaver_Toggle())

ScreenSaver_Toggle() {
    global ScreenSaver_on := !ScreenSaver_on
    if ScreenSaver_on {
        SetTimer(_ScreenSaver_Jiggle, 1000)
        _ScreenSaver_EscWatcher().Start()
        TraySetIcon("imageres.dll", 102)            ; 目のアイコン
        A_IconTip := A_ScriptName "`n☕ スクリーンセーバー回避：ON"
        A_TrayMenu.Check(SCREENSAVER_MENU)
    } else {
        SetTimer(_ScreenSaver_Jiggle, 0)
        _ScreenSaver_EscWatcher().Stop()
        TraySetIcon("*")
        A_IconTip := ""
        A_TrayMenu.Uncheck(SCREENSAVER_MENU)
    }
    ToolTip("☕ スクリーンセーバー回避：" (ScreenSaver_on ? "ON" : "OFF"))
    SetTimer(() => ToolTip(), -TOOLTIP_DURATION_MS)
}

; オンのときだけ解除する（ホットキーから Esc を送るときに併用）
ScreenSaver_Off() {
    if ScreenSaver_on
        ScreenSaver_Toggle()
}

; Esc で解除するための監視。ホットキーと違い InputHook はこのスクリプト自身が送った Esc も拾える（V：Esc はそのまま通す）
_ScreenSaver_EscWatcher() {
    static h := 0
    if !h {
        h := InputHook("L0 V")
        h.KeyOpt("{Esc}", "N")
        h.OnKeyDown := (*) => (ScreenSaver_on ? SetTimer(ScreenSaver_Toggle, -1) : 0)
    }
    return h
}

; 相対移動で左右に 1 往復させる（絶対座標を使わないのでどのモニター上でも位置がずれない）
_ScreenSaver_Jiggle() {
    static right := false
    right := !right
    DllCall("mouse_event", "UInt", 0x0001, "Int", right ? 2 : -2, "Int", 0, "UInt", 0, "UPtr", 0)  ; MOUSEEVENTF_MOVE
}
