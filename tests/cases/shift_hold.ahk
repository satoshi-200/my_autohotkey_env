#Requires AutoHotkey v2.0
; Shift 長押しモード（Caps → Space、shift_hold.ahk）と、Caps → 変換、解除した入力待ちの特殊キー
#Include ..\harness.ahk
T_Start("edit")

BarCount() {
    DetectHiddenWindows(false)
    n := 0
    for hwnd in WinGetList("ahk_class AutoHotkeyGUI") {
        try {
            WinGetPos(&x, &y, &w, &h, hwnd)
            if (h = 6 && w > 800)
                n++
        }
    }
    return n
}

T_Clear()
T_Tap("sc03A"), Sleep(400), T_Tap("vk20"), Sleep(700)
T_Expect("Caps → Space：上端の帯が出る", BarCount(), 1)
T_Tap("a")
Sleep(200)
T_Expect("モード中は大文字", T_Value(), "A")
T_Tap("Enter")
Sleep(300)
T_Expect("IME オフの 1 回目の Enter：改行せずモードを抜ける", T_Value(), "A")
T_Expect("  帯が消える", BarCount(), 0)
T_Tap("b")
Sleep(200)
T_Expect("  抜けたあとは小文字", T_Value(), "Ab")
T_Tap("Enter")
Sleep(300)
T_Expect("2 回目の Enter：普通の改行", T_Value(), "Ab<LF>")

T_Clear()
T_Tap("sc03A"), Sleep(400), T_Tap("vk1C"), Sleep(600)
T_Tap("a"), T_Tap("b")
Sleep(300)
T_Expect("Caps → 変換：次の 1 文字だけ大文字", T_Value(), "Ab")

T_Clear()
T_Combo("vk20", "a")
Sleep(400)
T_Tap("vk20"), Sleep(400)
T_Tap("a")
Sleep(200)
T_Expect("Space+A → Space（解除済み）：何も起きず入力待ちが終わる", T_Value(), "a")

T_End()
