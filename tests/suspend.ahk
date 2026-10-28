#Requires AutoHotkey v2.0
;==============================================================================
; suspend.ahk
; 動いている main.ahk（リポジトリ直下のもの）のホットキーを止める・戻す。試験の間だけ使う（tests\run_tests.ps1 が前後に呼ぶ）。
;   使い方：suspend.ahk リポジトリのパス on|off（main.ahk の OnMessage(0x8051) が受ける。切り替えではないので、何度呼んでもずれない）
;==============================================================================
DetectHiddenWindows(true)
SetTitleMatchMode(2)
root := (A_Args.Length >= 1) ? A_Args[1] : ""
hwnd := WinExist(root "\main.ahk ahk_class AutoHotkey")
if !hwnd
    ExitApp(2)
try SendMessage(0x8051, (A_Args.Length >= 2 && A_Args[2] = "off") ? 0 : 1, 0, , "ahk_id " hwnd, , , , 2000)
ExitApp(0)
