#Requires AutoHotkey v2.0
; Space + m , . / のクリック類（hold_keys.ahk）。マウスを試験用の窓の中へ動かす
#Include ..\harness.ahk
T_Start("msg")
CoordMode("Mouse", "Screen")
WinGetPos(&wx, &wy, &ww, &wh, "t_case")
MouseMove(wx + 200, wy + 80, 0)
Sleep(300)
T_Msgs()

T_Combo("vk20", ",")
T_Expect("Space+, ダブルクリック", T_Msgs(), "LDOWN LUP LDBL LUP")
T_Combo("vk20", ".")
T_Expect("Space+. 右クリック", T_Msgs(), "RDOWN RUP")
T_Combo("vk20", "/")
T_Expect("Space+/ 中クリック", T_Msgs(), "MDOWN MUP")
T_Combo("vk20", "m")
T_Expect("Space+m Ctrl+クリック", T_Msgs(), "LDOWN+Ctrl LUP+Ctrl")

T_End()
