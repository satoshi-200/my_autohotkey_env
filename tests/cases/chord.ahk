#Requires AutoHotkey v2.0
; 変換 / 無変換 を両方押したままの 3 キー（chord_keys.ahk / chord_ordered_keys.ahk）。
; 割り当てのあるキーの中身ではなく、「順番で働く」「割り当てのないキーは何も起きない」「通常の割り当ては止まる」を調べる
#Include ..\harness.ahk
T_Start("edit")

T_Clear()
SendInput("hello")
Sleep(300)
T_Chord("vk1C", "vk1D", "a")
T_Expect("変換→無変換 + a：元に戻す", T_Value(), "")

T_Clear()
SendInput("hello")
Sleep(300)
T_Chord("vk1D", "vk1C", "x")
T_Expect("無変換→変換 + x：割り当てなしは何も起きない", T_Value(), "hello")
T_Chord("vk1C", "vk1D", "x")
T_Expect("変換→無変換 + x：割り当てなしは何も起きない", T_Value(), "hello")
T_Chord("vk1D", "vk1C", "g")
T_Expect("無変換→変換 + g：通常の割り当て（BS・ワープ）は止まる", T_Value(), "hello")
T_Chord("vk1C", "vk1D", "g")
T_Expect("変換→無変換 + g：通常の割り当て（BS）は止まる", T_Value(), "hello")

T_Down("vk1C"), T_Tap("g"), T_Up("vk1C")
T_Expect("変換 + g だけなら BackSpace が働く", T_Value(), "hell")

T_End()
