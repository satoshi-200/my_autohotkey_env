#Requires AutoHotkey v2.0

global input_shift_mode := false

#HotIf input_shift_mode
vk1D & sc03A:: Turnoff_input_shift_mode()   ;Capslock 
; vk1D & vk1C:: Turnoff_input_shift_mode()  ;変換
vk1D & a:: SendInput("+{a}")
vk1D & b:: SendInput("+{b}")
vk1D & c:: SendInput("+{c}")
vk1D & d:: SendInput("+{d}")
vk1D & e:: SendInput("+{e}")
vk1D & f:: SendInput("+{f}")
vk1D & g:: SendInput("+{g}")
vk1D & h:: SendInput("+{h}")
vk1D & i:: SendInput("+{i}")
vk1D & j:: SendInput("+{j}")
vk1D & k:: SendInput("+{k}")
vk1D & l:: SendInput("+{l}")
vk1D & m:: SendInput("+{m}")
vk1D & n:: SendInput("+{n}")
vk1D & o:: SendInput("+{o}")
vk1D & p:: SendInput("+{p}")
vk1D & q:: SendInput("+{q}")
vk1D & r:: SendInput("+{r}")
vk1D & s:: SendInput("+{s}")
vk1D & t:: SendInput("+{t}")
vk1D & u:: SendInput("+{u}")
vk1D & v:: SendInput("+{v}")
vk1D & w:: SendInput("+{w}")
vk1D & x:: SendInput("+{x}")
vk1D & y:: SendInput("+{y}")
vk1D & z:: SendInput("+{z}")
vk1D & 1:: SendInput("+{1}")
vk1D & 2:: SendInput("+{2}")
vk1D & 3:: SendInput("+{3}")
vk1D & 4:: SendInput("+{4}")
vk1D & 5:: SendInput("+{5}")
vk1D & 6:: SendInput("+{6}")
vk1D & 7:: SendInput("+{7}")
vk1D & 8:: SendInput("+{8}")
vk1D & 9:: SendInput("+{9}")

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

