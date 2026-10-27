#Requires AutoHotkey v2.0
; Space の短押し・修飾キー付き・Space+○（hold_keys.ahk）。割り当てを変えたら、期待を合わせる
#Include ..\harness.ahk
T_Start("msg")

T_Tap("vk20")
T_Expect("Space 短押しで空白", T_Msgs(), "[vk20](c32)")

T_Down("vk20"), Sleep(600), T_Up("vk20")
T_Expect("Space 長押しだけで離すと何も入力しない", T_Msgs(), "")

T_Down("LShift"), T_Tap("vk20"), T_Up("LShift")
T_Expect("Shift+Space が通る", T_Msgs(), "[vk20 Shift](c32)")

T_Down("LCtrl"), T_Tap("vk20"), T_Up("LCtrl")
T_Expect("Ctrl+Space が通る", T_Msgs(), "[vk20 Ctrl](c32)")

T_Combo("vk20", "j")
T_Expect("Space+j = ←", T_Msgs(), "[vk25]")
T_Combo("vk20", "l")
T_Expect("Space+l = ↓", T_Msgs(), "[vk28]")
T_Combo("vk20", "sc027")
T_Expect("Space+; = →（スキャンコードの行と衝突していない）", T_Msgs(), "[vk27]")

T_End()
