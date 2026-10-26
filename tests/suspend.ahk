#Requires AutoHotkey v2.0
;==============================================================================
; suspend.ahk
; 動いている main.ahk（リポジトリ直下のもの）のホットキーの「一時停止」を切り替える。試験の間だけ使う（tests\run_tests.ps1 が前後 1 回ずつ呼ぶ）。
;   使い方：suspend.ahk リポジトリのパス
;   いまの状態は外から読めない（メニューにも出ない）ので、切り替えるだけ。途中で打ち切ったら、もう一度呼んで戻す。
;==============================================================================
DetectHiddenWindows(true)
SetTitleMatchMode(2)
root := (A_Args.Length >= 1) ? A_Args[1] : ""
hwnd := WinExist(root "\main.ahk ahk_class AutoHotkey")
if !hwnd
    ExitApp(2)
PostMessage(0x111, 65305, , , "ahk_id " hwnd)
ExitApp(0)
