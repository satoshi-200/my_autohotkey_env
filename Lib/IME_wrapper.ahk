#Requires AutoHotkey v2.0
#Include IME.ahk

turn_on_hira_input_mode(){
    SendInput("{vkF3sc029}")
    ; Sleep(1)
    IME_SET(0)
    ; Sleep(10)
}

turn_on_roman_input_mode(){
    SendInput("{vkF3sc029}")
    ; Sleep(1)
    IME_SET(1)
    ; Sleep(10)
}

toggle_input_mode(){
    SendInput("{vkF3sc029}")
}
