; ==============================================================================
; 【AutoHotkey v2 メイン・設定スクリプト】
;
; ●キー対応表 (JISキーボード基準)
;   ・vk1C : [変換] キー
;   ・vk1D : [無変換] キー
;   ・vk20 : [Space] キー
;   ・sc03A: [CapsLock] キー
;   ・sc070: [カタカナひらがな] キー
;   ・sc00F: [Tab] キー
;   ・sc029: [半角/全角] キー
;
; ●主なレイヤー構成（代表的な機能）
;   ・変換 (vk1C)     : 記号・テンキー、削除・やり直し等の入力編集
;   ・無変換 (vk1D)   : マウス移動・スクロール、記号、アプリ切替・ウィンドウ操作
;   ・Space (vk20)    : カーソル移動、Tab/F6によるフォーカス移動、Enter、左右クリック、F2(リネーム)、Esc、
;                       タブ・ページ移動、修飾キー付Enter、InputHook階層呼出 など
;   ・CapsLock/かな   : InputHookによる階層（レイヤー）呼び出し
;
;   ※上記は代表的な設定であり、他にも多岐にわたる機能を割り当てています。
;
; ●メンテナンス
;   ・Insertキーでスクリプトのリロードを実行します。
;   ・各機能は Lib フォルダ内のライブラリに依存しています。
; ==============================================================================

; ------------------------------------------------------------------------------
; ライブラリの読み込み (Imports)
; ------------------------------------------------------------------------------
#Include Lib\IME.ahk
#Include Lib\IME_wrapper.ahk
#Include Lib\hotstring.ahk
#Include Lib\launch_execute.ahk
#Include Lib\char_input_assist.ahk
#Include Lib\vscode.ahk
#Include Lib\parameter.ahk
#Include Lib\global_settings.ahk
#Include Lib\InputHook.ahk
#Include Lib\screen_saver.ahk
#Include Lib\mouse_cursor.ahk
#Include Lib\text_cursor.ahk
#Include Lib\os_operate_assist.ahk
#Include Lib\test_scripts.ahk
#Include Lib\multi_clipboard.ahk

; ------------------------------------------------------------------------------
; レイヤー：変換キー (vk1C) ＋ 各種キー
; ------------------------------------------------------------------------------

; --- 特殊・編集 ---
vk1C & vk20::   SendInput("{Space}")        ; 変換 + Space -> Space
vk1C & sc03A::  SendInput("{Space}")        ; 変換 + CapsLock -> Space
vk1C & vk1D::   return
vk1C & sc00F::  SendInput("^{y}")           ; 変換 + Tab -> やり直し (Redo)
vk1C & LShift:: SendInput("^{z}")           ; 変換 + LShift -> 元に戻す (Undo)
vk1C & t::      SendInput("{Blind}{Delete}")    ; 変換 + t -> Delete
vk1C & g::      SendInput("{Blind}{BackSpace}") ; 変換 + g -> BackSpace
vk1C & b::      SendInput("{F8}")           ; 変換 + b -> F8

; --- 記号 (jkl / uiop) ---
vk1C & j::      SendInput("{(}")
vk1C & +::      SendInput("{)}")
vk1C & k::      SendInput("{[}")
vk1C & l::      SendInput("{]}")
vk1C & u::      SendInput("{<}")
vk1C & p::      SendInput("{>}")
vk1C & i::      SendInput("{{}")
vk1C & o::      SendInput("{}}")
vk1C & *::      SendInput("{'}")
vk1C & `::      SendInput("{/}")
vk1C & h::      SendInput("{`"}")

; --- テンキー・数値 (fdsa / rewq / vcxz) ---
vk1C & w::      SendInput("{7}")
vk1C & e::      SendInput("{8}")
vk1C & r::      SendInput("{9}")
vk1C & q::      SendInput("{,}")
vk1C & s::      SendInput("{4}")
vk1C & d::      SendInput("{5}")
vk1C & f::      SendInput("{6}")
vk1C & a::      SendInput("{.}")
vk1C & x::      SendInput("{1}")
vk1C & c::      SendInput("{2}")
vk1C & v::      SendInput("{3}")
vk1C & z::      SendInput("{0}")

; --- 計算記号 (1234) ---
vk1C & 4::      SendInput("{+}")
vk1C & 3::      SendInput("{-}")
vk1C & 2::      SendInput("{*}")
vk1C & 1::      SendInput("{/}")

; --- その他 ---
vk1C & n::      SendInput("{F9}")
vk1C & [::      SendInput("^+[")
vk1C & ]::      SendInput("^+]")
vk1C & sc029::  return                      ; 半角/全角 (未割当)
vk1C & sc070::  return                      ; カタカナひらがな (未割当)

; ------------------------------------------------------------------------------
; レイヤー：無変換キー (vk1D) ＋ 各種キー
; ------------------------------------------------------------------------------

; --- 特殊・システム ---
vk1D & vk20::   ToggleClick()               ; 無変換 + Space -> クリック状態切替
vk1D & LAlt::   SendInput("{Blind}{m}")     ; 無変換 + LAlt -> m
vk1D & sc00F::  SendInput("#+{Right}")      ; 無変換 + Tab -> ウィンドウを右モニタへ
vk1D & sc03A::  SendInput("{Space}")        ; 無変換 + CapsLock -> Space
vk1D & sc070::  Jump_to_center_display4()   ; 無変換 + かな -> 第4画面中央へ移動
vk1D & RAlt::   FocusUnderCursor()          ; 無変換 + RAlt -> カーソル下のウィンドウにフォーカス
vk1D & 3::      AltTab                      ; 無変換 + 3 -> 次のアプリへ
vk1D & 2::      ShiftAltTab                 ; 無変換 + 2 -> 前のアプリへ
vk1D & 4::      SendInput("#{Down}")        ; 無変換 + 4 -> ウィンドウ最小化
vk1D & 1::      SendInput("#{Up}")          ; 無変換 + 1 -> ウィンドウ最大化

; --- マウスエミュレート ---
vk1D & WheelUp::    Text_cursor_move_left_by_using_mouse_wheel()  ; ホイール上 -> カーソル左
vk1D & WheelDown::  Text_cursor_move_right_by_using_mouse_wheel() ; ホイール下 -> カーソル右
vk1D & RButton::    SendInput("{MButton}")  ; 右クリック -> 中央クリック
vk1D & r::      SendInput("{WheelRight 1}")
vk1D & e::      SendInput("{WheelDown 1}")
vk1D & w::      SendInput("{WheelUp 1}")
vk1D & q::      SendInput("{WheelLeft 1}")
vk1D & n::      MouseClick()                ; n -> マスクリック
vk1D & g::      FocusUnderCursor()
vk1D & b::      MouseClick()

; --- カーソル移動 (fdsa / vcxc) ---
vk1D & f::      MoveCursorToRight()
vk1D & d::      MoveCursorToDown()
vk1D & s::      MoveCursorToUp()
vk1D & a::      MoveCursorToLeft()
vk1D & v::      SendInput("{Right}")
vk1D & z::      SendInput("{Left}")
vk1D & x::      SendInput("{up}")
vk1D & c::      SendInput("{down}")

; --- 記号・入力 ---
vk1D & j::      SendInput("{_}")
vk1D & k::      SendInput("{,}")
vk1D & l::      SendInput("{.}")
vk1D & +::      SendInput("{=}")
vk1D & u::      SendInput("{/}")
vk1D & i::      SendInput("{*}")
vk1D & p::      SendInput("{+}")
vk1D & o::      SendInput("{-}")
vk1D & m::      SendInput("{#}")
vk1D & ,::      SendInput("{$}")
vk1D & .::      SendInput("{%}")
vk1D & /::      SendInput("{&}")
vk1D & h::      Bullet_points()             ; h -> 箇条書き記号
vk1D & *::      SendInput("{?}")
vk1D & @::      SendInput("{!}")            
vk1D & y::      SendInput("{~}")
vk1D & [::      SendInput("{\}")
vk1D & ]::      SendInput("{^}")
vk1D & _::      SendInput("{~}")
vk1D & RShift:: SendInput("{|}")
vk1D & sc00D::  SendInput(obsidian_folderlink_templete) ; Obsidianリンク
vk1D & sc07D::  SendInput("{- 30}")         ; コメント用ライン (---)

; --- shift+矢印(powerpoint 図形編集) ---
vk1D & 6::      return
vk1D & 7::      SendInput("+{Left}")
vk1D & 8::      SendInput("+{Up}")
vk1D & 9::      SendInput("+{Down}")
vk1D & 0::      SendInput("+{Right}")

; --- Ctrl+矢印(powerpoint 図形編集、その他) ---
vk1D & F9::     SendInput("^{Left}")
vk1D & F10::    SendInput("^{Up}")
vk1D & F11::    SendInput("^{Down}")
vk1D & F12::    SendInput("^{Right}")

; ------------------------------------------------------------------------------
; レイヤー：Spaceキー (vk20) ＋ 各種キー
; ------------------------------------------------------------------------------

; --- 特殊・システム ---
vk20 & vk1C::   SendInput("{Space}")        ; Space + 変換 -> Space
vk20 & vk1D::   ToggleClick()               ; Space + 無変換 -> クリック状態切替
vk20 & sc03A::  SendInput("{Escape}")       ; Space + CapsLock -> Escape
vk20 & sc00F::  SendInput("^+{Tab}")        ; Space + Tab -> 前のタブへ
vk20 & F1::     Popup_Screen_saver()        ; Space + F1 -> スクリーンセーバー
vk20 & sc070::  Capitalize_next_character_you_type() ; 次の文字を大文字に

; --- カーソル・スクロール移動 (jkl+ / uiop / 矢印) ---
vk20 & j::      SendInput("{Blind}{Left}")
vk20 & l::      SendInput("{Blind}{Down}")
vk20 & k::      SendInput("{Blind}{Up}")
vk20 & +::      SendInput("{Blind}{Right}")
vk20 & u::      SendInput("{Blind}{Home}")
vk20 & p::      SendInput("{Blind}{End}")
vk20 & 8::      SendInput("^{Left}")
vk20 & 9::      SendInput("^{Right}")
vk20 & 7::      SendInput("^{Home}")
vk20 & 0::      SendInput("^{End}")
vk20 & Up::     SendInput("{WheelUp 3}")
vk20 & Down::   SendInput("{WheelDown 3}")
vk20 & Right::  SendInput("{WheelRight 3}")
vk20 & Left::   SendInput("{WheelLeft 3}")
vk20 & PgUp::   SendInput("{{WheelUp 6}")
vk20 & PgDn::   SendInput("{WheelDown 6}")

; --- マウスエミュレート ---
vk20 & WheelUp::    Text_cursor_move_up_by_using_mouse_wheel()
vk20 & WheelDown::  Text_cursor_move_down_by_using_mouse_wheel()
vk20 & RButton::    MouseClick()
vk20 & LButton::    SendInput("{WheelDown}")
vk20 & n::      MouseClick()
vk20 & y::      SendInput("^{LButton}")
vk20 & @::      SendInput("{RButton}")
vk20 & b::      MouseClick()
vk20 & i::      SendInput("{WheelUp 1}")
vk20 & o::      SendInput("{WheelDown 1}")

; --- 編集・入力補助 ---
vk20 & h::      SendInput("{Enter}")
vk20 & g::      SendInput("{Enter}")
vk20 & m::      SendInput("+{Enter}")
vk20 & ,::      SendInput("^{Enter}")
vk20 & .::      SendInput("!{Enter}")
vk20 & s::      SendInput("{Backspace}")
vk20 & d::      SendInput("{Delete}")
vk20 & *::      SendInput("{F2}")           ; 名前変更
vk20 & r::      SendInput("{Tab}")
vk20 & q::      SendInput("+{Tab}")
vk20 & e::      SendInput("{F6}")
vk20 & w::      SendInput("+{F6}")

; --- ウィンドウ・タブ操作 (vcxz / 1234) ---
vk20 & z::      SendInput("!{Left}")
vk20 & v::      SendInput("!{Right}")
vk20 & x::      SendInput("!{Up}")
vk20 & c::      SendInput("!{Down}")
vk20 & t::      SendInput("^{Tab}")         ; 次のタブへ
vk20 & 2::      SendInput("^{PgUp}")        ; 前のページ
vk20 & 3::      SendInput("^{PgDn}")        ; 次のページ
vk20 & 1::      SendInput("^+{PgUp}")
vk20 & 4::      SendInput("^+{PgDn}")

; --- 拡張入力 (InputHook) ---
vk20 & f::      WaitForKeyInput_for_Space_and_f_1level()
vk20 & a::      WaitForKeyInput_Input_letter_only_lefthand_and_symbols()

; --- その他 ---
vk20 & LShift::   SendInput("^{z}")
vk20 & RShift::   SendInput("{Blind}^{Space}") ; Ctrl + Space
vk20 & RCtrl::    SendInput("{Blind}+{Space}") ; Shift + Space

; ------------------------------------------------------------------------------
; 単独キー・InputHook階層呼び出し
; ------------------------------------------------------------------------------

; CapsLock -> InputHook階層へ
sc03A:: WaitForKeyInput_for_Caps_1level()

; カタカナひらがな -> 拡張入力へ
sc070:: WaitForKeyInput_kata_hira_romeji()

; Insert -> スクリプトの再読み込み
Insert:: Reload

#SuspendExempt
; Suspend対象外の設定
#SuspendExempt
