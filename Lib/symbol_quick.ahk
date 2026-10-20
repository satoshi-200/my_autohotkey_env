#Requires AutoHotkey v2.0
;==============================================================================
; symbol_quick.ahk
; 記号メニューのツールチップ版：小窓を出さず、InputHook でキーを受ける（フォーカスを動かさないので軽い）
;   QM_SymbolQuick_Show()  Caps → k から QM_SymbolMenu_Show（quick_menu.ahk）経由で呼ぶ
;   小窓版（QM_SymbolMenu クラス。矢印 + Enter で選べる）は quick_menu.ahk に残してある。
;   切り替えは quick_menu.ahk の QM_SYMBOL_UI（"tooltip" / "window"）。
;
; 操作
;   英字（一覧のキー） … その記号を入力して終わる
;   Space             … 全角／半角を切り替える（始めは、入力先の IME が全角で入力する状態なら全角）
;   Esc / Caps        … 閉じる
; 記号の一覧と全角の変換は QM_SymbolMenu.Symbols / FULL_OVERRIDE と同じものを使う（二重に書かない）。
;==============================================================================
#Include %A_LineFile%\..\key_mode.ahk
#Include %A_LineFile%\..\text_ops.ahk
#Include %A_LineFile%\..\last_input.ahk

SYMBOLQUICK_COLUMNS := 4                       ; ツールチップで 1 行に並べる記号の数

QM_SymbolQuick_Show() {
    st := {full: QM_TargetImeIsFullWidth(WinExist("A")), ch: ""}   ; ツールチップは前面を奪わないが、念のため始めに調べる
    IHM_Run(st, {message: _SymbolQuick_Message, onKey: _SymbolQuick_OnKey, onStart: _SymbolQuick_Tip
        , layers: false, tip: "cursor"})
    if (st.result = "pick") {
        SendText(st.ch)                                          ; 文字をそのまま入力（キー配列・Shift の影響を受けない）
        LastInput_NoteText(st.ch)                                ; 「直前の 1 文字」に覚える
    }
}

_SymbolQuick_Message(st) {
    switch st.result {
        case "pick":    return ""                                ; 表示は消して、入力した文字だけが残るようにする
        case "timeout": return "❌ [記号] タイムアウト"
        case "error":   return "⚠️ [記号] 失敗：" st.err
        default:        return "❌ [記号] キャンセル"
    }
}

_SymbolQuick_Char(st, sym) {
    if !st.full
        return sym
    if QM_SymbolMenu.FULL_OVERRIDE.Has(sym)
        return QM_SymbolMenu.FULL_OVERRIDE[sym]
    return QM_ToFullAscii(sym)
}

_SymbolQuick_Tip(st) {
    rows := "", n := 0
    for s in QM_SymbolMenu.Symbols {
        rows .= (n = 0 ? "" : (Mod(n, SYMBOLQUICK_COLUMNS) = 0 ? "`n" : "　")) "[" s.key "] " _SymbolQuick_Char(st, s.sym)
        n++
    }
    IHM_Tip(st, "🔣 [記号：" (st.full ? "全角" : "半角") "]　Space：全角／半角　Esc / Caps：閉じる", rows)
}

_SymbolQuick_OnKey(st, k) {
    switch k.sc {
        case 0x01, 0x3A:                           ; Esc / Caps
            IHM_Finish(st, "cancel")
        case 0x39:                                 ; Space：全角／半角
            st.full := !st.full
            _SymbolQuick_Tip(st)
        default:
            for s in QM_SymbolMenu.Symbols {
                if (StrLower(s.key) = k.name) {
                    st.ch := _SymbolQuick_Char(st, s.sym)
                    IHM_Finish(st, "pick")
                    return
                }
            }
    }
}
