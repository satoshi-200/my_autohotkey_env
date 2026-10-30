#Requires AutoHotkey v2.0
;==============================================================================
; hold_keys.ahk
; 押しながら使うレイヤー（起点キーを押したまま別のキー）の割り当て表
;   ・変換 (vk1C)   : 記号・テンキー、削除・やり直しなどの入力編集
;   ・無変換 (vk1D) : マウス移動・スクロール、記号、アプリ切り替え・ウィンドウ操作
;   ・Space (vk20)  : カーソル移動、Tab / F6 によるフォーカス移動、Enter、クリック、F2、Esc、
;                     タブ・ページ移動、入力待ちの呼び出し（Space+F / Space+A）など
;   ・変換 → 無変換 + ○ : chord_keys.ahk、無変換 → 変換 + ○ : chord_ordered_keys.ahk（2 つ押したままの 3 キー）
;   キーコードの対応は main.ahk の冒頭を参照
;==============================================================================
#Include %A_LineFile%\..\..\Lib\key_wait.ahk
#Include %A_LineFile%\..\..\Lib\text_input.ahk
#Include %A_LineFile%\..\..\Lib\screen_saver.ahk
#Include %A_LineFile%\..\..\Lib\mouse_cursor.ahk
#Include %A_LineFile%\..\..\Lib\shift_hold.ahk
#Include %A_LineFile%\..\..\Lib\chord.ahk
#Include %A_LineFile%\..\leader_keys.ahk
#Include %A_LineFile%\..\chord_ordered_keys.ahk
#Include %A_LineFile%\..\chord_keys.ahk

; 変換と無変換の 2 キーの組み合わせ（3 キーの割り当て用に、押した順番を記録する）。下の割り当てと違い、両方を押している間も働く
#HotIf !IH_waiting
vk1C & vk1D::   Chord_Begin("CD")                   ; 変換 → 無変換 の順に押した記録（3 キー用。単独では何もしない。処理を割り当てるときは Chord_Begin("CD", 関数)）
vk1D & vk1C::   Chord_Begin("DC")                   ; 無変換 → 変換 の順に押した記録（3 キー用。単独では何もしない。処理を割り当てるときは Chord_Begin("DC", 関数)）

; 入力待ちの間は、このファイルのホットキーをすべて止める。変換と無変換を両方押している間も止める（その間は chord_*.ahk の 3 キーの割り当てだけ。割り当てのないキーは何も起きない）
#HotIf !IH_waiting && !Chord_Both()

;------------------------------------------------------------------------------
; 変換 (vk1C) ＋ 各種キー
;------------------------------------------------------------------------------
; --- 特殊・編集 ---
vk1C & vk20::   SendInput("{Space}")
vk1C & sc03A::  SendInput("{Space}")                ; CapsLock
vk1C & sc00F::  SendInput("^{y}")                   ; Tab -> やり直し
vk1C & LShift:: SendInput("^{z}")                   ; 元に戻す
vk1C & t::      SendInput("{Blind}{Delete}")
vk1C & g::      SendInput("{Blind}{BackSpace}")
vk1C & b::      ShiftHold_SendPlain("{F8}")         ; F8（IME：半角に変換。Shift 長押しモード中も Shift なしで送る）
vk1C & n::      ShiftHold_SendPlain("{F9}")         ; F9（IME：全角に変換。同上）
vk1C & [::      return
vk1C & ]::      return
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
vk1C & `::      return                              ; @（未割り当て）
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
vk1D & LAlt::   return                              ; 左 Alt（未割り当て）
vk1D & sc00F::  SendInput("^{PgUp}")               ; Tab -> 前のページ
vk1D & t::      SendInput("^{PgDn}")               ; 次のページ
vk1D & RAlt::   return                              ; 右 Alt（未割り当て）
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
vk1D & n::      MouseNav_WarpExternalCenter()  ; 外付けモニター 1 ↔ 2 の中央へ（外付けが 1 台以下なら全モニターの中央を巡回）し、カーソル下をアクティブに
vk1D & b::      MouseNav_WarpVertical()  ; かな -> 縦に並んだモニターへ（下にあれば下へ、なければ上へ）の中央へ移動し、カーソル下をアクティブに
vk1D & g::      MouseNav_WarpWindow()               ; アクティブウィンドウの中央へ
vk1D & LShift::      return                              ; 未割り当て
vk1D & sc070::      return                              ; 未割り当て
vk1D & 7::      return                              ; 未割り当て（2 分割ジャンプ MouseNav_Jump* は Lib\archive\mouse_nav_timer.ahk にある）
vk1D & 8::      return                              ; 未割り当て
vk1D & 9::      return                              ; 未割り当て
vk1D & 0::      return                              ; 未割り当て
vk1D & [::      return                              ; 未割り当て
vk1D & ]::      SendInput("{#}")
vk1D & RButton::    SendInput("^{LButton}")
vk1D & WheelUp::    Text_WheelCursor("Left")
vk1D & WheelDown::  Text_WheelCursor("Right")

; --- 矢印 ---
vk1D & z::      SendInput("{Left}")
vk1D & x::      SendInput("{Up}")
vk1D & c::      SendInput("{Down}")
vk1D & v::      SendInput("{Right}")
vk1D & Left::      return                              ; 未割り当て
vk1D & Up::      return                              ; 未割り当て
vk1D & Down::      return                              ; 未割り当て
vk1D & Right::      return                              ; 未割り当て
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
vk1D & ,::      return                              ; 未割り当て
vk1D & .::      return                              ; 未割り当て
vk1D & /::      return                              ; 未割り当て
vk1D & *::      SendInput("{?}")
vk1D & `::      SendInput("{!}")
vk1D & y::      SendInput("{~}")
vk1D & _::      return                              ; 未割り当て
vk1D & RShift::      return                              ; 未割り当て
vk1D & h::      Text_BulletPoint()                  ; 箇条書きの「- 」
vk1D & sc07D::  return
vk1D & sc00D::  return
vk1D & sc058::  LastInput_RecallChar()  ; 直前の 1 文字（記号など）をもう一度入力

;------------------------------------------------------------------------------
; Space (vk20) ＋ 各種キー
;------------------------------------------------------------------------------
; --- 特殊・システム ---
vk20 & vk1C::   SendInput("{Space}")
vk20 & vk1D::   return                              ; 無変換（未割り当て）
vk20 & sc03A::  ShiftHold_Stop(), SendInput("{Escape}"), ScreenSaver_Off()   ; CapsLock -> Esc（Shift 長押しモード・スクリーンセーバー回避も解除）
vk20 & sc00F::  SendInput("^+{Tab}")                ; Tab -> 前のタブへ
vk20 & F1::     ScreenSaver_Toggle()
vk20 & sc070::  SendInput("+{RButton}")  ; shift+右クリック
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
vk20 & `::      SendInput("{Blind}^{Right}")
vk20 & 8::      SendInput("{Blind}^{Left}")
vk20 & 9::      SendInput("{Blind}^{Right}")
vk20 & 7::      SendInput("{Blind}^{Home}")
vk20 & 0::      SendInput("{Blind}^{End}")
vk20 & Up::      return                              ; 未割り当て
vk20 & Down::      return                              ; 未割り当て
vk20 & Right::      return                              ; 未割り当て
vk20 & Left::      return                              ; 未割り当て

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
vk20 & h::      ShiftHold_Enter()                   ; Enter（Shift 長押しモード中は、モードを終えてから送る＝確定して抜ける）
vk20 & g::      ShiftHold_Enter()                   ; Enter（同上）
vk20 & s::      SendInput("{Backspace}")
vk20 & d::      SendInput("{Delete}")
vk20 & *::      SendInput("{F2}")                   ; 名前の変更
vk20 & r::      SendInput("{Tab}")
vk20 & q::      SendInput("+{Tab}")
vk20 & e::      SendInput("{F6}")
vk20 & w::      SendInput("+{F6}")
vk20 & LShift:: return                              ; 左 Shift（未割り当て）
vk20 & RShift::      return                              ; 未割り当て
vk20 & RControl::      return                              ; 未割り当て
vk20 & m::      SendInput("^{LButton}")             ; Ctrl + クリック
vk20 & ,::      MouseClick("Left", , , 2)           ; ダブルクリック
vk20 & .::      MouseClick("Right")                 ; 右クリック
vk20 & /::      return                              ; 未割り当て

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

;------------------------------------------------------------------------------
; 短押し（単独で押して離したとき。「○ & キー」を使ったときは働かない。元のキーの動きは置き換わる）
;   Space は元の空白が入らないので、自分で送る。1 行で書く（キー割り当て一覧が読めるように）
;------------------------------------------------------------------------------
*vk20:: LastInput_SpaceTap()                        ; 空白を入力（Shift / Ctrl などを押していればそのまま付ける：Shift+Space・Ctrl+Space）
vk1C:: ShiftHold_Stop(), Ime_Hiragana()             ; IME をひらがなに（Shift 長押しモードも終える）
vk1D:: ShiftHold_Stop(), Ime_AlnumCommit()          ; IME を半角英数に（未確定の文字は確定。Shift 長押しモードも終える）

#HotIf
