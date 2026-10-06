#Requires AutoHotkey v2.0
;==============================================================================
; text_input.ahk
; 文字入力の補助（IME の切り替え・大文字化・定型文や日付の入力・テキストカーソル移動）
;   旧 IME_wrapper.ahk / char_input_assist.ahk / hotstring.ahk / text_cursor.ahk を統合
;   ※ IME_SET / IME_GET は IME.ahk で定義
;==============================================================================
#Include %A_LineFile%\..\IME.ahk

;------------------------------------------------------------------------------
; IME の入力モード切り替え（旧 IME_wrapper.ahk）
;------------------------------------------------------------------------------
; VK_IME_ON / VK_IME_OFF：現在の状態に関係なく IME を ON / OFF にする（Microsoft IME など対応 IME のみ）
turn_on_hiragana_input_mode(){
    SendInput("{vk16}")
}

turn_on_roman_input_mode(){
    SendInput("{vk1A}")
}

toggle_input_mode(){
    SendInput("{vkF3sc029}")
}

;------------------------------------------------------------------------------
; Shift 入力モード・大文字化・CapsLock・箇条書き（旧 char_input_assist.ahk）
;------------------------------------------------------------------------------
global input_shift_mode := false

#HotIf input_shift_mode
; vk1D & sc03A:: Turnoff_input_shift_mode()   ;Capslock 
; vk1D & vk1C:: Turnoff_input_shift_mode()  ;変換
; vk1D & a:: SendInput("+{a}")
; vk1D & b:: SendInput("+{b}")
; vk1D & c:: SendInput("+{c}")
; vk1D & d:: SendInput("+{d}")
; vk1D & e:: SendInput("+{e}")
; vk1D & f:: SendInput("+{f}")
; vk1D & g:: SendInput("+{g}")
; vk1D & h:: SendInput("+{h}")
; vk1D & i:: SendInput("+{i}")
; vk1D & j:: SendInput("+{j}")
; vk1D & k:: SendInput("+{k}")
; vk1D & l:: SendInput("+{l}")
; vk1D & m:: SendInput("+{m}")
; vk1D & n:: SendInput("+{n}")
; vk1D & o:: SendInput("+{o}")
; vk1D & p:: SendInput("+{p}")
; vk1D & q:: SendInput("+{q}")
; vk1D & r:: SendInput("+{r}")
; vk1D & s:: SendInput("+{s}")
; vk1D & t:: SendInput("+{t}")
; vk1D & u:: SendInput("+{u}")
; vk1D & v:: SendInput("+{v}")
; vk1D & w:: SendInput("+{w}")
; vk1D & x:: SendInput("+{x}")
; vk1D & y:: SendInput("+{y}")
; vk1D & z:: SendInput("+{z}")
; vk1D & 1:: SendInput("+{1}")
; vk1D & 2:: SendInput("+{2}")
; vk1D & 3:: SendInput("+{3}")
; vk1D & 4:: SendInput("+{4}")
; vk1D & 5:: SendInput("+{5}")
; vk1D & 6:: SendInput("+{6}")
; vk1D & 7:: SendInput("+{7}")
; vk1D & 8:: SendInput("+{8}")
; vk1D & 9:: SendInput("+{9}")

#HotIf

Turnon_input_shift_mode(){
    global input_shift_mode := true
}

Turnoff_input_shift_mode(){
    global input_shift_mode := false
}

Capitalize_next_character_you_type(){       ;次に入力する文字を大文字にする
    ihChar := InputHook("L1 M"), ihChar.Start(), ihChar.Wait(), Char := ihChar.Input    ; 一文字だけを待ち受ける
    Char := Chr(Ord(Char) - 32)                                                         ; 小文字を大文字に変換
    SendInput(Char)                                                                          ; 大文字で送信
    return
}

;------------------------------------------------------------------------------
; 大文字入力モード（Caps → 無変換 から呼ぶ）
;   英字キーを Shift 付きで送る（Shift を押しながら打つのと同じで、IME の未確定文字になる）。
;   数字・記号はそのまま入力してモードを続ける。
;   Esc / Caps / 無変換 / 変換：終了のみ　Space・Enter・BS などほかのキー：終了してそのキーを入力
;   無変換 / 変換 / Space は leader_keys.ahk のホットキーから UpperMode_Stop() を呼ぶ
;------------------------------------------------------------------------------
UpperMode_hook := 0

UpperMode_IsOn() => UpperMode_hook && UpperMode_hook.InProgress
UpperMode_Stop() => UpperMode_IsOn() && UpperMode_hook.Stop()

UpperMode_Start() {
  global UpperMode_hook, isWaitingInput := true   ; 待機中はほかのレイヤーを止める
  SetTimer(IH_TipClear, 0)

  h := InputHook("L0 V")                          ; 指定しないキーはそのまま入力させる
  h.MinSendLevel := 1                             ; 自分で送った Shift+英字を拾って無限ループしないように
  h.KeyOpt("{All}", "E")                          ; ほかのキーは押したら終了（キーはそのまま届く）
  ; {All} は VK と SC の両方に付くので、外すときも両方から外す
  opt(vk, o) => h.KeyOpt(Format("{{}vk{:X}{}}{{}sc{:X}{}}", vk, GetKeySC(Format("vk{:X}", vk))), o)
  for vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]  ; Shift / Ctrl / Alt / Win
    opt(vk, "-E")
  loop 10                                         ; 数字
    opt(0x2F + A_Index, "-E")
  for vk in [0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE, 0xE2]  ; 記号
    opt(vk, "-E")
  loop 26                                         ; 英字：止めて OnKeyDown で Shift+英字を送る
    opt(0x40 + A_Index, "-E +S +N")
  h.KeyOpt("{Esc}{sc03A}", "+E +S")               ; 終了のみ（キーは送らない）
  h.OnKeyDown := _UpperMode_OnKey

  UpperMode_hook := h
  ToolTip("🔠 [大文字モード] 英字を大文字で入力"
    . "`nEsc / Caps / 無変換 / 変換：終了　Space・Enter など：終了してそのキーを入力")
  h.Start()
  h.Wait()
  isWaitingInput := false

  ToolTip("🔡 [大文字モード] 終了")
  SetTimer(IH_TipClear, -tooltipDuration)
}

_UpperMode_OnKey(h, vk, sc) {
  if (GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin")) {
    h.Stop()                                      ; Ctrl+C などは終了して通常のショートカットとして送る
    SendInput("{Blind}{vk" Format("{:X}", vk) "}")
    return
  }
  SendInput("+{vk" Format("{:X}", vk) "}")
}
Toggle_capslock_on_off(){                   ;capslock on/off 切り替え
    SetCapsLockState(!GetKeyState("CapsLock", "T")) ;
}

Turnon_capslock(){
    SetCapsLockState(true)
}

Turnoff_capslock(){
    SetCapsLockState(false)
}

Bullet_points(){
    if(IME_GET() = 0){
        IME_SET(0)
        SendInput("{-}")
        SendInput("{Space}")
        Sleep(50)           ; - の後のスペースが全角になるのを防ぐため
        IME_SET(0)
    }
    else{
        IME_SET(0)
        SendInput("{-}")
        SendInput("{Space}")
        Sleep(50)           ; - の後のスペースが全角になるのを防ぐため
        IME_SET(1)
    }
}

; Input_char_without_switching_IME(char){
;   if(IME_GET() = 0){
;       IME_SET(0)
;       SendInput(char)
;       SendInput("{Space}")
;       Sleep(50)           ; - の後のスペースが全角になるのを防ぐため
;       IME_SET(0)
;   }
;   else{
;       IME_SET(0)
;       SendInput(char)
;       SendInput("{Space}")
;       Sleep(50)           ; - の後のスペースが全角になるのを防ぐため
;       IME_SET(1)
;   }
; }

;------------------------------------------------------------------------------
; 定型文・日付の入力（旧 hotstring.ahk）
;------------------------------------------------------------------------------
Paste_string(signature){					;指定した文字列をpasteする
	A_Clipboard := signature
	SendInput("^v")
}

SendInput_char_without_switching_IME(char){
	if(IME_GET() = 0){
		IME_SET(0)
		SendInput(char)
		Sleep(100) 			; - の後のスペースが全角になるのを防ぐため
		IME_SET(0)
	}
	else{
		IME_SET(0) 
		SendInput(char)
		Sleep(100) 			; - の後のスペースが全角になるのを防ぐため
		IME_SET(1)
	}
}


Input_current_Date1(){						;現在の日付時刻を入力する（yyyy/MM/dd HH:mm:ss形式）
	CurrentDateTime := FormatTime(, "yyyy/MM/dd HH:mm:ss")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date2(){						;現在の日付を入力する（yyyy/MM/dd形式）
	CurrentDateTime := FormatTime(, "yyyy/MM/dd")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date3(){						;現在の日付を入力する（yy/MM/dd形式）
	CurrentDateTime := FormatTime(, "yy/MM/dd")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date4(){						;現在の日付を入力する（yyyyMMdd形式）
	CurrentDateTime := FormatTime(, "yyyyMMdd")
	SendInput_char_without_switching_IME(CurrentDateTime)
}
Input_current_Date5(){						;現在の日付を入力する　obsidian_pagetitle用　　（yyyyMMdd_形式）
	CurrentDateTime0 := FormatTime(, "yyMMdd_")
	SendInput_char_without_switching_IME(CurrentDateTime0) ;現在の日時を入力する
}
Input_current_Time1(){						;現在の時刻を入力する(HH:mm)
	CurrentDateTimeSub := FormatTime(, "HH:mm")
	SendInput_char_without_switching_IME(CurrentDateTimeSub) ;現在の日時を入力する
}

;------------------------------------------------------------------------------
; マウスホイールでテキストカーソルを動かす（旧 text_cursor.ahk）
;------------------------------------------------------------------------------
sleep_timer_for_text_cursor := 20

Text_cursor_move_down_by_using_mouse_wheel()    ;
{
    Sleep(sleep_timer_for_text_cursor)
    SendInput("{Blind}{Down}")
    Sleep(sleep_timer_for_text_cursor)
}

Text_cursor_move_up_by_using_mouse_wheel()    ;
{
    Sleep(sleep_timer_for_text_cursor)
    SendInput("{Blind}{Up}")
    Sleep(sleep_timer_for_text_cursor)
}

Text_cursor_move_right_by_using_mouse_wheel()    ;
{
    Sleep(sleep_timer_for_text_cursor)
    SendInput("{Blind}{right}")
    Sleep(sleep_timer_for_text_cursor)
}

Text_cursor_move_left_by_using_mouse_wheel()    ;
{
    Sleep(sleep_timer_for_text_cursor)
    SendInput("{Blind}{left}")
    Sleep(sleep_timer_for_text_cursor)
}
