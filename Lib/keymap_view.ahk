#Requires AutoHotkey v2.0
;==============================================================================
; keymap_view.ahk
; キー割り当ての見える化：keymap\hold_keys.ahk と keymap\leader_keys.ahk を読み、
; JIS 配列のキーボード図の上に、レイヤーごとの割り当てを表示する HTML を作ってブラウザで開く
;   Keymap_Show()  … クイックメニューの「システム → キー割り当て一覧」から呼ぶ
;
; 読み取る形式（上の 2 ファイルの書き方に合わせてある）
;   押しながら使うレイヤー： 起点 & キー::  処理  ; コメント
;   入力待ちの表：           "キー",  処理,  ; コメント   ／   0x0F, 処理)  ; コメント
; 表示する文字は、コメントがあればコメント、なければ処理から作る（SendInput の中身はキー名に直す）。
; 関数名だけの処理は KM_FUNC_NAMES で日本語にする。載っていない関数は関数名のまま表示する。
; 画面のひな形は keymap_view.html（__DATA__ の部分に割り当てのデータを入れる）。
;==============================================================================

; 関数名 → 表示名（キー割り当てに出てくるもの）
KM_FUNC_NAMES := Km_Map(
    "MousePlain_Right", "マウス →", "MousePlain_Left", "マウス ←", "MousePlain_Up", "マウス ↑", "MousePlain_Down", "マウス ↓",
    "MousePlain_ScrollUp", "スクロール ↑", "MousePlain_ScrollDown", "スクロール ↓",
    "MousePlain_ScrollLeft", "スクロール ←", "MousePlain_ScrollRight", "スクロール →",
    "MouseNav_JumpLeft", "マウスを左へジャンプ", "MouseNav_JumpRight", "マウスを右へジャンプ",
    "MouseNav_JumpUp", "マウスを上へジャンプ", "MouseNav_JumpDown", "マウスを下へジャンプ",
    "MouseNav_WarpWindow", "ウィンドウの中央へ", "MouseNav_WarpCenter", "モニターの中央へ",
    "MouseNav_WarpExternalCenter", "外付けモニターの中央へ", "MouseNav_WarpMonitor", "次のモニターへ",
    "MouseClick", "クリック", "Mouse_ToggleDrag", "ドラッグ開始／解除", "Mouse_FocusUnderCursor", "カーソル下をアクティブに",
    "Mouse_ContextMenu", "右クリックメニュー", "Text_WheelCursor", "ホイールでカーソル移動",
    "Text_BulletPoint", "箇条書き「- 」", "Text_CapitalizeNext", "次の 1 文字を大文字に", "Text_InsertDate", "日付の入力",
    "AltTab", "次のアプリへ", "ShiftAltTab", "前のアプリへ", "ScreenSaver_Toggle", "スクリーンセーバー回避の切り替え",
    "ScreenSaver_Off", "スクリーンセーバー回避を解除",
    "Leader_SpaceF", "Space+F の入力待ち", "Leader_SpaceA", "Space+A の入力待ち",
    "WindowResizer_Show", "ウィンドウの大きさ", "WindowMonitor_Show", "ウィンドウを別のモニターへ",
    "AppSwitcher_Show", "アプリ切り替え", "TabPageSwitcher_Show", "タブ・ページ切り替え",
    "QuickPalette_Show", "コマンドパレット", "QuickMenu_Show", "クイックメニュー", "QM_SymbolMenu_Show", "記号メニュー",
    "QM_DesktopMenu_Show", "仮想デスクトップメニュー", "QM_DateMenu_Show", "日付・時刻メニュー",
    "QM_CaptureMenu_Show", "画面キャプチャメニュー", "VimiumC_ShowHints", "Vimium C 風ヒント",
    "Oneshot_Fn", "Fn キー", "Oneshot_AltChar", "Alt + 文字キー", "Oneshot_CtrlChar", "Ctrl + 文字キー",
    "Oneshot_CtrlShiftChar", "Ctrl+Shift + 文字キー", "Oneshot_WinChar", "Win + 文字キー", "Oneshot_CtrlNum", "Ctrl + 数字キー",
    "Ime_Alnum", "IME 半角英数", "Ime_Hiragana", "IME ひらがな", "UpperMode_Start", "大文字入力モード",
    "Window_CloseAndFocus", "ウィンドウを閉じてカーソル下にフォーカス")

; SendInput のキー名 → 表示名
KM_KEY_NAMES := Km_Map(
    "Left", "←", "Right", "→", "Up", "↑", "Down", "↓", "Delete", "Del", "BackSpace", "BS", "Escape", "Esc",
    "LWin", "Win", "RWin", "Win", "LCtrl", "Ctrl", "RCtrl", "Ctrl", "LAlt", "Alt", "RAlt", "Alt",
    "LShift", "Shift", "RShift", "Shift", "WheelUp", "ホイール↑", "WheelDown", "ホイール↓", "LButton", "左クリック")

; 大文字・小文字を区別しない Map を作る
Km_Map(pairs*) {
    m := Map()
    m.CaseSense := false
    m.Set(pairs*)
    return m
}

; キー名・文字 → スキャンコード（JIS 配列。16 進 3 桁）
KM_SCAN := Map()
KM_SCAN.CaseSense := false
Km_InitScan() {
    for i, c in StrSplit("1234567890")
        KM_SCAN[c] := Km_Hex(1 + i)
    for i, c in StrSplit("qwertyuiop")
        KM_SCAN[c] := Km_Hex(0x0F + i)
    for i, c in StrSplit("asdfghjkl")
        KM_SCAN[c] := Km_Hex(0x1D + i)
    for i, c in StrSplit("zxcvbnm")
        KM_SCAN[c] := Km_Hex(0x2B + i)
    for i in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        KM_SCAN["F" i] := Km_Hex(0x3A + i)
    KM_SCAN["F11"] := "057", KM_SCAN["F12"] := "058"
    ; 記号（"+" は JIS の「;」、"*" は「:」、"`" は「@」と同じキー）
    for c, sc in Map("-", 0x0C, "^", 0x0D, "\", 0x7D, "@", 0x1A, "``", 0x1A, "[", 0x1B, "]", 0x2B, ";", 0x27, "+", 0x27
        , ":", 0x28, "*", 0x28, ",", 0x33, ".", 0x34, "/", 0x35, "_", 0x73)
        KM_SCAN[c] := Km_Hex(sc)
    for n, sc in Map("LShift", 0x2A, "RShift", 0x136, "LAlt", 0x38, "RAlt", 0x138, "LControl", 0x1D, "RControl", 0x11D
        , "Up", 0x148, "Left", 0x14B, "Down", 0x150, "Right", 0x14D, "PgUp", 0x149, "PgDn", 0x151)
        KM_SCAN[n] := Km_Hex(sc)
}
Km_InitScan()

Km_Hex(n) => Format("{:03X}", n)

;------------------------------------------------------------------------------
; 呼び出し口
;------------------------------------------------------------------------------
Keymap_Show() {
    try
        html := Km_BuildHtml()
    catch as e {
        MsgBox("キー割り当て一覧を作れませんでした。`n" e.Message, "キー割り当て一覧")
        return
    }
    path := A_Temp "\keymap_view.html"
    f := FileOpen(path, "w", "UTF-8-RAW")
    f.Write(html)
    f.Close()
    Run(path)
}

Km_BuildHtml() {
    dir := A_LineFile "\..\..\keymap"
    hold := FileRead(dir "\hold_keys.ahk", "UTF-8")
    lead := FileRead(dir "\leader_keys.ahk", "UTF-8")
    layers := [
        Km_Layer("変換 +", ["079"], "変換キーを押しながら押すキー", Km_ParseHold(hold, "vk1C")),
        Km_Layer("無変換 +", ["07B"], "無変換キーを押しながら押すキー", Km_ParseHold(hold, "vk1D")),
        Km_Layer("Space +", ["039"], "Space を押しながら押すキー（Space+F / Space+A は入力待ちになる）", Km_ParseHold(hold, "vk20")),
        Km_Layer("Caps →", ["03A"], "CapsLock を押して離したあと、次に押すキー", Km_ParseLeader(lead, "Leader_Caps")),
        Km_Layer("Space+F →", ["039", "021"], "Space+F を押して離したあと、次に押すキー", Km_ParseLeader(lead, "Leader_SpaceF")),
        Km_Layer("Space+A →", ["039", "01E"], "Space+A を押して離したあと、次に押すキー（右手側の文字を左手で入力）", Km_ParseLeader(lead, "Leader_SpaceA")),
        Km_Layer("かな →", ["070"], "カタカナひらがなを押して離したあと、次に押すキー", Km_ParseLeader(lead, "Leader_Kana"))]
    json := "{`"layers`":["
    for i, ly in layers
        json .= (i > 1 ? "," : "") Km_LayerJson(ly)
    json .= "]}"
    return StrReplace(FileRead(A_LineFile "\..\keymap_view.html", "UTF-8"), "__DATA__", json)
}

Km_Layer(name, origin, note, parsed) => {name: name, origin: origin, note: note, keys: parsed.keys, extra: parsed.extra}

;------------------------------------------------------------------------------
; 読み取り
;------------------------------------------------------------------------------
; 「prefix & キー::  処理  ; コメント」の行を読む。キーは最初に書かれたものを採る（AutoHotkey も同じ）
Km_ParseHold(src, prefix) {
    keys := Map(), extra := []
    loop parse src, "`n", "`r" {
        if !RegExMatch(A_LoopField, "^" prefix " & (.+?)::\s*(.*)$", &m)
            continue
        Km_SplitComment(m[2], &action, &comment)
        if (action = "return" || action = "")
            continue
        Km_Add(keys, extra, m[1], Km_Sc(m[1]), Km_Label(action, comment), action)
    }
    return {keys: keys, extra: extra}
}

; 関数 fn の中の「"キー", 処理」「0x79, 処理」の行を読む
Km_ParseLeader(src, fn) {
    keys := Map(), extra := []
    inFn := false
    loop parse src, "`n", "`r" {
        line := A_LoopField
        if !inFn {
            inFn := RegExMatch(line, "^" fn "\(\)\s*\{")
            continue
        }
        if (SubStr(line, 1, 1) = "}")
            break
        if RegExMatch(line, '^\s*"(.)",\s*(.*)$', &m)
            name := m[1], sc := Km_Sc(m[1]), rest := m[2]
        else if RegExMatch(line, "^\s*(?:static specials := Map\()?(0x[0-9A-Fa-f]+),\s*(.*)$", &m)
            name := m[1], sc := Km_Hex(Integer(m[1])), rest := m[2]
        else
            continue
        Km_SplitComment(rest, &action, &comment)
        if (SubStr(name, 1, 2) = "0x")
            comment := RegExReplace(comment, "^[^：]+：")          ; 「Tab：…」の先頭はキー名なので除く
        action := Km_TrimAction(action)
        if (action = "" || action = '""')
            continue
        Km_Add(keys, extra, name, sc, Km_Label(action, comment), action)
    }
    return {keys: keys, extra: extra}
}

Km_Add(keys, extra, name, sc, label, src) {
    item := {n: name, t: label, s: src}
    if (sc = "")
        extra.Push(item)
    else if !keys.Has(sc)
        keys[sc] := item
}

; 行末のコメント（空白＋「;」）を分ける。引用符の中の「;」は見ない
Km_SplitComment(s, &action, &comment) {
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
Km_TrimAction(action) {
    action := RTrim(action)
    if (SubStr(action, -1) = ",")
        action := RTrim(SubStr(action, 1, -1))
    StrReplace(action, "(", , , &open), StrReplace(action, ")", , , &close)
    if (close > open)
        action := RTrim(SubStr(action, 1, -1))
    return action
}

; 起点と一緒に書かれたキー名 → スキャンコード（マウスなど、キーボードにないものは ""）
Km_Sc(token) {
    if RegExMatch(token, "i)^sc([0-9a-f]+)$", &m)
        return Km_Hex(Integer("0x" m[1]))
    if RegExMatch(token, "i)^vk([0-9a-f]+)$", &m) {
        vk := Integer("0x" m[1])
        return Km_Hex(vk = 0x1C ? 0x79 : vk = 0x1D ? 0x7B : vk = 0x20 ? 0x39 : GetKeySC(token))
    }
    return KM_SCAN.Get(token, "")
}

;------------------------------------------------------------------------------
; 表示する文字
;------------------------------------------------------------------------------
Km_Label(action, comment) {
    comment := Km_CleanComment(comment)
    if (comment != "")
        return comment
    a := RegExReplace(action, "^\(\)\s*=>\s*")
    if RegExMatch(a, '^"(.*)"$', &m)                              ; 入力待ちの表の「送るキーの文字列」
        return Km_Keys(m[1])
    if !RegExMatch(a, "^(\w+)", &m)
        return a
    fn := m[1]
    if (fn = "SendInput")
        return RegExMatch(a, '^SendInput\("((?:[^"``]|``.)*)"', &s) ? Km_Keys(s[1]) : "キー入力"
    arg := RegExMatch(a, '\("([^"]*)"', &s) ? s[1] : ""
    if (fn = "Text_InsertDate")
        return "日付 " arg
    if (fn = "Text_WheelCursor")
        return "ホイールでカーソル " arg
    return KM_FUNC_NAMES.Get(fn, fn)
}

; 「Tab -> やり直し」は右側だけ使う。「CapsLock」のようにキー名だけのコメントは使わない
Km_CleanComment(c) {
    c := Trim(c)
    if RegExMatch(c, "^.+?\s->\s(.+)$", &m)
        return m[1]
    if RegExMatch(c, "^(CapsLock|Tab|Space|変換|無変換)$")
        return ""
    return c
}

; SendInput("^{Left}") などの文字列を「Ctrl+←」のような表示にする（最初のキーだけ）
Km_Keys(s) {
    s := StrReplace(s, "``")
    s := RegExReplace(s, "i)^\{Blind\}")
    mods := ""
    while (s != "" && InStr("^+!#", SubStr(s, 1, 1))) {
        c := SubStr(s, 1, 1)
        mods .= (c = "^" ? "Ctrl+" : c = "+" ? "Shift+" : c = "!" ? "Alt+" : "Win+")
        s := SubStr(s, 2)
    }
    if (SubStr(s, 1, 1) = "{") {
        if (SubStr(s, 1, 3) = "{}}")
            tok := "}"
        else if (SubStr(s, 1, 3) = "{{}")
            tok := "{"
        else
            tok := SubStr(s, 2, InStr(s, "}") - 2)
    }
    else
        tok := SubStr(s, 1, 1)
    if RegExMatch(tok, "^(\S+) (\d+)$", &m)
        tok := m[1] "×" m[2]
    return mods KM_KEY_NAMES.Get(tok, tok)
}

;------------------------------------------------------------------------------
; JSON
;------------------------------------------------------------------------------
Km_LayerJson(ly) {
    keys := ""
    for sc, it in ly.keys
        keys .= (keys != "" ? "," : "") Km_Q(sc) ":" Km_ItemJson(it)
    extra := ""
    for it in ly.extra
        extra .= (extra != "" ? "," : "") Km_ItemJson(it)
    origin := ""
    for sc in ly.origin
        origin .= (origin != "" ? "," : "") Km_Q(sc)
    return "{`"name`":" Km_Q(ly.name) ",`"note`":" Km_Q(ly.note) ",`"origin`":[" origin "],`"keys`":{" keys "},`"extra`":[" extra "]}"
}

Km_ItemJson(it) => "{`"n`":" Km_Q(it.n) ",`"t`":" Km_Q(it.t) ",`"s`":" Km_Q(it.s) "}"

Km_Q(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, "<", "\u003c")
    return '"' s '"'
}
