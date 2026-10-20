#Requires AutoHotkey v2.0
;==============================================================================
; last_input.ahk
; 直前に入力した文字を覚えておき、すぐに入力し直す
;   LastInput_Recall()      直前の「ひとまとまりの入力」を入力する（いまは割り当てなし。割り当てるときは leader_keys.ahk の表に書く）
;   LastInput_RecallChar()  直前の 1 文字を入力する（keymap\leader_keys.ahk の Caps → : から呼ぶ。記号を何回も打つとき用）
;
; 直前の 1 文字：最後に入力された 1 文字（空白は除く）。次の 3 つのどれからでも覚える。
;   ・キーを直接打った文字（IME オンで打ったローマ字の 1 文字も覚える）
;   ・変換・無変換・Space のレイヤー（keymap\hold_keys.ahk）で送った記号。「起点 & キー::  SendInput("{_}")」の形の行を読んで、
;     そのホットキーが働いたときに覚える（割り当てを変えてもこちらを直さなくてよい）
;   ・入力待ちの表（keymap\leader_keys.ahk）で送った文字。Space+A → キーなど。Leader_Run が LastInput_NoteSendInput で渡す
;   ・記号メニュー（Caps → k）で入力した文字。QM_SymbolMenu が LastInput_NoteText で渡す
;   画面に出る形（全角・半角）のまま覚える。キーや記号を送ったとき、入力先の IME が全角で入力する状態なら全角にして覚え、
;   入力するときは IME に関係なくその文字をそのまま入力する（記号メニューで選んだ全角・半角は、選んだ形のまま）。
;
; 直前の「ひとまとまりの入力」：空白も含めて1 つだけ。次のどれかが起きるとひとまとまりが終わり、
;   それまでの文字が「直前の入力」になる。BackSpace は 1 文字消す。
;   ・Enter / Tab / Esc / 矢印 / Home / End / PgUp / PgDn / Delete / Ctrl・Alt・Win を押す
;   ・マウスをクリックする、前面のウィンドウが変わる
;   ・LASTINPUT_GAP_MS だけ、何も打たない時間が空く
;   ・IME をオンにして打つ（変換前のローマ字は覚えない。覚えるのは IME オフ＝半角で打った文字だけ）
; 覚えた文字はメモリの中だけに置き、ファイルには書かない。再読み込み・終了で消える。
; パスワード欄などで打った文字も覚えるので、気になる場合は LASTINPUT_ENABLED を false にする。
;
; 仕組み
;   画面に出る文字は、常駐する InputHook の OnChar で受ける（キーは奪わない）。
;   Space は「Space & ○」の起点でスクリプトが自分で打ち直すので InputHook に届かない。そのため、
;   Space を押して離したとき（押している間に組み合わせを使わなかったとき）だけ、押下の状態を見て空白を足す。
;==============================================================================
#Include %A_LineFile%\..\IME.ahk
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\text_input.ahk
#Include %A_LineFile%\..\text_ops.ahk

LASTINPUT_ENABLED := true
LASTINPUT_MAX_LEN := 200                     ; 覚える文字数の上限（超えたら古い方から忘れる）
LASTINPUT_GAP_MS := 3000                     ; この時間、何も打たなければ、ひとまとまりが終わる

LastInput_cur := ""                          ; 入力中のひとまとまり
LastInput_last := ""                         ; 直前の入力
LastInput_ch := ""                           ; 直前の 1 文字
LastInput_tick := 0
LastInput_win := 0
LastInput_hook := ""
LastInput_hkStamp := 0                       ; 直前に調べたホットキーが働いた時刻
LastInput_btnDown := false

LastInput_sending := false                   ; 自分が打ち直している間（打ち直した文字を覚え直さない）

;------------------------------------------------------------------------------
; 呼び出し口
;------------------------------------------------------------------------------
LastInput_Recall() {
    global LastInput_sending
    LastInput_Boundary()
    if (LastInput_last = "") {
        UI_TipFlash("⌨️ [直前の入力] 覚えている文字がありません")
        return
    }
    LastInput_sending := true
    try Text_SendHalfWidth("{Text}" LastInput_last)  ; 覚えるのは半角で打った文字だけなので、IME を一時的にオフにして打つ
    LastInput_sending := false
}

LastInput_RecallChar() {
    global LastInput_sending
    if (LastInput_ch = "") {
        UI_TipFlash("⌨️ [直前の 1 文字] 覚えている文字がありません")
        return
    }
    LastInput_sending := true
    try Text_SendHalfWidth("{Text}" LastInput_ch)   ; 覚えている形（全角・半角）の文字をそのまま入力する。IME オンのままだと全角文字が入らないことがあるので、一時的にオフにして打つ
    LastInput_sending := false
}

; 1 文字の記憶に入れる。exact が false のときは、入力先の IME が全角で入力する状態なら全角にして覚える
;   （画面に出る形に合わせる）。exact が true のときは、渡された文字をそのまま覚える
LastInput_SetChar(ch, exact := false) {
    global LastInput_ch
    if (ch = "" || ch = " ")
        return
    if (!exact && Ord(ch) >= 0x21 && Ord(ch) <= 0x7E) {
        full := false
        try full := QM_TargetImeIsFullWidth(WinExist("A"))
        if full
            ch := QM_ToFullAscii(ch)
    }
    LastInput_ch := ch
}

; メニューなどが入力した文字列を覚える。記号メニュー（Caps → k）などが全角・半角を選んで送った文字は、その形のまま覚える
LastInput_NoteText(text) {
    if (LASTINPUT_ENABLED && StrLen(text) = 1)
        LastInput_SetChar(text, true)
}

; ホットキー・入力待ちが SendInput で送った文字を覚える（ch は 1 文字）。1 文字の記憶に入れ、ひとまとまりにも足す
LastInput_NoteSend(ch) {
    if (!LASTINPUT_ENABLED || ch = "")
        return
    LastInput_SetChar(ch)
    LastInput_Add(ch)
}

; SendInput に渡す文字列（例："{_}"、"{(}"、"p"）が 1 文字だけなら、その文字を返す。それ以外（{Enter} や ^{Home} など）は ""
LastInput_CharOf(keys) {
    keys := StrReplace(keys, "``")
    keys := RegExReplace(keys, "i)^\{Blind\}")
    if RegExMatch(keys, "^\{(.)\}$", &m)
        ch := m[1]
    else if (StrLen(keys) = 1 && !InStr("^+!#{}", keys))
        ch := keys
    else
        return ""
    return (ch = " " || ch = "`t") ? "" : ch
}

; keymap\leader_keys.ahk の Leader_Run が、表の「送るキーの文字列」を SendInput したあとに呼ぶ
LastInput_NoteSendInput(keys) => LastInput_NoteSend(LastInput_CharOf(keys))

; keymap\hold_keys.ahk の「起点 & キー::  SendInput("{_}")」の行から、ホットキー名（"vk1D & j"）→ 送る 1 文字の表を作る
_LastInput_HoldChars() {
    static chars := 0
    if IsObject(chars)
        return chars
    chars := Map()
    chars.CaseSense := false
    src := ""
    try src := KP_Read("hold_keys.ahk")
    for prefix in ["vk1C", "vk1D", "vk20"] {
        for row in KP_HoldRows(src, prefix) {
            if RegExMatch(row.action, '^SendInput\("(.*)"\)$', &m) {
                ch := LastInput_CharOf(m[1])
                if (ch != "")
                    chars[prefix " & " row.key] := ch
            }
        }
    }
    return chars
}

; 入力中のひとまとまりを終わらせ、「直前の入力」にする
LastInput_Boundary() {
    global LastInput_cur, LastInput_last
    if (LastInput_cur != "") {
        LastInput_last := LastInput_cur
        LastInput_cur := ""
    }
}

;------------------------------------------------------------------------------
; 文字の記録
;------------------------------------------------------------------------------
LastInput_Add(ch) {
    global LastInput_cur, LastInput_tick, LastInput_win
    now := A_TickCount, win := WinExist("A")
    if (LastInput_cur != "" && (now - LastInput_tick > LASTINPUT_GAP_MS || win != LastInput_win))
        LastInput_Boundary()
    LastInput_tick := now, LastInput_win := win
    ime := 0
    try ime := IME_GET()
    if (ime != 0) {                                 ; 変換前のローマ字は、ひとまとまりには入れない。IME で打つ間は区切りにする
        LastInput_Boundary()
        return
    }
    LastInput_cur .= ch
    if (StrLen(LastInput_cur) > LASTINPUT_MAX_LEN)
        LastInput_cur := SubStr(LastInput_cur, -LASTINPUT_MAX_LEN + 1)
}

_LastInput_OnChar(h, ch) {
    ; Space は届かない（下のホットキーで足す）。届いても数えない。制御文字は文字ではない
    if (!LASTINPUT_ENABLED || IH_waiting || LastInput_sending || ch = " " || Ord(ch) < 32)
        return
    LastInput_Add(ch)
}

_LastInput_OnKeyDown(h, vk, sc) {
    global LastInput_cur
    if (!LASTINPUT_ENABLED || IH_waiting || LastInput_sending)
        return
    static boundary := Map(0x0D, 1, 0x09, 1, 0x1B, 1, 0x21, 1, 0x22, 1, 0x23, 1, 0x24, 1, 0x25, 1, 0x26, 1, 0x27, 1, 0x28, 1
        , 0x2E, 1, 0x11, 1, 0xA2, 1, 0xA3, 1, 0x12, 1, 0xA4, 1, 0xA5, 1, 0x5B, 1, 0x5C, 1)   ; Enter Tab Esc 移動キー Delete Ctrl Alt Win
    if (vk = 0x08)                                  ; BackSpace
        LastInput_cur := SubStr(LastInput_cur, 1, -1)
    else if boundary.Has(vk)
        LastInput_Boundary()
    else if (ch := _LastInput_KeyChar(vk, sc)) != ""
        LastInput_SetChar(ch)                       ; IME オンで打つと OnChar に届かないので、キーから文字を作って 1 文字の記憶に入れる
}

; 押されたキーの文字（Shift・CapsLock を反映）。Ctrl / Alt / Win を押しているとき、文字でないキーは ""
_LastInput_KeyChar(vk, sc) {
    if (vk = 0xE5 || vk = 0xE7 || vk = 0x20 || GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin"))
        return ""
    state := Buffer(256, 0)
    if GetKeyState("Shift")
        NumPut("UChar", 0x80, state, 0x10)
    if GetKeyState("CapsLock", "T")
        NumPut("UChar", 0x01, state, 0x14)
    buf := Buffer(16, 0)
    n := DllCall("ToUnicode", "UInt", vk, "UInt", sc, "Ptr", state, "Ptr", buf, "Int", 8, "UInt", 4, "Int")   ; 4：キーボードの状態（ダイアキリティカル）を変えない
    if (n != 1)
        return ""
    ch := StrGet(buf, 1)
    return (Ord(ch) < 32) ? "" : ch
}

LastInput_Start() {
    global LastInput_hook
    h := InputHook("V")                             ; 文字を奪わず、受けるだけ
    h.KeyOpt("{All}", "N")                          ; すべてのキーを OnKeyDown で受ける
    h.OnChar := _LastInput_OnChar
    h.OnKeyDown := _LastInput_OnKeyDown
    h.OnEnd := (*) => h.Start()                     ; 文字数の上限などで終わっても、続けて受ける
    h.Start()
    LastInput_hook := h
}

LastInput_Start()

;------------------------------------------------------------------------------
; Space（押して離したときに、組み合わせのホットキーを使わなかったら、空白を足す）
;   Space にホットキーを定義すると、「Space & ○」の起点の動きを変えてしまうので、押下の状態を短い間隔で見る。
;   Space を押している間に、何かホットキーが働いたら（Space+j など）空白ではない。
;------------------------------------------------------------------------------
LASTINPUT_POLL_MS := 15
LastInput_spaceSince := 0                    ; Space を押し始めた時刻（押していないときは 0）
LastInput_spaceUsed := false                 ; 押している間に、組み合わせ・入力待ちがあった

_LastInput_PollSpace() {
    global LastInput_spaceSince, LastInput_spaceUsed
    _LastInput_PollHotkey()
    _LastInput_PollMouse()
    down := GetKeyState("vk20", "P")
    if (down && !LastInput_spaceSince) {
        LastInput_spaceSince := A_TickCount
        LastInput_spaceUsed := false
    }
    else if (down) {
        ; A_ThisHotkey は直前に働いたホットキー。Space を押してから働いたなら、組み合わせに使われている
        if (IH_waiting || (A_ThisHotkey != "" && A_TimeSinceThisHotkey < A_TickCount - LastInput_spaceSince))
            LastInput_spaceUsed := true
    }
    else if (LastInput_spaceSince) {
        used := LastInput_spaceUsed || IH_waiting
        LastInput_spaceSince := 0
        if used                                     ; Space+j のカーソル移動などは、入力の区切りにする
            LastInput_Boundary()
        else if (LASTINPUT_ENABLED && LastInput_cur != "")
            LastInput_Add(" ")
    }
}

SetTimer(_LastInput_PollSpace, LASTINPUT_POLL_MS)

; 新しくホットキーが働いたとき、それが「記号を 1 文字送る行」なら、その文字を覚える
;   hold_keys.ahk の SendInput は自分の InputHook に届かないので、働いたホットキーの名前から調べる
_LastInput_PollHotkey() {
    global LastInput_hkStamp
    if (A_ThisHotkey = "")
        return
    stamp := A_TickCount - A_TimeSinceThisHotkey
    if (Abs(stamp - LastInput_hkStamp) < 5)         ; 前に見たのと同じ 1 回の押下
        return
    LastInput_hkStamp := stamp
    LastInput_NoteSend(_LastInput_HoldChars().Get(A_ThisHotkey, ""))
}

; マウスのボタンを押したら、ひとまとまりを終える（ホットキーにすると、直前のホットキーの判定を乱すので見るだけにする）
_LastInput_PollMouse() {
    global LastInput_btnDown
    down := GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
    if (down && !LastInput_btnDown)
        LastInput_Boundary()
    LastInput_btnDown := down
}
