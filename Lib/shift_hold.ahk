#Requires AutoHotkey v2.0
;==============================================================================
; shift_hold.ahk
; Shift 長押しモード：入ると Shift を押したままの状態になる。終わるまで、Shift を押しながら打つのと同じ入力になる。
;   ・英字は大文字、数字・記号は Shift 側（Shift + 1 の「!」など）になる。
;   ・変換 + g などの BS、Space + j などのカーソル移動も、そのまま使える（押し直さないので、キーを横取りしない）。
;   ・矢印は Shift 付きになり、範囲選択になる。マウスのクリックも Shift 付きになる。
;   ・Enter（Space+g / h、Enter キー）：IME が日本語入力（ひらがななど）のときは、モードを終えてから Shift なしで送る（未確定の文字を確定して、モードを抜ける）。
;     IME が半角英数のときは、1 回目の Enter はモードを抜けるだけで、Enter は送らない（そのまま実行されないように）。2 回目からは普通の Enter。
;     IME の F8・F9（変換+b / n）は、モードは続けたまま ShiftHold_SendPlain で Shift なしで送る（半角全角変換が効くように）。
;   表示：入っている間、前面のウィンドウのあるモニターの上端に色つきの帯（SHIFTHOLD_BAR_HEIGHT）と、左下にツールチップを出す。ウィンドウが別のモニターへ移ったら追う。
;   Space + A（左手で文字・記号）は、入力待ちの間だけ ShiftHold_Pause で Shift を離し、送る直前に ShiftHold_Resume で戻す（送る文字にモードが反映される）。
;   呼び出し：Caps → Space（keymap\leader_keys.ahk）
;   終了：Esc / Caps / Space+Caps、変換・無変換の短押し（IME を切り替えたとき。keymap\hold_keys.ahk）、Enter（確定したら抜ける）、キー操作がない状態が SHIFTHOLD_IDLE_MS 続いたとき、Shift キーを物理的に押して離したとき、
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
#Include %A_LineFile%\..\text_ops.ahk
#Include %A_LineFile%\..\IME.ahk

SHIFTHOLD_IDLE_MS := 120000                        ; 操作がなければ終了するまでの時間 [ms]（0 で無効）
SHIFTHOLD_BAR_HEIGHT := 6                          ; モード中にモニターの上端に出す帯の高さ [px]（0 で出さない）
SHIFTHOLD_BAR_COLOR := "FF8C00"                   ; 帯の色

ShiftHold_on := false
ShiftHold_paused := false                          ; 入力待ちの間だけ Shift を離している
ShiftHold_wasOn := false                           ; 入力待ちを始めたときの状態（ShiftHold_Toggle 用）
ShiftHold_bar := 0                                 ; 帯の Gui
ShiftHold_mon := 0                                 ; 表示中のモニター（ハンドル）

ShiftHold_IsOn() => ShiftHold_on

; 入力待ちからの切り替え（ShiftHold_Toggle を割り当てたとき）。モード中に Caps を押すと終了用のホットキーも同時に働くので、
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
; IME が半角英数のときは、確定する文字がないので、モードを抜けるだけで Enter は送らない（そのまま実行されないように。次の Enter から普通）
; keys には、物理キーのホットキーから呼ぶときは「{Blind}{Enter}」を渡す（押している Ctrl などを残す）
ShiftHold_Enter(keys := "{Enter}") {
    if (ShiftHold_on && !_ShiftHold_ImeJapanese()) {
        ShiftHold_Stop("⇧ Shift 長押しモード：終了（もう一度 Enter で実行）")
        return
    }
    ShiftHold_Stop()
    SendInput(keys)
}

; 入力先の IME が日本語入力の状態（ひらがな・全角・変換中）か。半角英数（IME オフ）と確かめられたときだけ false
; アプリによって IME の状態の取り方が合わないことがあるので、3 通りのどれかが「オン」なら true にする。
; IME に問い合わせても答えがないときも true（従来どおり、確定してモードを抜ける側にする）
_ShiftHold_ImeJapanese() {
    hwnd := WinExist("A")
    if !hwnd
        return true
    try {
        if (QM_TargetImeIsFullWidth(hwnd) || IME_GET() || IME_GetConverting())
            return true
        hIme := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
        r := 0
        return !hIme || !DllCall("SendMessageTimeout", "Ptr", hIme, "UInt", 0x0283, "Ptr", 5, "Ptr", 0
            , "UInt", 0x2, "UInt", 200, "UPtr*", &r, "Ptr")
    }
    catch
        return true
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
    _ShiftHold_Show(true)
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
    _ShiftHold_Hide()
    if (message != "")
        UI_Tip(message)
}

; Shift が外部から離された（物理的に Shift を押して離した）か、操作がない状態が続いたら終了する。前面のウィンドウが別のモニターへ移ったら、表示も追う
_ShiftHold_Watch() {
    if ShiftHold_paused
        return
    if !GetKeyState("LShift")
        ShiftHold_Stop("⇧ Shift 長押しモード：終了")
    else if (SHIFTHOLD_IDLE_MS > 0 && A_TimeIdlePhysical > SHIFTHOLD_IDLE_MS)
        ShiftHold_Stop("⇧ Shift 長押しモード：時間切れで終了")
    else
        _ShiftHold_Show()
}

; 前面のウィンドウのあるモニターに、上端の帯とツールチップを出す（force：同じモニターでも出し直す）
_ShiftHold_Show(force := false) {
    global ShiftHold_bar, ShiftHold_mon
    hMon := DllCall("MonitorFromWindow", "Ptr", WinExist("A"), "UInt", 1, "Ptr")       ; 1：前面がなければメインのモニター
    if (!force && hMon = ShiftHold_mon)
        return
    ShiftHold_mon := hMon
    mi := Buffer(40, 0), NumPut("UInt", 40, mi)
    DllCall("GetMonitorInfo", "Ptr", hMon, "Ptr", mi)
    ml := NumGet(mi, 4, "Int"), mt := NumGet(mi, 8, "Int"), mr := NumGet(mi, 12, "Int")      ; モニター全体
    wl := NumGet(mi, 20, "Int"), wb := NumGet(mi, 32, "Int")                                  ; 作業領域（タスクバーを除く）の左と下
    CoordMode("ToolTip", "Screen")
    UI_ToolTip("⇧ [Shift 長押しモード] Shift を押したままの状態です`nEsc / Caps / Space+Caps：終了　Enter：確定して終了（半角英数のときは終了だけ）", wl + 12, wb - 56, TIP_ID_SHIFTHOLD)
    if (SHIFTHOLD_BAR_HEIGHT <= 0)
        return
    if !IsObject(ShiftHold_bar) {
        bar := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20 +E0x08000000")      ; クリックを通す
        bar.BackColor := SHIFTHOLD_BAR_COLOR
        bar.Show("NoActivate Hide w1 h1")
        WinSetTransparent(250, bar)                                                          ; クリックを通すには透過の属性が要る
        ShiftHold_bar := bar
    }
    ShiftHold_bar.Show("NoActivate x" ml " y" mt " w" (mr - ml) " h" SHIFTHOLD_BAR_HEIGHT)
}

_ShiftHold_Hide() {
    global ShiftHold_mon
    ShiftHold_mon := 0
    ToolTip(, , , TIP_ID_SHIFTHOLD)
    if IsObject(ShiftHold_bar)
        ShiftHold_bar.Hide()
}

OnExit((*) => ShiftHold_Stop())
