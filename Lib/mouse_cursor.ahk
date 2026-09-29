#Requires AutoHotkey v2.0

Right_click(){
    turn_on_roman_input_mode()
    SendInput("{vk5Dsc15D}")
}


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
amount_of_movement := 200
amount_of_movement_minimal := 30
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

MoveCursorToRightMinimal() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x + amount_of_movement_minimal, "Int", y)
}

MoveCursorToLeftMinimal() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x - amount_of_movement_minimal, "Int", y)
}
MoveCursorToUpMinimal() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x, "Int", y - amount_of_movement_minimal)
}

MoveCursorToDownMinimal() {
    MouseGetPos(&x, &y)
    DllCall("SetCursorPos", "Int", x, "Int", y + amount_of_movement_minimal)
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

;==============================================================================
; 2026/09/28 カーソル移動処理の実装変更（MoveCursorTo*2 系を追加）
;------------------------------------------------------------------------------
; 【経緯】
; Snapdragon 版 SoC 搭載 Surface（Windows on Arm）で使用したところ、
; 従来の MoveCursorTo* 系の動きが x64 機と比べて鈍く感じられたため、
; 処理の見直しを行った。
;
; 【原因の想定】
; (1) AutoHotkey は Arm64 ネイティブではなく、Windows on Arm の
; x86/x64 エミュレーション層（Prism）上で動作する。
; このため DllCall 1 回ごとの命令変換オーバーヘッドが体感に乗る。
; (2) DllCall("SetCursorPos", ...) と関数名を文字列で毎回指定していたため、
; 呼び出しのたびに関数アドレスの名前解決が発生していた。
; (3) MouseGetPos は AHK 側の DPI 仮想化を経由した座標を返すのに対し、
; SetCursorPos は生のピクセル座標を要求する。
; AHK v2.0 は per-monitor DPI aware ではないため、
; 高 DPI／マルチモニタ環境では両者の座標系がずれる場合がある。
; (4) 1 押下 = 固定量ジャンプの実装のため、押しっぱなしで移動する際に
; OS のキーリピート初回待ち時間（約 250ms）がそのまま遅延に見えていた。
;
; 【対策】
; (1) user32.dll の SetCursorPos / GetCursorPos のアドレスを
; GetProcAddress で起動時に一度だけ解決し、以降は使い回す。
; (2) 座標取得を MouseGetPos から GetCursorPos の直接呼び出しに変更し、
; 取得・設定の座標系を生ピクセルに統一。
; あわせて SetThreadDpiAwarenessContext(-4) で
; per-monitor v2 を有効化し、スケーリング差によるずれを排除。
; (3) POINT 構造体用の Buffer をグローバルで確保し、呼び出し毎の
; メモリ割り当てを回避。
; (4) ListLines / KeyHistory を無効化し、実行履歴記録の負荷を削減。
; ProcessSetPriority "High" で優先度を引き上げ。
; (5) 前回呼び出しからの経過時間（REPEAT_WINDOW 以内かどうか）で
; キーリピート中かを判定し、同方向の連続呼び出しでは
; 移動量に加速倍率（最大 MAX_ACCEL 倍）を掛ける。
; 単発押下時は従来どおりの固定量で動作する。
;
; 【呼び出し側への影響】
; ホットキー定義の書式は変更していない。
; 従来関数は残したまま末尾に "2" を付けた新関数を追加しているため、
; ホットキーの呼び出し先を MoveCursorToRight2() 等に差し替えるだけでよい。
; Minimal 系は第 3 引数 false で加速を無効化しており、
; 従来同様つねに amount_of_movement_minimal の固定量で移動する。
;
; 【調整ポイント】
; REPEAT_WINDOW … 大きいと加速が持続しやすい。効きすぎる場合は 100 程度へ。(default 150)
; MAX_ACCEL … 押しっぱなし時の最高速。行き過ぎるなら下げる。(default 4.0)
; ACCEL_STEP … 加速の立ち上がりの速さ。(default 0.35)
;==============================================================================
#SingleInstance Force
ListLines False
KeyHistory 0
ProcessSetPriority "High"
CoordMode("Mouse", "Screen")
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

; --- 設定 ---
amount_of_movement2 := 200
amount_of_movement2_minimal := 30
;REPEAT_WINDOW := 5 ; この ms 以内の再呼び出しを「押しっぱなし」とみなす
;MAX_ACCEL := 50.0 ; 加速の上限倍率
;ACCEL_STEP := 10.0 ; 1回あたりの加速量
REPEAT_WINDOW := 100 ; この ms 以内の再呼び出しを「押しっぱなし」とみなす
MAX_ACCEL := 4.0 ; 加速の上限倍率
ACCEL_STEP := 0.35 ; 1回あたりの加速量


; --- API を起動時に一度だけ解決 ---
_hUser32 := DllCall("GetModuleHandle", "Str", "user32", "Ptr")
_pSetCursor := DllCall("GetProcAddress", "Ptr", _hUser32, "AStr", "SetCursorPos", "Ptr")
_pGetCursor := DllCall("GetProcAddress", "Ptr", _hUser32, "AStr", "GetCursorPos", "Ptr")
_ptBuf := Buffer(8, 0)

; --- 内部共通処理 ---
_MoveCursor(dx, dy, accelerate := true) {
global _pGetCursor, _pSetCursor, _ptBuf
global REPEAT_WINDOW, MAX_ACCEL, ACCEL_STEP
static lastTick := 0, lastDX := 0, lastDY := 0, accel := 1.0

if (accelerate) {
now := A_TickCount
if (now - lastTick <= REPEAT_WINDOW && dx = lastDX && dy = lastDY)
accel := Min(accel + ACCEL_STEP, MAX_ACCEL)
else
accel := 1.0
lastTick := now, lastDX := dx, lastDY := dy
} else {
accel := 1.0, lastTick := 0
}
DllCall(_pGetCursor, "Ptr", _ptBuf, "Int")
DllCall(_pSetCursor
, "Int", NumGet(_ptBuf, 0, "Int") + Round(dx * accel)
, "Int", NumGet(_ptBuf, 4, "Int") + Round(dy * accel), "Int")
}
; --- 公開関数（呼び出し側は今まで通り）---
MoveCursorToRight2() => _MoveCursor( amount_of_movement2, 0)
MoveCursorToLeft2() => _MoveCursor(-amount_of_movement2, 0)
MoveCursorToUp2() => _MoveCursor( 0, -amount_of_movement2)
MoveCursorToDown2() => _MoveCursor( 0, amount_of_movement2)

MoveCursorToRightMinimal2() => _MoveCursor( amount_of_movement2_minimal, 0, false)
MoveCursorToLeftMinimal2() => _MoveCursor(-amount_of_movement2_minimal, 0, false)
MoveCursorToUpMinimal2() => _MoveCursor( 0, -amount_of_movement2_minimal, false)
MoveCursorToDownMinimal2() => _MoveCursor( 0, amount_of_movement2_minimal, false)


