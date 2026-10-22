#Requires AutoHotkey v2.0
;==============================================================================
; shift_hold.ahk
; Shift 長押しモード：入ると Shift を押したままの状態になる。終わるまで、Shift を押しながら打つのと同じ入力になる。
;   ・英字は大文字、数字・記号は Shift 側（Shift + 1 の「!」など）になる。
;   ・変換 + g などの BS、Space + j などのカーソル移動も、そのまま使える（押し直さないので、キーを横取りしない）。
;   ・矢印は Shift 付きになり、範囲選択になる。マウスのクリックも Shift 付きになる。
;   ・Enter（Space+g / h、Enter キー）は、モードを終えてから Shift なしで送る（未確定の文字を確定して、モードを抜ける）。
;     IME の F8・F9（変換+b / n）は、モードは続けたまま ShiftHold_SendPlain で Shift なしで送る（半角全角変換が効くように）。
;   Space + A（左手で文字・記号）は、入力待ちの間だけ ShiftHold_Pause で Shift を離し、送る直前に ShiftHold_Resume で戻す（送る文字にモードが反映される）。
;   呼び出し：Space+A → Space、Space+F → 変換（keymap\leader_keys.ahk）
;   終了：Esc / Caps / Space+Caps、Enter（確定したら抜ける）、キー操作がない状態が SHIFTHOLD_IDLE_MS 続いたとき、Shift キーを物理的に押して離したとき、
;         スクリプトの終了・再読み込み。
;
; 注意
;   ・Shift を押したままの間は、「*」なしの単独キーのホットキー（Insert など）は発動しない。
;     組み合わせ（変換 & g など）は発動する。終了用のホットキーには「*」を付けてある。
;   ・押しっぱなしを残さないよう、終了時・再読み込み時に必ず Shift を離す。
; 旧「大文字入力モード」の作り直し。旧版は Lib\archive\upper_mode.ahk。
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\ui_common.ahk

SHIFTHOLD_IDLE_MS := 120000                        ; 操作がなければ終了するまでの時間 [ms]（0 で無効）

ShiftHold_on := false
ShiftHold_paused := false                          ; 入力待ちの間だけ Shift を離している
ShiftHold_wasOn := false                           ; 入力待ちを始めたときの状態（ShiftHold_Toggle 用）

ShiftHold_IsOn() => ShiftHold_on

; 入力待ち（Space+A → Space）からの切り替え。モード中に Caps を押すと終了用のホットキーも同時に働くので、
; 待つ前に ShiftHold_Remember で記録した状態で、入る・抜けるを決める
ShiftHold_Remember() {
    global ShiftHold_wasOn := ShiftHold_on
}

ShiftHold_Toggle() {
    if ShiftHold_wasOn
        ShiftHold_Stop()
    else
        ShiftHold_Start()
}

; 入力待ちで打ったキーを「Shift なしの文字」で受けるために、モードは続けたまま Shift を一時的に離す。戻すのは ShiftHold_Resume
ShiftHold_Pause() {
    global ShiftHold_paused
    if !ShiftHold_on || ShiftHold_paused
        return
    ShiftHold_paused := true
    SendInput("{Blind}{LShift up}")
}

ShiftHold_Resume() {
    global ShiftHold_paused
    if !ShiftHold_paused
        return
    ShiftHold_paused := false
    if ShiftHold_on
        SendInput("{Blind}{LShift down}")
}

; Enter を Shift なしで送る。Shift 長押しモード中なら、モードを終えてから送る（未確定の文字を確定したら、モードも抜ける）
; keys には、物理キーのホットキーから呼ぶときは「{Blind}{Enter}」を渡す（押している Ctrl などを残す）
ShiftHold_Enter(keys := "{Enter}") {
    ShiftHold_Stop()
    SendInput(keys)
}

; モード中の F8・F9 のように、モードは続けたまま、そのキーだけ Shift なしで送る
; （Shift 付きだと、IME の半角・全角変換などが効かない）
ShiftHold_SendPlain(keys) {
    if ShiftHold_on
        SendInput("{Blind}{LShift up}" keys "{LShift down}")
    else
        SendInput(keys)
}

; モードに入る（入っていれば終了する）
ShiftHold_Start() {
    global ShiftHold_on
    if ShiftHold_on {
        ShiftHold_Stop()
        return
    }
    ShiftHold_on := true
    SendInput("{Blind}{LShift down}")
    SetTimer(_ShiftHold_Watch, 200)
    _ShiftHold_Tip()
}

; モードを終える。入っていなければ何もしない
ShiftHold_Stop(message := "") {
    global ShiftHold_on, ShiftHold_paused
    if !ShiftHold_on
        return
    ShiftHold_on := false
    ShiftHold_paused := false
    SetTimer(_ShiftHold_Watch, 0)
    SendInput("{Blind}{LShift up}")
    ToolTip(, , , TIP_ID_SHIFTHOLD)
    if (message != "")
        UI_Tip(message)
}

; Shift が外部から離された（物理的に Shift を押して離した）か、操作がない状態が続いたら終了する
_ShiftHold_Watch() {
    if ShiftHold_paused
        return
    if !GetKeyState("LShift")
        ShiftHold_Stop("⇧ Shift 長押しモード：終了")
    else if (SHIFTHOLD_IDLE_MS > 0 && A_TimeIdlePhysical > SHIFTHOLD_IDLE_MS)
        ShiftHold_Stop("⇧ Shift 長押しモード：時間切れで終了")
}

_ShiftHold_Tip() {
    CoordMode("ToolTip", "Screen")
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    UI_ToolTip("⇧ [Shift 長押しモード] Shift を押したままの状態です`nEsc / Caps / Space+Caps：終了", l + 12, b - 56, TIP_ID_SHIFTHOLD)
}

OnExit((*) => ShiftHold_Stop())
