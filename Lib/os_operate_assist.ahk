#Requires AutoHotkey v2.0

Launch_copilot_on_msedge(){					;microsoft edge上のcopilotページを開く
	Run("msedge.exe `"https://www.bing.com/search?q=Bing+AI&showconv=1&FORM=hpcodx`"") ; "msedge.exe"はMicrosoft Edgeの実行ファイル名です。Copilot pageを開きます
	return
}
Launch_folder_explorer_at_shortcut_list_web_dir(){
	Run("explorer `"C:\Users\KNK07559\Documents\shortcut_list(web_dir)`"")
}

execute_app(){
	SendInput("!{F4}")
	FocusUnderCursor()
}

; ==============================================================================
; アクティブウィンドウの最前面表示（Always on Top）制御
;   AlwaysOnTop_Toggle()  : 現在の状態を反転
;   AlwaysOnTop_Set()     : 最前面に固定
;   AlwaysOnTop_Release() : 固定を解除
; ==============================================================================

; --- 内部共通：現在のウィンドウが最前面固定かを判定 ---
_IsAlwaysOnTop(hwnd) {
    return (WinGetExStyle(hwnd) & 0x8) ? true : false   ; WS_EX_TOPMOST = 0x8
}

; --- ① トグル ---
AlwaysOnTop_Toggle() {
    hwnd := WinExist("A")
    if !hwnd
        return
    if _IsAlwaysOnTop(hwnd) {
        WinSetAlwaysOnTop(0, hwnd)
        ToolTip("📌 最前面：解除")
    } else {
        WinSetAlwaysOnTop(1, hwnd)
        ToolTip("📌 最前面：固定")
    }
    SetTimer(() => ToolTip(), -tooltipDuration)
}

; --- ② 固定 ---
AlwaysOnTop_Set() {
    hwnd := WinExist("A")
    if !hwnd
        return
    WinSetAlwaysOnTop(1, hwnd)
    ToolTip("📌 最前面：固定")
    SetTimer(() => ToolTip(), -tooltipDuration)
}

; --- ③ 解除 ---
AlwaysOnTop_Release() {
    hwnd := WinExist("A")
    if !hwnd
        return
    WinSetAlwaysOnTop(0, hwnd)
    ToolTip("📌 最前面：解除")
    SetTimer(() => ToolTip(), -tooltipDuration)
}