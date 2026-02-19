#Requires AutoHotkey v2.0

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