#Requires AutoHotkey v2.0
;==============================================================================
; config.ahk
; スクリプト全体の動作設定・共通の定数・キーコードの早見表
;==============================================================================

;--- 動作設定 -------------------------------------------------------------------
Persistent                                ; 常駐させる
#SingleInstance Force                     ; 再実行したら確認なしで入れ替える
#UseHook                                  ; RegisterHotkey を使わず、フックでホットキーを定義する（反応速度のため）
ListLines False
KeyHistory 0
ProcessSetPriority("High")
SendMode("Input")
CoordMode("Mouse", "Screen")
DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")  ; Per-Monitor v2：座標を物理ピクセルで扱う

;--- 共通の定数 -----------------------------------------------------------------
TOOLTIP_DURATION_MS := 1000               ; 完了・状態表示のツールチップを消すまでの時間
TOOLTIP_FONT_SIZE   := 9                  ; ツールチップの文字の大きさ（pt。Windows 標準は 9）
IME_TIP_MS          := 700                ; 変換・無変換で IME を切り替えたときの表示を消すまでの時間（0 で表示しない）

; ツールチップの番号（同時に出る表示が消し合わないように分ける。1 は入力待ちなどの一時表示）
TIP_ID_SHIFTHOLD := 18                    ; Shift 長押しモードの表示（出し続ける）
TIP_ID_CAPTURE   := 19                    ; 画面キャプチャの選択中の案内
TIP_ID_UI        := 20                    ; UI_Tip（完了の短い知らせ）

;--- キーコード早見表 -----------------------------------------------------------
; 修飾子：# Win　^ Ctrl　+ Shift　! Alt
; vk1C 変換　vk1D 無変換　vk20 Space　sc03A CapsLock　sc070 カタカナひらがな
; sc00F Tab　sc029 半角/全角　vk5Dsc15D アプリケーションキー（右クリックメニュー）
;
; テンキーのスキャンコード
;   NumpadEnter sc11C　NumpadAdd sc04E　NumpadSub sc04A　NumpadMult sc037　NumpadDiv sc135
;   Numpad0 sc052　Numpad1 sc04F　Numpad2 sc050　Numpad3 sc051　Numpad4 sc04B
;   Numpad5 sc04C　Numpad6 sc04D　Numpad7 sc047　Numpad8 sc048　Numpad9 sc049
;   NumpadDot / NumpadDel sc053（NumLock オフで切り替わる）　NumLock sc145　電卓 sc121
;   NumpadBackspace sc00E　NumpadEqual sc00C　NumpadTab sc00F　NumpadClear sc001（キーボードと共通）
