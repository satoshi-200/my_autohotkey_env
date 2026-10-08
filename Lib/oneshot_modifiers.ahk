#Requires AutoHotkey v2.0
;==============================================================================
; oneshot_modifiers.ahk
; 次に押したキー 1 つを Fn / Ctrl / Alt / Win 付きで送る入力モード
;   keymap\leader_keys.ahk（Caps → f / l / o / i / ; / , .）から呼ぶ
;==============================================================================
#Include %A_LineFile%\..\key_wait.ahk

; Fn キーの配置（左手のホームポジション周り）。quick_menu.ahk の Fn キーのカテゴリも同じ配置を使う
ONESHOT_FN_KEYS := Map(
    "x", 1,  "c", 2,  "v", 3,
    "s", 4,  "d", 5,  "f", 6,
    "w", 7,  "e", 8,  "r", 9,
    "z", 10, "a", 11, "q", 12)
ONESHOT_FN_HINT := "q:F12  w:F7  e:F8  r:F9`na:F11  s:F4  d:F5  f:F6`nz:F10  x:F1  c:F2  v:F3"

; 数字キーの配置（テンキー風）
ONESHOT_NUM_KEYS := Map(
    "w", 7, "e", 8, "r", 9,
    "s", 4, "d", 5, "f", 6,
    "x", 1, "c", 2, "v", 3,
    "z", 0)
ONESHOT_NUM_HINT := "w:7  e:8  r:9`ns:4  d:5  f:6`nx:1  c:2  v:3`nz:0"

Oneshot_Fn() {
    k := _Oneshot_Wait("Fn キー", ONESHOT_FN_HINT)
    if ONESHOT_FN_KEYS.Has(k)
        SendInput("{F" ONESHOT_FN_KEYS[k] "}")
}

Oneshot_CtrlNum() {
    k := _Oneshot_Wait("Ctrl + 数字キー", ONESHOT_NUM_HINT)
    if ONESHOT_NUM_KEYS.Has(k)
        _Oneshot_SendCtrl(String(ONESHOT_NUM_KEYS[k]))
}

Oneshot_CtrlChar() {
    k := _Oneshot_Wait("Ctrl + 文字キー")
    if RegExMatch(k, "^[a-z1-9]$")
        _Oneshot_SendCtrl(k)
}

Oneshot_CtrlShiftChar() => _Oneshot_Char("^+", "Ctrl + Shift + 文字キー", "^[a-z;]$")
Oneshot_WinChar()       => _Oneshot_Char("#",  "Win + 文字キー",          "^[a-z,.]$")
Oneshot_AltChar()       => _Oneshot_Char("!",  "Alt + 文字キー",          "^[a-z]$")

; キーを 1 つ待って小文字で返す（キャンセル・タイムアウトでは ""）
_Oneshot_Wait(mode, hint := "") {
    if !IH_WaitNext(mode, hint)
        return ""
    k := StrLower(ih.Input)
    ih.Stop()
    return k
}

; pattern に当てはまるキーだけ、修飾キー mods を付けて送る
_Oneshot_Char(mods, mode, pattern) {
    k := _Oneshot_Wait(mode)
    if RegExMatch(k, pattern)
        SendInput(mods "{" k "}")
}

; Ctrl + k を送る。コピー・貼り付け・切り取りは、Ctrl を明示的に押してから送る（取りこぼし対策）
_Oneshot_SendCtrl(k) {
    if (k = "c" || k = "v" || k = "x") {
        try {
            Send("{Ctrl down}")
            Sleep(5)
            Send("{" k "}")
            Sleep(5)
        } finally {
            Send("{Ctrl up}")
        }
    }
    else
        SendInput("^{" k "}")
}
