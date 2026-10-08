#Requires AutoHotkey v2.0
;==============================================================================
; hold_keys.ahk
; 押しながら使うレイヤー（起点キーを押したまま別のキー）の割り当て表
;   ・変換 (vk1C)   : 記号・テンキー、削除・やり直しなどの入力編集
;   ・無変換 (vk1D) : マウス移動・スクロール、記号、アプリ切り替え・ウィンドウ操作
;   ・Space (vk20)  : カーソル移動、Tab / F6 によるフォーカス移動、Enter、クリック、F2、Esc、
;                     タブ・ページ移動、入力待ちの呼び出し（Space+F / Space+A）など
;   キーコードの対応は main.ahk の冒頭を参照
;==============================================================================
#Include %A_LineFile%\..\..\Lib\key_wait.ahk
#Include %A_LineFile%\..\..\Lib\text_input.ahk
#Include %A_LineFile%\..\..\Lib\system_utils.ahk
#Include %A_LineFile%\..\..\Lib\mouse_cursor.ahk
#Include %A_LineFile%\..\leader_keys.ahk

; 入力待ちの間は、このファイルのホットキーをすべて止める
#HotIf !isWaitingInput

;------------------------------------------------------------------------------
; 変換 (vk1C) ＋ 各種キー
;------------------------------------------------------------------------------
; --- 特殊・編集 ---
vk1C & vk20::   SendInput("{Space}")
vk1C & sc03A::  SendInput("{Space}")                ; CapsLock
vk1C & vk1D::   return
vk1C & sc00F::  SendInput("^{y}")                   ; Tab -> やり直し
vk1C & LShift:: SendInput("^{z}")                   ; 元に戻す
vk1C & t::      SendInput("{Blind}{Delete}")
vk1C & g::      SendInput("{Blind}{BackSpace}")
vk1C & b::      SendInput("{F8}")
vk1C & n::      SendInput("{F9}")
vk1C & [::      SendInput("^+[")
vk1C & ]::      SendInput("^+]")
vk1C & sc029::  return                              ; 半角/全角（未割り当て）
vk1C & sc070::  return                              ; カタカナひらがな（未割り当て）

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

; --- テンキー (wer / sdf / xcv / z) ---
vk1C & w::      SendInput("{7}")
vk1C & e::      SendInput("{8}")
vk1C & r::      SendInput("{9}")
vk1C & s::      SendInput("{4}")
vk1C & d::      SendInput("{5}")
vk1C & f::      SendInput("{6}")
vk1C & x::      SendInput("{1}")
vk1C & c::      SendInput("{2}")
vk1C & v::      SendInput("{3}")
vk1C & z::      SendInput("{0}")
vk1C & q::      SendInput("{,}")
vk1C & a::      SendInput("{.}")

; --- 計算記号 (1234) ---
vk1C & 1::      SendInput("{/}")
vk1C & 2::      SendInput("{*}")
vk1C & 3::      SendInput("{-}")
vk1C & 4::      SendInput("{+}")

;------------------------------------------------------------------------------
; 無変換 (vk1D) ＋ 各種キー
;------------------------------------------------------------------------------
; --- ウィンドウ・アプリ ---
vk1D & LAlt::   SendInput("{Blind}{m}")
vk1D & sc00F::  SendInput("#+{Right}")              ; Tab -> ウィンドウを右のモニターへ
vk1D & RAlt::   Mouse_FocusUnderCursor()
vk1D & sc03A::  Mouse_FocusUnderCursor()            ; CapsLock
vk1D & 1::      SendInput("#{Up}")                  ; 最大化
vk1D & 2::      ShiftAltTab                         ; 前のアプリへ
vk1D & 3::      AltTab                              ; 次のアプリへ
vk1D & 4::      SendInput("#{Down}")                ; 最小化

; --- マウス ---
vk1D & f::      MousePlain_Right()
vk1D & d::      MousePlain_Down()
vk1D & s::      MousePlain_Up()
vk1D & a::      MousePlain_Left()
vk1D & w::      MousePlain_ScrollUp()
vk1D & e::      MousePlain_ScrollDown()
vk1D & q::      MousePlain_ScrollLeft()
vk1D & r::      MousePlain_ScrollRight()
vk1D & n::      MouseClick()
vk1D & b::      MouseClick()
vk1D & g::      MouseNav_WarpWindow()               ; アクティブウィンドウの中央へ
vk1D & LShift:: MouseNav_WarpCenter()               ; モニターの中央へ
vk1D & vk1C::   MouseNav_WarpExternalCenter()       ; 外付けモニター 1 ↔ 2 の中央へ移動し、カーソル下をアクティブに
vk1D & sc070::  MouseNav_WarpMonitor()              ; かな -> 次のモニターへ
vk1D & 7::      MouseNav_JumpLeft()
vk1D & 8::      MouseNav_JumpUp()
vk1D & 9::      MouseNav_JumpDown()
vk1D & 0::      MouseNav_JumpRight()
vk1D & [::      SendInput("^{WheelUp}")
vk1D & ]::      SendInput("^{WheelDown}")
vk1D & RButton::    SendInput("^{LButton}")
vk1D & WheelUp::    Text_WheelCursor("Left")
vk1D & WheelDown::  Text_WheelCursor("Right")

; --- 矢印 ---
vk1D & z::      SendInput("{Left}")
vk1D & x::      SendInput("{Up}")
vk1D & c::      SendInput("{Down}")
vk1D & v::      SendInput("{Right}")
vk1D & Left::   SendInput("^{Left}")
vk1D & Up::     SendInput("^{Up}")
vk1D & Down::   SendInput("^{Down}")
vk1D & Right::  SendInput("^{Right}")
vk1D & F9::     SendInput("^{Left}")
vk1D & F10::    SendInput("^{Up}")
vk1D & F11::    SendInput("^{Down}")
vk1D & F12::    SendInput("^{Right}")
vk1D & 6::      return

; --- 記号・入力 ---
vk1D & j::      SendInput("{_}")
vk1D & k::      SendInput("{,}")
vk1D & l::      SendInput("{.}")
vk1D & +::      SendInput("{=}")
vk1D & u::      SendInput("{/}")
vk1D & i::      SendInput("{*}")
vk1D & o::      SendInput("{-}")
vk1D & p::      SendInput("{+}")
vk1D & m::      SendInput("{#}")
vk1D & ,::      SendInput("{$}")
vk1D & .::      SendInput("{%}")
vk1D & /::      SendInput("{&}")
vk1D & *::      SendInput("{?}")
vk1D & @::      SendInput("{!}")
vk1D & y::      SendInput("{~}")
vk1D & _::      SendInput("{~}")
vk1D & RShift:: SendInput("{|}")
vk1D & h::      Text_BulletPoint()                  ; 箇条書きの「- 」
vk1D & sc07D::  SendInput("{- 30}")                 ; ￥ -> コメント用の区切り線
vk1D & sc00D::  return

;------------------------------------------------------------------------------
; Space (vk20) ＋ 各種キー
;------------------------------------------------------------------------------
; --- 特殊・システム ---
vk20 & vk1C::   SendInput("{Space}")
vk20 & vk1D::   Mouse_ToggleDrag()                  ; ドラッグ開始／解除
vk20 & sc03A::  SendInput("{Escape}"), ScreenSaver_Off()   ; CapsLock -> Esc（スクリーンセーバー回避も解除）
vk20 & sc00F::  SendInput("^+{Tab}")                ; Tab -> 前のタブへ
vk20 & F1::     ScreenSaver_Toggle()
vk20 & sc070::  Text_CapitalizeNext()               ; かな -> 次の 1 文字を大文字に
vk20 & f::      Leader_SpaceF()
vk20 & a::      Leader_SpaceA()

; --- カーソル移動 ---
vk20 & j::      SendInput("{Blind}{Left}")
vk20 & k::      SendInput("{Blind}{Up}")
vk20 & l::      SendInput("{Blind}{Down}")
vk20 & +::      SendInput("{Blind}{Right}")
vk20 & u::      SendInput("{Blind}{Home}")
vk20 & p::      SendInput("{Blind}{End}")
vk20 & y::      SendInput("{Blind}^{Left}")
vk20 & @::      SendInput("{Blind}^{Right}")
vk20 & 8::      SendInput("{Blind}^{Left}")
vk20 & 9::      SendInput("{Blind}^{Right}")
vk20 & 7::      SendInput("{Blind}^{Home}")
vk20 & 0::      SendInput("{Blind}^{End}")
vk20 & Up::     SendInput("+{Up}")
vk20 & Down::   SendInput("+{Down}")
vk20 & Right::  SendInput("+{Right}")
vk20 & Left::   SendInput("+{Left}")

; --- マウス・スクロール ---
vk20 & i::      MousePlain_ScrollUp()
vk20 & o::      MousePlain_ScrollDown()
vk20 & n::      MouseClick()
vk20 & b::      MouseClick()
vk20 & RButton::    MouseClick()
vk20 & LButton::    SendInput("{WheelDown}")
vk20 & WheelUp::    Text_WheelCursor("Up")
vk20 & WheelDown::  Text_WheelCursor("Down")
vk20 & PgUp::   SendInput("{WheelUp 6}")
vk20 & PgDn::   SendInput("{WheelDown 6}")

; --- 編集・フォーカス ---
vk20 & h::      SendInput("{Enter}")
vk20 & g::      SendInput("{Enter}")
vk20 & s::      SendInput("{Backspace}")
vk20 & d::      SendInput("{Delete}")
vk20 & *::      SendInput("{F2}")                   ; 名前の変更
vk20 & r::      SendInput("{Tab}")
vk20 & q::      SendInput("+{Tab}")
vk20 & e::      SendInput("{F6}")
vk20 & w::      SendInput("+{F6}")
vk20 & LShift:: SendInput("^{z}")
vk20 & RShift:: SendInput("{Blind}+{Space}")
vk20 & RControl:: SendInput("{Blind}^{Space}")
vk20 & m::      return
vk20 & ,::      return
vk20 & .::      return
vk20 & /::      return

; --- ウィンドウ・タブ ---
vk20 & z::      SendInput("!{Left}")
vk20 & x::      SendInput("!{Up}")
vk20 & c::      SendInput("!{Down}")
vk20 & v::      SendInput("!{Right}")
vk20 & t::      SendInput("^{Tab}")                 ; 次のタブへ
vk20 & 1::      SendInput("^+{PgUp}")
vk20 & 2::      SendInput("^{PgUp}")                ; 前のページ
vk20 & 3::      SendInput("^{PgDn}")                ; 次のページ
vk20 & 4::      SendInput("^+{PgDn}")

#HotIf
