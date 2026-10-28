#Requires AutoHotkey v2.0
; 無変換 + 記号キー（hold_keys.ahk）。@ のキー（sc01A）は文字名と物理キーのずれで取りこぼしやすい
#Include ..\harness.ahk
T_Start("edit")

T_Clear()
T_Combo("vk1D", "sc01A")
T_Expect("無変換 + @ のキー = !", T_Value(), "!")

T_Clear()
T_Combo("vk1D", "sc028")
T_Expect("無変換 + : のキー = ?", T_Value(), "?")

T_End()
