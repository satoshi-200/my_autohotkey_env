#Requires AutoHotkey v2.0
;==============================================================================
; chord.ahk
; 変換と無変換を両方押したままの 3 キーの割り当て（keymap\chord_keys.ahk / chord_ordered_keys.ahk）の共通部品
;   Chord_Both()        変換と無変換を両方押しているか
;   Chord_Begin(order, pairFn)
;                       2 キーの組み合わせ（keymap\hold_keys.ahk の vk1C & vk1D / vk1D & vk1C）が呼び、押した順番を覚える
;                       order："CD"＝変換 → 無変換、"DC"＝無変換 → 変換。pairFn：2 キー自体に割り当てる処理（なくてよい）
;   両方を押している間は、hold_keys.ahk の通常の割り当てが止まり、chord_*.ahk の割り当てだけが働く。
;   割り当てのないキーが文字として入力されないよう、何もしないホットキーを、通常の割り当てのあるキーなどに先に足しておく（Chord_InstallCatchAll）。
;==============================================================================
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\keymap_parse.ahk

Chord_order := ""                                   ; 最後に押した 2 キーの順番

Chord_Both() => GetKeyState("vk1C", "P") && GetKeyState("vk1D", "P")

Chord_Begin(order, pairFn := 0) {
    global Chord_order := order
    if pairFn
        pairFn()
}

Chord_Ctx(*) => !IH_waiting && Chord_Both()

Chord_Nop(*) {
}

; 両方を押している間、割り当てのないキーも何も起こさないようにする。
; 割り当てのあるキー（chord_*.ahk の行）は先に読み込まれているので、そちらが優先される
Chord_InstallCatchAll() {
    keys := Map()
    keys.CaseSense := false
    for k in StrSplit("abcdefghijklmnopqrstuvwxyz1234567890")
        keys[k] := 1
    for k in ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "Up", "Down", "Left", "Right"
        , "Home", "End", "PgUp", "PgDn", "Insert", "Delete", "BackSpace", "Enter", "Tab"]
        keys[k] := 1
    src := ""
    try src := KP_Read("hold_keys.ahk")
    for prefix in ["vk1C", "vk1D"]
        for row in KP_HoldRows(src, prefix)
            if !RegExMatch(row.key, "i)^(vk1C|vk1D|vk20)$")
                keys[row.key] := 1
    HotIf(Chord_Ctx)
    for k in keys
        for prefix in ["vk1C", "vk1D"]
            try Hotkey(prefix " & " k, Chord_Nop)
    HotIf()
}

Chord_InstallCatchAll()
