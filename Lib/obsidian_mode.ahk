#Requires AutoHotkey v2.0
;==============================================================================
; obsidian_mode.ahk
; Obsidian 専用モード（keymap\leader_keys.ahk の Leader_Kana から呼ぶ。かなキー。Obsidian が前面のときだけ）
;   Obsidian_Mode()  … 次のキーを待ち、Caps を押すと、リンク選択のプラグイン（mrj-jump-to-link）を呼ぶ
;       Caps                    表示内のリンクにヒントを出す（OBSIDIAN_LINK_HOTKEY を送る）
;       Esc / Space+Caps / かな  やめる
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\key_mode.ahk

OBSIDIAN_LINK_HOTKEY := "^j"                        ; リンク選択のプラグインに割り当てたホットキー
OBSIDIAN_MODE_IDLE_SEC := 10                        ; この秒数キー入力がなければ終わる

Obsidian_Mode() {
    st := {}
    IHM_Run(st, {message: _ObsMode_Message, onKey: _ObsMode_OnKey
        , onStart: _ObsMode_Tip, idleSec: OBSIDIAN_MODE_IDLE_SEC, tip: "corner"})
    if (st.result = "link")
        SendInput(OBSIDIAN_LINK_HOTKEY)
}

_ObsMode_Message(st) {
    switch st.result {
        case "link":    return "✅ [Obsidian] リンク選択"
        case "timeout": return "❌ [Obsidian] タイムアウト"
        case "error":   return "⚠️ [Obsidian] 失敗：" st.err
        default:        return "❌ [Obsidian] キャンセル"
    }
}

_ObsMode_Tip(st) {
    IHM_Tip(st, "📝 Obsidian モード　Caps：リンク選択　Esc：やめる")
}

_ObsMode_OnKey(st, k) {
    if k.left
        return
    switch k.sc {
        case 0x3A:
            IHM_Finish(st, st.held.Has(0x39) ? "cancel" : "link")
        case 0x01, 0x70:                            ; Esc / かな
            IHM_Finish(st, "cancel")
    }
}
