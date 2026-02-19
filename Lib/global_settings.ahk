; ---
; 参考
; ---
; ProcessSetPriority("Realtime")
; - 効果：プロセス優先度が最大に設定される
; - 参照元：https://zenn.dev/thinkingsinc/articles/3ee9a6bb35ea55
; - その他の参照元：https://qiita.com/ryoheiszk/items/092cc5d76838cb5a13f1

#Requires AutoHotkey v2.0

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