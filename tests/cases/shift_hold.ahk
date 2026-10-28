#Requires AutoHotkey v2.0
; Shift 長押しモード（Caps → 無変換、shift_hold.ahk）と、Caps → 変換、解除した入力待ちの特殊キー
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
T_Tap("sc03A"), Sleep(400), T_Tap("vk1D"), Sleep(700)
T_Expect("Caps → 無変換：上端の帯が出る", BarCount(), 1)
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

; Shift を押していると Space 単独のホットキーが押した時点で働く。組み合わせを使ったら空白を入れない
T_Clear()
T_Tap("sc03A"), Sleep(400), T_Tap("vk1D"), Sleep(700)
T_Down("vk20"), T_Tap("a"), Sleep(300), T_Tap("a"), Sleep(300), T_Up("vk20")
Sleep(300)
T_Expect("Shift モード中の Space+A → a（Space を押したまま）：空白が入らない", T_Value(), "+")
T_Clear()
T_Down("vk20"), T_Tap("a"), Sleep(300), T_Up("vk20"), Sleep(100), T_Tap("a")
Sleep(300)
T_Expect("Shift モード中の Space+A → a（Space を離してから）", T_Value(), "+")
T_Clear()
T_Combo("vk20", "j")
T_Expect("Shift モード中の Space+j：空白が入らない", T_Value(), "")
T_Tap("vk20")
T_Expect("Shift モード中の Space 短押し：空白", T_Value(), " ")
T_Tap("Escape")
Sleep(300)
T_Clear()
T_Down("LShift"), T_Combo("vk20", "j"), T_Up("LShift")
T_Expect("Shift+Space+j：空白が入らない", T_Value(), "")

T_End()
