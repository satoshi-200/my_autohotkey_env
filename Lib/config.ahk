#Requires AutoHotkey v2.0
;==============================================================================
; config.ahk
; スクリプト全体の動作設定・定型文などの定数と、キーコードの早見表
;   旧 global_settings.ahk / parameter.ahk / code_list.ahk を統合
;==============================================================================

;------------------------------------------------------------------------------
; 動作設定（旧 global_settings.ahk）
;------------------------------------------------------------------------------
; ---
; 参考
; ---
; ProcessSetPriority("Realtime")
; - 効果：プロセス優先度が最大に設定される
; - 参照元：https://zenn.dev/thinkingsinc/articles/3ee9a6bb35ea55
; - その他の参照元：https://qiita.com/ryoheiszk/items/092cc5d76838cb5a13f1

Persistent                            ; スクリプトを明示的に常駐させる
#SingleInstance Force                 ; 同じスクリプトを再実行した際は、確認なくリロードする
; REMOVED: #NoEnv                     ; 変数の処理においてWindows環境変数の探索をしない（v2では削除されたみたい）
#UseHook                              ; RegisterHotkeyを介さず、フックを使用してホットキーを定義する（処理速度向上のため）
; InstallKeybdHook()                  ;キーボードフックを有効化する（デバッグのため）
; InstallMouseHook()                  ;マウスフックを有効化する（デバッグのため）
; A_HotkeyInterval := 2000            ;無限ループの検出間隔を設定（このままだと機能してなさそう）
; A_MaxHotkeysPerInterval := 200      ;この回数以上のホットキーが上の間隔で行われた場合、無限ループとして警告する（このままだと機能してなさそう）
ProcessSetPriority("Realtime")        ;プロセス優先度を最高にする
SendMode("Input")                     ;SendコマンドのモードをInputにする(処理速度向上のため)
; SetWorkingDir(A_ScriptDir)          ;作業フォルダをAutoHotKey.ahkを含むフォルダとする
; SetTitleMatchMode(2)                  ; WindowTitleは部分一致検索とする

;------------------------------------------------------------------------------
; 定数（旧 parameter.ahk）
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; キーコード早見表（旧 code_list.ahk）
;------------------------------------------------------------------------------
; --------------
; 修飾子一覧
; --------------
; # windowsキー
; ^ Ctrlキー
; + Shiftキー
; ! Altキー

; --------------
; 仮想キーコード一覧
; --------------
; vk1D 無変換キー
; vk1C 変換キー

; --------------
; スキャンコード一覧
; --------------
; sc03A		CapsLockキー
; vk5Dsc15D	右クリック（AppKey）

; ------
; テンキー上キー　スキャンコード一覧
; ------
; NumpadEnter		sc11C
; NumpadAdd			sc04E
; NumpadSub			sc04A
; NumpadMult		sc037
; NumpadDiv			sc135
; NumpadBackspace	sc00E(※　キーボードと共通)
; NumpadEqual 		sc00C
; NumpadTab			sc00F
; NumpadClear		sc001
; Numpad0	sc052
; Numpad1	sc04F
; Numpad2	sc050
; Numpad3	sc051
; Numpad4	sc04B
; Numpad5	sc04C
; Numpad6	sc04D
; Numpad7	sc047
; Numpad8	sc048
; Numpad9	sc049
; NumpadDot	sc053
; NumpadDel	sc053 ※numlockoffでNumpadDotから切り替わる
; Numlock	sc145
; 電卓		sc121
