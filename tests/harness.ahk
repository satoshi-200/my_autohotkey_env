#Requires AutoHotkey v2.0
;==============================================================================
; harness.ahk
; 試験用の共通部品。tests\cases\*.ahk が #Include する（tests\run_tests.ps1 が、リポジトリの複製の main.ahk を動かして実行する）。
;   T_Start("edit"|"msg")  試験用の窓を前面に出す。edit：入力欄あり（入った文字を読む）、msg：入力欄なし（窓に届いたキー・マウスのメッセージを読む）
;   T_Tap(キー) / T_Down / T_Up / T_Combo(起点, キー) / T_Chord(先, 後, キー)   別プロセスとして入力を送る（{Blind}。SendLevel 1）
;   T_Msgs()  届いたメッセージの記録 [vkXX 修飾]（キー）・(cNN)（文字）・LDOWN など（マウス）。読むと空になる
;   T_Value() / T_Clear()  入力欄の中身
;   T_Expect(名前, 実際, 期待)   PASS / FAIL を記録する。最後に T_End()
;   押している判定：T_Down はキーごとの旗ファイルを作る（複製では GetKeyState(キー, "P") が旗の有無に置き換わっている）
;   注意：マウスを窓の中へ動かす試験がある。補助スクリプトが送るキーは前面の窓に届くので、試験中は触らない
;==============================================================================
T_out := ""
T_gui := 0
T_ed := 0
T_buf := ""
T_name := RegExReplace(A_ScriptName, "\.ahk$")
OnError((e, *) => (T_Fatal("error: " e.Message " (" RegExReplace(e.File, ".*\\") " line " e.Line ")"), 1))   ; ダイアログで止めず、結果に書いて終える
SetTimer(() => T_Fatal("stopped (no T_End within 50 s)"), -50000)      ; run_tests.ps1 の時間切れ（60 秒）より前に、そこまでの結果を残す

T_Start(mode := "edit") {
    global T_gui, T_ed
    Sleep(200)
    T_gui := Gui("+AlwaysOnTop", "t_case")
    if (mode = "edit")
        T_ed := T_gui.AddEdit("w380 r4")
    T_gui.Show("w400 h160")
    inp := Buffer(40, 0)
    DllCall("SendInput", "UInt", 1, "Ptr", inp, "Int", 40)         ; 前面にできるよう、空のマウス入力を送る
    WinActivate("t_case")
    if !WinWaitActive("t_case", , 3)
        T_Fatal("試験用の窓を前面にできない")
    if T_ed
        T_ed.Focus()
    for m in [0x100, 0x102, 0x201, 0x202, 0x203, 0x204, 0x205, 0x206, 0x207, 0x208, 0x209]
        OnMessage(m, _T_OnMsg)
    SendLevel(1)
    Sleep(300)
}

_T_OnMsg(wParam, lParam, msg, hwnd) {
    global T_buf
    static mouse := Map(0x201, "LDOWN", 0x202, "LUP", 0x203, "LDBL", 0x204, "RDOWN", 0x205, "RUP", 0x206, "RDBL", 0x207, "MDOWN", 0x208, "MUP", 0x209, "MDBL")
    if (msg = 0x100) {
        if (wParam = 0x10 || wParam = 0x11 || wParam = 0x12 || (wParam >= 0xA0 && wParam <= 0xA5) || wParam = 0x5B || wParam = 0x5C)
            return                                     ; 修飾キー自身は記録しない
        T_buf .= Format("[vk{:X}", wParam) (GetKeyState("Shift") ? " Shift" : "") (GetKeyState("Ctrl") ? " Ctrl" : "") "]"
    }
    else if (msg = 0x102)
        T_buf .= "(c" wParam ")"
    else
        T_buf .= mouse[msg] ((wParam & 0x8) ? "+Ctrl" : "") " "
}

T_Msgs() {
    global T_buf
    s := RTrim(T_buf)
    T_buf := ""
    return s
}

T_Value() {
    return T_ed ? StrReplace(StrReplace(T_ed.Value, "`r"), "`n", "<LF>") : ""
}

T_Clear() {
    global T_buf
    if T_ed
        T_ed.Value := ""
    T_buf := ""
    Sleep(100)
}

_T_Flag(k, on) {
    f := A_Temp "\_t_down_" StrLower(k)
    if on
        FileOpen(f, "w").Close()
    else if FileExist(f)
        FileDelete(f)
}

T_Down(k) {
    _T_Flag(k, true)
    SendInput("{Blind}{" k " down}")
    Sleep(80)
}

T_Up(k) {
    _T_Flag(k, false)
    SendInput("{Blind}{" k " up}")
    Sleep(80)
}

T_Tap(k) {
    SendInput("{Blind}{" k " down}")
    Sleep(40)
    SendInput("{Blind}{" k " up}")
    Sleep(120)
}

; 起点を押したまま k を打つ
T_Combo(prefix, k) {
    T_Down(prefix)
    T_Tap(k)
    T_Up(prefix)
    Sleep(250)
}

; a を先に、b を後に押したまま k を打つ（3 キー）
T_Chord(a, b, k) {
    T_Down(a)
    T_Down(b)
    T_Tap(k)
    T_Up(b)
    T_Up(a)
    Sleep(250)
}

T_Expect(name, actual, expected) {
    global T_out
    T_out .= (actual == expected ? "PASS " : "FAIL ") T_name ": " name (actual == expected ? "" : "  got [" actual "] want [" expected "]") "`n"
}

T_Fatal(msg) {
    global T_out
    T_out .= "FAIL " T_name ": " msg "`n"
    T_End()
}

T_End() {
    global T_out
    try FileDelete(A_Temp "\_t_case_" T_name ".txt")
    FileAppend(T_out, A_Temp "\_t_case_" T_name ".txt", "UTF-8")
    for f in ["vk1c", "vk1d", "vk20"]
        _T_Flag(f, false)
    ExitApp()
}
