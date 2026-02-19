#Requires AutoHotkey v2.0

; ディスプレイの中心座標を設定
global display1 := {x: 960, y: 540} ; ディスプレイ1の中心座標（例: 1920x1080の解像度）
global display2 := {x: 960, y: 540} ; ディスプレイ2の中心座標（例: 1920x1080の解像度）
global display3 := {x: 960, y: 540} ; ディスプレイ3の中心座標（例: 1920x1080の解像度）
; 現在のディスプレイを追跡する変数
global currentDisplay := 1

Get_cursor_xy_pos()                 ; マウスカーソルの現在位置を取得
{ ; V1toV2: Added bracket
    MouseGetPos(&xpos, &ypos)
    ; ポップアップで座標を表示
    MsgBox("マウスカーソルの位置: X" xpos " Y" ypos)
    return
}

move_mouse_cursor_to_right(){
    MouseGetPos(&xpos, &ypos)
    xpos += 10
    MouseMove(xpos, ypos, 1)
    Sleep(5)
}

move_mouse_cursor_to_left(){
    ; MouseGetPos(&xpos, &ypos)
    ; xpos -= 10
    ; MouseMove(xpos, ypos, 1)
    ; Sleep(5)

    ; CoordMode("Mouse", "Screen")
    ; MouseGetPos(&xpos, &ypos)
    ; MouseMove(xpos-10, ypos, 0)

    CoordMode("Mouse", "Screen")
    MouseGetPos(&xpos, &ypos)
    MonitorCount := MonitorGetCount()
    Loop MonitorCount
    {
        MonitorGet(A_Index, &MonitorLeft, &MonitorTop, &MonitorRight, &MonitorBottom)
        if (xpos >= MonitorLeft and xpos < MonitorRight and ypos >= MonitorTop and ypos < MonitorBottom)
        {
            ; 現在のディスプレイの左端からの相対位置に基づいて移動
            newX := xpos - 10
            ; ディスプレイの境界を超えないように調整
            if (newX < MonitorLeft)
                newX := MonitorLeft
            MouseMove(newX, ypos, 0)
            break
        }
    }
return
}

move_mouse_cursor_to_up(){
    MouseGetPos(&xpos, &ypos)
    ypos -= 10
    MouseMove(xpos, ypos, 1)
    Sleep(5)
}

move_mouse_cursor_to_down(){
    MouseGetPos(&xpos, &ypos)
    ypos += 10
    MouseMove(xpos, ypos, 1)
    Sleep(5)
}

Jump_to_upper_left_point()              ; マウスカーソルを左上の原点に移動させる処理
{
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos -= 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        ypos -= 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos -= 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
return
}

Jump_to_upper_right_point()              ; マウスカーソルを左上の原点に移動させる処理
{
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos += 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        ypos -= 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos += 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
return
}

Jump_to_lower_right_point()              ; マウスカーソルを左上の原点に移動させる処理
{
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos += 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        ypos += 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos += 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
return
}

Jump_to_lower_left_point()              ; マウスカーソルを左上の原点に移動させる処理
{
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos -= 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        ypos += 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
    MouseGetPos(&xpos, &ypos)
    Loop 40
    {
        xpos -= 100
        MouseMove(xpos, ypos, 1)
        ; Sleep(5)  ; 少し待機（必要に応じて調整）
    }
return
}

Jump_to_center_display1()          ; マウスカーソルを各ポジションに移動させる処理
{         
    if (currentDisplay = 1) {               ; 2に移動
        ;Jump_to_origin_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(display1.x, ypos, 1)
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos, display1.y, 1)
        global currentDisplay := 2
    } else if (currentDisplay = 2) {        ; 3に移動
        ;Jump_to_origin_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(display2.x, ypos, 1)
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos, display2.y, 1)
        global currentDisplay := 3
    } else if (currentDisplay = 3) {        ; 1に移動
        ;Jump_to_origin_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(display3.x, ypos, 1)
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos, display3.y, 1)
        global currentDisplay := 1
    }
return
}

Jump_to_center_display2()          ; マウスカーソルを各ポジションに移動させる処理
{         
    if (currentDisplay = 1) {               ; 2に移動
        Jump_to_upper_right_point()
        MouseGetPos(&xpos, &ypos)
        Loop 10
            {
                xpos -= 100
                MouseMove(xpos, ypos, 1)
                ; Sleep(5)  ; 少し待機（必要に応じて調整）
            }
        Loop 8
            {
                ypos += 100
                MouseMove(xpos, ypos, 1)
                ; Sleep(5)  ; 少し待機（必要に応じて調整）
            }
        global currentDisplay := 2
    } else if (currentDisplay = 2) {        ; 3に移動
        Jump_to_lower_right_point()
        MouseGetPos(&xpos, &ypos)
        Loop 10
            {
                xpos -= 100
                MouseMove(xpos, ypos, 1)
                ; Sleep(5)  ; 少し待機（必要に応じて調整）
            }
        Loop 8
            {
                ypos += 100
                MouseMove(xpos, ypos, 1)
                ; Sleep(5)  ; 少し待機（必要に応じて調整）
            }
        global currentDisplay := 3
    } else if (currentDisplay = 3) {        ; 1に移動
        Jump_to_upper_left_point()
        MouseGetPos(&xpos, &ypos)
        Loop 10
            {
                xpos += 100
                MouseMove(xpos, ypos, 1)
                ; Sleep(5)  ; 少し待機（必要に応じて調整）
            }
        Loop 28
            {
                ypos += 100
                MouseMove(xpos, ypos, 1)
                ; Sleep(5)  ; 少し待機（必要に応じて調整）
            }
    }
return
}

Jump_to_center_display3()          ; マウスカーソルを各ポジションに移動させる処理
{         
    _x_move_value_dp1 := 1400
    _y_move_value_dp1 := 800
    _x_move_value_dp2 := 1400
    _y_move_value_dp2 := 800
    _x_move_value_dp3 := 1400
    _y_move_value_dp3 := 500
    if (currentDisplay = 1) {               ; 2に移動
        Jump_to_upper_right_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos-_x_move_value_dp2, ypos+_y_move_value_dp2, 1)
        global currentDisplay := 2
    } else if (currentDisplay = 2) {        ; 3に移動
        Jump_to_lower_right_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos-_x_move_value_dp3, ypos+_y_move_value_dp3, 1)
        global currentDisplay := 3
    } else if (currentDisplay = 3) {        ; 1に移動
        Jump_to_upper_left_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos+_x_move_value_dp1, ypos+_y_move_value_dp1, 1)
        global currentDisplay := 1
    }
return
}

Jump_to_center_display4()          ; マウスカーソルを各ポジションに移動させる処理
{         
    ; 2025/07/10  画面配置変更により修正
    ; 画面遷移の順番は右上⇒左上⇒左下
    _x_move_value_dp1 := 900
    _y_move_value_dp1 := 800
    _x_move_value_dp2 := 550
    _y_move_value_dp2 := 800
    _x_move_value_dp3 := 1000
    _y_move_value_dp3 := 550
    if (currentDisplay = 1) {               ; 2に移動
        Jump_to_upper_right_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos+_x_move_value_dp2, ypos+_y_move_value_dp2, 1)
        global currentDisplay := 2
    } else if (currentDisplay = 2) {        ; 3に移動
        Jump_to_upper_left_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos+_x_move_value_dp1, ypos+_y_move_value_dp1, 1)
        global currentDisplay := 3
    } else if (currentDisplay = 3) {        ; 1に移動
        Jump_to_lower_left_point()
        MouseGetPos(&xpos, &ypos)
        MouseMove(xpos+_x_move_value_dp3, ypos-_y_move_value_dp3, 1)
        global currentDisplay := 1
    }
return
}

FocusUnderCursor() {
    ; マウスカーソル下にあるアプリにコントロールを移す関数
    MouseGetPos &x, &y, &winID, &control
    WinActivate("ahk_id " winID)
}

; キーボードのみでカーソルを動かす処理
; --- 設定セクション ---
; CoordModeはSetCursorPosの引数には影響しませんが、
; MouseGetPosのためにScreenの絶対座標のまま維持
CoordMode("Mouse", "Screen")
amount_of_movement := 300

MoveCursorToRight() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x + amount_of_movement, "Int", y)
}

MoveCursorToLeft() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x - amount_of_movement, "Int", y)
}
MoveCursorToUp() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x, "Int", y - amount_of_movement)
}

MoveCursorToDown() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x, "Int", y + amount_of_movement)
}

ToggleClick()
{
    ; 左ボタンの状態を確認して分岐
    if GetKeyState("LButton")
    {
        Click "Up"
        Tooltip "Released" ; (任意) 動作確認用のヒント表示
    }
    else
    {
        Click "Down"
        Tooltip "Holding" ; (任意) 動作確認用のヒント表示
    }

    ; 1秒後にヒントを消す（不要なら削除してください）
    SetTimer () => ToolTip(), -3000
}
