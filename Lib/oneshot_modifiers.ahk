#Requires AutoHotkey v2.0
;==============================================================================
; oneshot_modifiers.ahk
; 修飾キー付き入力モード：次に押したキー 1 つを、Fn / Ctrl / Alt / Win 付きで送る
;   keymap\leader_keys.ahk（Caps → f / l / o / i / ; など）から呼ばれる
;   入力待ちの共通部品は key_wait.ahk
;==============================================================================

; 使う部品（単体で開いたときもエディタが変数を見つけられるように。同じファイルは 1 度しか読まれない）
#Include %A_LineFile%\..\key_wait.ahk

; Fn キーの配置（左手のホームポジション周り）
ONESHOT_FN_KEYS := Map(
    "x", 1,  "c", 2,  "v", 3,
    "s", 4,  "d", 5,  "f", 6,
    "w", 7,  "e", 8,  "r", 9,
    "z", 10, "a", 11, "q", 12)
IH_FN_HINT := "q:F12  w:F7  e:F8  r:F9`na:F11  s:F4  d:F5  f:F6`nz:F10  x:F1  c:F2  v:F3"

; 数字キーの配置（テンキー風）
ONESHOT_NUM_KEYS := Map(
    "w", 7, "e", 8, "r", 9,
    "s", 4, "d", 5, "f", 6,
    "x", 1, "c", 2, "v", 3,
    "z", 0)
IH_NUM_HINT := "w:7  e:8  r:9`ns:4  d:5  f:6`nx:1  c:2  v:3`nz:0"

;--- Fn キー ------------------------------------------------------------------
WaitForKeyInput_call_Fnkeys()            => _Oneshot_Fn("",   "Fn キー")
WaitForKeyInput_call_Shift_Fnkeys()      => _Oneshot_Fn("+",  "Shift + Fn キー")
WaitForKeyInput_call_Ctrl_Fnkeys()       => _Oneshot_Fn("^",  "Ctrl + Fn キー")
WaitForKeyInput_call_Ctrl_Shift_Fnkeys() => _Oneshot_Fn("^+", "Ctrl + Shift + Fn キー")

;--- 数字キー（左手で入力）-------------------------------------------------
WaitForKeyInput_call_CtrlNum_keys() {
    k := _Oneshot_Wait("Ctrl + 数字キー", IH_NUM_HINT)
    if ONESHOT_NUM_KEYS.Has(k)
        _Oneshot_SendCtrl(String(ONESHOT_NUM_KEYS[k]))
}

;--- 文字キー -----------------------------------------------------------------
WaitForKeyInput_call_CtrlShiftChar_keys() => _Oneshot_Char("^+", "Ctrl + Shift + 文字キー", "^[a-z;]$")
WaitForKeyInput_call_WinChar_keys()       => _Oneshot_Char("#",  "Win + 文字キー",          "^[a-z,.]$")
WaitForKeyInput_call_AltChar_keys()       => _Oneshot_Char("!",  "Alt + 文字キー",          "^[a-z]$")

WaitForKeyInput_call_CtrlChar_keys() {
    k := _Oneshot_Wait("Ctrl + 文字キー")
    if RegExMatch(k, "^[a-z1-9]$")
        _Oneshot_SendCtrl(k)
}

;--- 共通処理 -----------------------------------------------------------------
; Ctrl + k を送る
_Oneshot_SendCtrl(k) {
    if (k = "c" || k = "v" || k = "x") {
        ; コピー・貼り付け・切り取りは、Ctrl を明示的に押してから送る（2025/08/07 変更）
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

; キーを 1 つ待って小文字で返す（キャンセル・タイムアウト・特殊キーでは ""）
_Oneshot_Wait(mode, hint := "") {
    global ih
    IH_TipWaiting(mode, hint)
    ih.Start()
    ih.Wait()
    if IH_EndWait(mode)
        return ""
    k := StrLower(ih.Input)
    ih.Stop()
    return k
}

_Oneshot_Fn(mods, mode) {
    k := _Oneshot_Wait(mode, IH_FN_HINT)
    if ONESHOT_FN_KEYS.Has(k)
        SendInput(mods "{F" ONESHOT_FN_KEYS[k] "}")
}

; pattern に当てはまるキーだけ送る
_Oneshot_Char(mods, mode, pattern) {
    k := _Oneshot_Wait(mode)
    if RegExMatch(k, pattern)
        SendInput(mods "{" k "}")
}
