#Requires AutoHotkey v2.0
; 変換・無変換で IME を切り替えたときの表示（text_input.ahk の _Ime_Tip）。ツールチップの文字は外から読めないので、出ているかだけ見る
#Include ..\harness.ahk
T_Start("msg")

TipShown() => WinExist("ahk_class tooltips_class32") ? 1 : 0

T_Tap("vk1C")
Sleep(150)
T_Expect("変換：表示が出る", TipShown(), 1)
Sleep(1200)
T_Expect("時間が過ぎると消える", TipShown(), 0)

T_Tap("vk1D")
Sleep(150)
T_Expect("無変換：表示が出る", TipShown(), 1)

T_End()
