#Requires AutoHotkey v2.0
;==============================================================================
; keymap_parse.ahk
; keymap\ のキー割り当て表（hold_keys.ahk・leader_keys.ahk）を読む共通部品。関数は KP_ で始める
;   KP_Dir() / KP_Read(name)        keymap フォルダ／その中のファイルの中身
;   KP_HoldRows(src, prefix)        「prefix & キー::  処理  ; コメント」の行
;   KP_LeaderRows(src, fn)          入力待ちの関数 fn の表の「"キー",  処理,  ; コメント」「0x79, 処理」の行
;   KP_HotkeyRows(src)              起点キーの欄の単独のホットキー（Caps、Ctrl+Shift+Alt+F12 など）の行
;   KP_SplitComment / KP_TrimAction 行末のコメントを分ける／表の行の末尾のカンマと閉じ括弧を除く
; 使う部品：keymap_view.ahk（割り当て一覧）、key_wait.ahk（モードでのキーの読み替え）、leader_keys.ahk（入力待ちの一覧）
; 表の書き方を変えるときは、ここだけを直す
;==============================================================================

KP_Dir() => RegExReplace(A_LineFile, "\\Lib\\[^\\]+$") "\keymap"

KP_Read(name) => FileRead(KP_Dir() "\" name, "UTF-8")

; 返す行：{key, action, comment, lineNo, raw}（action が "" や "return" のときは割り当てなし）
KP_HoldRows(src, prefix) {
    rows := []
    loop parse src, "`n", "`r" {
        if !RegExMatch(A_LoopField, "^" prefix " & (.+?)::\s*(.*)$", &m)
            continue
        KP_SplitComment(m[2], &action, &comment)
        rows.Push({key: m[1], action: action, comment: comment, lineNo: A_Index, raw: A_LoopField})
    }
    return rows
}

; 返す行：{key, action, comment, lineNo, raw}。起点キーの欄（「#HotIf !IH_waiting」で始まる行から次の「#HotIf」まで。複数あってもよい）にある、単独のホットキー「キー::  処理  ; コメント」
;   key は修飾キーを含むホットキーの名前（例：sc03A、^+!F12）
KP_HotkeyRows(src) {
    rows := [], inBlock := false
    loop parse src, "`n", "`r" {
        line := A_LoopField
        if RegExMatch(line, "^#HotIf\b") {
            inBlock := RegExMatch(line, "^#HotIf !IH_waiting\b") > 0
            continue
        }
        if !inBlock
            continue
        if !RegExMatch(line, "^(\S+?)::\s*(.*)$", &m)
            continue
        KP_SplitComment(m[2], &action, &comment)
        rows.Push({key: m[1], action: action, comment: comment, lineNo: A_Index, raw: line})
    }
    return rows
}

; 返す行：{key, special, action, comment, lineNo, raw}
;   文字キーの行は key が 1 文字（special = false）、特殊キーの行は key が "0x79" など（special = true）
;   action が "" や '""' のときは割り当てなし
KP_LeaderRows(src, fn) {
    rows := [], inFn := false
    loop parse src, "`n", "`r" {
        line := A_LoopField
        if !inFn {
            inFn := RegExMatch(line, "^" fn "\(\)\s*\{")
            continue
        }
        if (SubStr(line, 1, 1) = "}")
            break
        if RegExMatch(line, '^\s*"(.)",\s*(.*)$', &m)
            key := m[1], special := false, rest := m[2]
        else if RegExMatch(line, "^\s*(?:static specials := Map\()?(0x[0-9A-Fa-f]+),\s*(.*)$", &m)
            key := m[1], special := true, rest := m[2]
        else
            continue
        KP_SplitComment(rest, &action, &comment)
        rows.Push({key: key, special: special, action: KP_TrimAction(action), comment: comment, lineNo: A_Index, raw: line})
    }
    return rows
}

; 行末のコメント（空白＋「;」）を分ける。引用符の中の「;」は見ない
KP_SplitComment(s, &action, &comment) {
    inQuote := false
    loop StrLen(s) {
        ch := SubStr(s, A_Index, 1)
        if (ch = '"') {
            if (SubStr(s, A_Index - 1, 1) != "``")
                inQuote := !inQuote
        }
        else if (!inQuote && ch = ";" && (A_Index = 1 || RegExMatch(SubStr(s, A_Index - 1, 1), "\s"))) {
            action := Trim(SubStr(s, 1, A_Index - 1)), comment := Trim(SubStr(s, A_Index + 1))
            return
        }
    }
    action := Trim(s), comment := ""
}

; 入力待ちの表の行から、末尾のカンマと、表を閉じる「)」を除く
KP_TrimAction(action) {
    action := RTrim(action)
    if (SubStr(action, -1) = ",")
        action := RTrim(SubStr(action, 1, -1))
    StrReplace(action, "(", , , &open), StrReplace(action, ")", , , &close)
    if (close > open)
        action := RTrim(SubStr(action, 1, -1))
    return action
}
