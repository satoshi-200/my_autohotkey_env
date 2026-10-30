#Requires AutoHotkey v2.0
;==============================================================================
; keymap_view.ahk
; キー割り当ての見える化：keymap\ の hold_keys.ahk・leader_keys.ahk・chord_keys.ahk を読み、
; JIS 配列のキーボード図の上に、レイヤーごとの割り当てを表示する HTML を作ってブラウザで開く。同じ画面の「設定」タブで、設定値（settings_view.ahk）も確認・編集できる
;   Keymap_Show()  … クイックメニューの「システム → キー割り当て一覧」から呼ぶ
;   起動時（Insert での再読み込みを含む）にも HTML を作り直すので、開いたままのブラウザは F5 で最新になる
;
; 読み取る形式（上の 3 ファイルの書き方に合わせてある）
;   押しながら使うレイヤー： 起点 & キー::  処理  ; コメント（chord_keys.ahk は、無変換側の行を読む）
;   単独のホットキー（短押し・特殊）： キー::  処理  ; コメント（処理が return なら割り当てなし）
;   入力待ちの表：           "キー",  処理,  ; コメント   ／   0x0F, 処理)  ; コメント（処理が "" なら割り当てなし）
; 表示する文字は、コメントがあればコメント、なければ処理から作る（SendInput の中身はキー名に直す）。
; 関数名だけの処理は KM_FUNC_NAMES で日本語にする。載っていない関数は関数名のまま表示する。
; 画面のひな形は keymap_view.html（__DATA__ の部分に割り当てのデータを入れる）。
; 行の読み取り（コメントの分離など）は keymap_parse.ahk と共通（モードのキーの読み替えや入力待ちの一覧も同じものを使う）。
;==============================================================================
#Include %A_LineFile%\..\keymap_parse.ahk
#Include %A_LineFile%\..\settings_view.ahk
#Include %A_LineFile%\..\ui_common.ahk

; 関数名 → 表示名（キー割り当てに出てくるもの）
KM_FUNC_NAMES := Km_Map(
    "MousePlain_Right", "マウス →", "MousePlain_Left", "マウス ←", "MousePlain_Up", "マウス ↑", "MousePlain_Down", "マウス ↓",
    "MousePlain_ScrollUp", "スクロール ↑", "MousePlain_ScrollDown", "スクロール ↓",
    "MousePlain_ScrollLeft", "スクロール ←", "MousePlain_ScrollRight", "スクロール →",
    "MouseNav_WarpWindow", "ウィンドウの中央へ", "MouseNav_WarpCenter", "モニターの中央へ",
    "MouseNav_WarpExternalCenter", "外付けモニターの中央へ", "MouseNav_WarpVertical", "縦のモニターへ",
    "MouseClick", "クリック", "Mouse_ToggleDrag", "ドラッグ開始／解除", "Mouse_FocusUnderCursor", "カーソル下をアクティブに",
    "Mouse_ContextMenu", "右クリックメニュー", "Text_WheelCursor", "ホイールでカーソル移動",
    "Text_BulletPoint", "箇条書き「- 」", "Text_CapitalizeNext", "次の 1 文字を大文字に", "Text_InsertDate", "日付の入力",
    "AltTab", "次のアプリへ", "ShiftAltTab", "前のアプリへ", "ScreenSaver_Toggle", "スクリーンセーバー回避の切り替え",
    "ScreenSaver_Off", "スクリーンセーバー回避を解除",
    "Leader_SpaceF", "Space+F の入力待ち", "Leader_SpaceA", "Space+A の入力待ち", "Leader_Caps", "Caps の入力待ち",
    "Leader_Kana", "かな：アプリ専用の機能（Outlook：s メール選択、Office：e 図形編集、VS Code：f 折りたたみ、Obsidian：リンク選択）",
    "WindowMonitor_Show", "ウィンドウを別のモニターへ",
    "AppSwitcher_Show", "アプリ切り替え", "TabPageSwitcher_Show", "タブ・ページ切り替え",
    "QuickPalette_Show", "コマンドパレット", "QuickMenu_Show", "クイックメニュー", "QM_SymbolMenu_Show", "記号メニュー",
    "QM_DesktopMenu_Show", "仮想デスクトップメニュー", "QM_DateMenu_Show", "日付・時刻メニュー", "QM_DateQuick_Show", "日付・時刻の一覧",
    "QM_CaptureMenu_Show", "画面キャプチャメニュー", "VimiumC_ShowHints", "Vimium C 風ヒント",
    "Oneshot_FnOrCtrlNum", "Fn キー / Ctrl + 数字キー", "Oneshot_AltChar", "Alt + 文字キー", "Oneshot_CtrlChar", "Ctrl + 文字キー",
    "Oneshot_CtrlShiftChar", "Ctrl+Shift + 文字キー", "Oneshot_WinChar", "Win + 文字キー", "Oneshot_CtrlNum", "Ctrl + 数字キー",
    "Ime_Alnum", "IME 半角英数", "Ime_Hiragana", "IME ひらがな", "ShiftHold_Toggle", "Shift 長押しモード", "ShiftHold_Start", "Shift 長押しモード",
    "Ime_AlnumCommit", "IME 半角英数（未確定は確定）", "LastInput_SpaceTap", "空白を入力",
    "Window_CloseAndFocus", "ウィンドウを閉じてカーソル下にフォーカス", "MouseGrid_Start", "カーソル移動モード",
    "LastInput_Recall", "直前の入力をもう一度入力", "LastInput_RecallChar", "直前の 1 文字をもう一度入力")

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
        path := Km_WriteHtml()
    catch as e {
        MsgBox("キー割り当て・設定の画面を作れませんでした。`n" e.Message, "キー割り当て・設定")
        return
    }
    try
        Km_ShowWindow(path)
    catch                                                        ; WebView2 が使えないときは、編集なしでブラウザに出す
        Run(path)
}

; HTML を作って一時フォルダに書き出し、そのパスを返す
Km_WriteHtml() {
    html := Km_BuildHtml()
    path := A_Temp "\keymap_view.html"
    f := FileOpen(path, "w", "UTF-8-RAW")
    f.Write(html)
    f.Close()
    return path
}

Km_BuildHtml() {
    dir := Km_KeymapDir()
    hold := FileRead(dir "\hold_keys.ahk", "UTF-8")
    lead := FileRead(dir "\leader_keys.ahk", "UTF-8")
    chord := FileRead(dir "\chord_keys.ahk", "UTF-8")
    chordo := FileRead(dir "\chord_ordered_keys.ahk", "UTF-8")
    hf := "hold_keys.ahk", lf := "leader_keys.ahk", cf := "chord_keys.ahk", cof := "chord_ordered_keys.ahk"
    layers := [
        Km_Layer("変換 +", ["079"], "変換キーを押しながら押すキー", Km_ParseHold(hold, "vk1C", hf), "hold", "vk1C", hf),
        Km_Layer("無変換 +", ["07B"], "無変換キーを押しながら押すキー", Km_ParseHold(hold, "vk1D", hf), "hold", "vk1D", hf),
        Km_Layer("Space +", ["039"], "Space を押しながら押すキー（Space+F / Space+A は入力待ちになる）", Km_ParseHold(hold, "vk20", hf), "hold", "vk20", hf),
        Km_Layer("変換→無変換 +", ["079", "07B"], "変換を先に押して、押したまま無変換を押し、さらに押すキー（同じ処理を 2 つの起点に書くので、表示は無変換側の行。割り当てのないキーは何も起きない）", Km_ParseHold(chord, "vk1D", cf), "hold", "vk1D", cf),
        Km_Layer("無変換→変換 +", ["07B", "079"], "無変換を先に押して、押したまま変換を押し、さらに押すキー（表示は無変換側の行。割り当てのないキーは何も起きない）", Km_ParseHold(chordo, "vk1D", cof), "hold", "vk1D", cof),
        Km_Layer("Caps →", ["03A"], "CapsLock を押して離したあと、次に押すキー", Km_ParseLeader(lead, "Leader_Caps", lf), "leader", "Leader_Caps", lf),
        Km_Layer("Space+F →", ["039", "021"], "Space+F を押して離したあと、次に押すキー", Km_ParseLeader(lead, "Leader_SpaceF", lf), "leader", "Leader_SpaceF", lf),
        Km_Layer("Space+A →", ["039", "01E"], "Space+A を押して離したあと、次に押すキー（右手側の文字を左手で入力）", Km_ParseLeader(lead, "Leader_SpaceA", lf), "leader", "Leader_SpaceA", lf),
        Km_Layer("短押し", [], "変換・無変換・Space を単独で押して離したとき（押している間に組み合わせを使わなかったとき）に働く。元のキーの働きは置き換わる", Km_ParseHotkeys(hold, hf), "hotkey", "", hf),
        Km_Layer("特殊", [], "基本のキーボード入力では使わない、単独で働くキー（修飾キーとの組み合わせを含む）。Logi Options+ などの外部ツールのボタンから呼ぶ用の押しにくい組み合わせ。Caps は入力待ちの起点", Km_ParseHotkeys(lead, lf), "hotkey", "", lf)]
    hist := Km_HistLoad()
    json := "{`"layers`":["
    for i, ly in layers
        json .= (i > 1 ? "," : "") Km_LayerJson(ly, hist)
    json .= "],`"settings`":" Set_Json(hist) "}"
    return StrReplace(FileRead(A_LineFile "\..\keymap_view.html", "UTF-8"), "__DATA__", json)
}

Km_KeymapDir() => KP_Dir()

; kind："hold"（押しながら）/ "leader"（入力待ち）。anchor：起点（vk1C など）または表の関数名。file：書かれているファイル（行を足すときに使う）
Km_Layer(name, origin, note, parsed, kind, anchor, file) => {name: name, origin: origin, note: note, keys: parsed.keys, extra: parsed.extra, blank: parsed.blank
    , kind: kind, anchor: anchor, file: file}

;------------------------------------------------------------------------------
; 読み取り
;------------------------------------------------------------------------------
; 「prefix & キー::  処理  ; コメント」の行を読む。キーは最初に書かれたものを採る（AutoHotkey も同じ）
; 各項目に、書かれているファイル名・行番号・元の行を持たせる（編集で使う）。割り当てのない行は blank に入れる
Km_ParseHold(src, prefix, file) {
    keys := Map(), extra := [], blank := Map()
    for row in KP_HoldRows(src, prefix) {
        if (row.action = "return" || row.action = "") {
            Km_AddBlank(blank, row.key, Km_Sc(row.key), file, row.lineNo, row.raw)
            continue
        }
        Km_Add(keys, extra, row.key, Km_Sc(row.key), Km_Label(row.action, row.comment), row.action, file, row.lineNo, row.raw)
    }
    Km_DropAssigned(blank, keys)
    return {keys: keys, extra: extra, blank: blank}
}

; 関数 fn の中の「"キー", 処理」「0x79, 処理」の行を読む
Km_ParseLeader(src, fn, file) {
    keys := Map(), extra := [], blank := Map()
    for row in KP_LeaderRows(src, fn) {
        sc := row.special ? Km_Hex(Integer(row.key)) : Km_Sc(row.key)
        comment := row.special ? RegExReplace(row.comment, "^[^：]+：") : row.comment   ; 「Tab：…」の先頭はキー名なので除く
        if (row.action = "" || row.action = '""') {
            Km_AddBlank(blank, row.key, sc, file, row.lineNo, row.raw)
            continue
        }
        Km_Add(keys, extra, row.key, sc, Km_Label(row.action, comment), row.action, file, row.lineNo, row.raw)
    }
    Km_DropAssigned(blank, keys)
    return {keys: keys, extra: extra, blank: blank}
}

; 起点キーの欄の「キー::  処理  ; コメント」を読む（Caps、Ctrl+Shift+Alt+F12、変換・無変換・Space の短押しなど）。修飾キーを除いたキーの位置に表示する
;   処理が return の行は、割り当てなし
Km_ParseHotkeys(src, file) {
    static vkNames := Km_Map("vk1C", "変換", "vk1D", "無変換", "vk20", "Space")
    keys := Map(), extra := [], blank := Map()
    for row in KP_HotkeyRows(src) {
        base := RegExReplace(row.key, "^[\^+!#*~$<>]+")
        prefix := SubStr(row.key, 1, StrLen(row.key) - StrLen(base))
        mods := ""
        for pair in [["^", "Ctrl+"], ["+", "Shift+"], ["!", "Alt+"], ["#", "Win+"]]
            mods .= InStr(prefix, pair[1]) ? pair[2] : ""
        shown := vkNames.Get(base, RegExMatch(base, "i)^(sc|vk)[0-9a-f]+$") ? GetKeyName(base) : base)
        if (shown = "")
            shown := (Km_Sc(base) = "03A") ? "Caps" : base
        if (row.action = "return" || row.action = "") {
            Km_AddBlank(blank, mods shown, Km_Sc(base), file, row.lineNo, row.raw)
            continue
        }
        Km_Add(keys, extra, mods shown, Km_Sc(base), Km_Label(row.action, row.comment), row.action, file, row.lineNo, row.raw)
    }
    Km_DropAssigned(blank, keys)
    return {keys: keys, extra: extra, blank: blank}
}

Km_Add(keys, extra, name, sc, label, src, file, lineNo, raw) {
    item := {n: name, t: label, s: src, f: file, l: lineNo, r: raw}
    if (sc = "")
        extra.Push(item)
    else if !keys.Has(sc)
        keys[sc] := item
}

; 割り当てのない行（編集で割り当てを足せる場所）
Km_AddBlank(blank, name, sc, file, lineNo, raw) {
    if (sc != "" && !blank.Has(sc))
        blank[sc] := {n: name, t: "", s: "", f: file, l: lineNo, r: raw}
}

; 別の行で割り当て済みのキーは、空き扱いから外す
Km_DropAssigned(blank, keys) {
    for sc in keys
        if blank.Has(sc)
            blank.Delete(sc)
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
    s := RegExReplace(s, "``(.)", "$1")                           ; AutoHotkey のエスケープ（`; や ``）を外す
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
Km_LayerJson(ly, hist) {
    keys := ""
    for sc, it in ly.keys
        keys .= (keys != "" ? "," : "") Km_Q(sc) ":" Km_ItemJson(it, ly.name, hist)
    blank := ""
    for sc, it in ly.blank
        blank .= (blank != "" ? "," : "") Km_Q(sc) ":" Km_ItemJson(it, ly.name, hist)
    extra := ""
    for it in ly.extra
        extra .= (extra != "" ? "," : "") Km_ItemJson(it, ly.name, hist)
    origin := ""
    for sc in ly.origin
        origin .= (origin != "" ? "," : "") Km_Q(sc)
    return "{`"name`":" Km_Q(ly.name) ",`"note`":" Km_Q(ly.note) ",`"kind`":" Km_Q(ly.kind) ",`"anchor`":" Km_Q(ly.anchor)
        . ",`"file`":" Km_Q(ly.file) ",`"origin`":[" origin "],`"keys`":{" keys "},`"blank`":{" blank "},`"extra`":[" extra "]}"
}

; n・t・s：表示用、f・l・r：書かれているファイルと行番号と元の行、p：1 つ前の内容（なければ空）
Km_ItemJson(it, layerName, hist) {
    id := Km_HistKey(it.f, layerName, it.n)
    return "{`"n`":" Km_Q(it.n) ",`"t`":" Km_Q(it.t) ",`"s`":" Km_Q(it.s) ",`"f`":" Km_Q(it.f) ",`"l`":" it.l
        . ",`"r`":" Km_Q(it.r) ",`"p`":" Km_Q(hist.Get(id, "")) "}"
}

Km_Q(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, "<", "\u003c")
    return '"' s '"'
}

;==============================================================================
; 編集（WebView2 のウィンドウで開いたとき）
;   一覧のキーをクリック → その行を書き換えて「確定」 → keymap\ のファイルに保存する。
;   ・保存の前に、元の行が変わっていないかを確かめる（別に編集していたら保存しない）。
;   ・保存後に main.ahk の構文を確かめ、エラーなら元の内容に戻す。
;   ・保存前の内容は、キーごとに 1 つ前の分を keymap\.history.tsv に覚える（「1 つ前に戻す」用）。
;     ファイル全体の 1 つ前の複製も keymap\.backup\ に残す。
;   ・動いているスクリプトへの反映は Insert（再読み込み）のあと。
;   ・WebView2 は Lib\webview2\（thqby/ahk2_lib の WebView2.ahk と、Microsoft の WebView2Loader.dll）を使う。
;==============================================================================
#Include %A_LineFile%\..\webview2\WebView2.ahk

KM_SEP := Chr(31)                                  ; ページから届く文字列の区切り
KM_EDITABLE_FILES := ["hold_keys.ahk", "leader_keys.ahk", "chord_keys.ahk", "chord_ordered_keys.ahk"]
KM_VALIDATE_TIMEOUT_MS := 8000

KM_win := 0
KM_wvc := 0
KM_wv := 0
KM_msgToken := 0
KM_navToken := 0

Km_ShowWindow(path) {
    global KM_win, KM_wvc, KM_wv, KM_msgToken, KM_navToken
    url := "file:///" StrReplace(path, "\", "/")
    if (KM_win && WinExist("ahk_id " KM_win.Hwnd)) {
        KM_wv.Navigate(url)
        KM_win.Show()
        WinActivate("ahk_id " KM_win.Hwnd)
        return
    }
    Km_WorkArea(&l, &t, &r, &b)
    w := (r - l) * 9 // 10, h := (b - t) * 9 // 10
    g := Gui("+Resize -DPIScale", "キー割り当て・設定")
    g.OnEvent("Size", Km_OnSize)
    g.OnEvent("Close", Km_CloseWindow)
    g.Show("x" (l + (r - l - w) // 2) " y" (t + (b - t - h) // 2) " w" w " h" h)
    try {
        dataDir := EnvGet("LOCALAPPDATA") "\my_autohotkey_env\webview2"
        wvc := WebView2.CreateControllerAsync(g.Hwnd, 0, dataDir).await2(20000)
    } catch as e {
        g.Destroy()
        throw e
    }
    KM_win := g, KM_wvc := wvc, KM_wv := wvc.CoreWebView2
    wvc.Fill()
    KM_msgToken := KM_wv.WebMessageReceived(Km_OnMessage)
    KM_navToken := KM_wv.NavigationCompleted(Km_OnNavDone)
    KM_wv.Navigate(url)
}

; 読み込みが終わってもページにキーボードフォーカスがないと、クリックするまで数字キー・Ctrl+Tab が届かない
Km_OnNavDone(sender, args) {
    SetTimer(Km_FocusPage, -1)
}

Km_FocusPage() {
    if (KM_wvc && KM_win && WinActive("ahk_id " KM_win.Hwnd))
        KM_wvc.MoveFocus(0)
}

; カーソルのあるモニターの作業領域
Km_WorkArea(&l, &t, &r, &b) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    MonitorGetWorkArea(UI_MonitorFromPoint(mx, my), &l, &t, &r, &b)
}

Km_OnSize(guiObj, minMax, width, height) {
    if (minMax != -1 && KM_wvc)
        KM_wvc.Fill()
}

Km_CloseWindow(*) {
    global KM_win, KM_wvc, KM_wv, KM_msgToken, KM_navToken
    KM_msgToken := 0, KM_navToken := 0
    try KM_wvc.Close()
    KM_wvc := 0, KM_wv := 0
    KM_win.Destroy()
    KM_win := 0
}

; ページからのメッセージ。重い処理（構文の確認）をこの通知の中でしないよう、タイマーに回す
Km_OnMessage(sender, args) {
    msg := args.TryGetWebMessageAsString()
    SetTimer(Km_HandleMessage.Bind(msg), -1)
}

Km_HandleMessage(msg) {
    parts := StrSplit(msg, KM_SEP)
    if (parts.Length = 7 && parts[1] = "save")
        res := Km_Save(parts[2], parts[3], parts[4], Integer(parts[5]), parts[6], parts[7])
    else if (parts.Length = 6 && parts[1] = "add")
        res := Km_Insert(parts[2], parts[4], parts[5], parts[6])
    else if (parts.Length = 6 && parts[1] = "setsave")
        res := Set_Save(parts[2], parts[3], Integer(parts[4]), parts[5], parts[6])
    else
        return
    if KM_wv
        KM_wv.ExecuteScriptAsync("window.KM_onResult(" (res.ok ? "true" : "false") "," Km_Q(res.msg) ")")
}

;------------------------------------------------------------------------------
; 保存
;------------------------------------------------------------------------------
; file の lineNo 行目（元の内容 raw）を newText に置き換える。結果は {ok, msg}
Km_Save(file, layerName, keyName, lineNo, raw, newText) {
    if !(Km_IsKeymapFile(file) || Set_IsEditableFile(file))
        return {ok: false, msg: "このファイルは編集できません。"}
    newText := RTrim(newText, " `t")
    if (newText = "" || RegExMatch(newText, "[\r\n]"))
        return {ok: false, msg: "1 行で、空でない内容を入力してください。"}
    if (newText == raw)
        return {ok: false, msg: "変更がありません。"}

    dir := Km_KeymapDir()
    path := Km_FilePath(file)
    content := FileRead(path, "UTF-8")
    if !Km_FindLine(content, lineNo, raw, &s, &e, &cr)
        return {ok: false, msg: "ファイルがほかで書き換えられています。F5 で更新してから、やり直してください。"}

    DirCreate(dir "\.backup")
    FileCopy(path, dir "\.backup\" StrReplace(file, "\", "_") ".bak", true)
    Km_WriteFile(path, SubStr(content, 1, s - 1) newText cr SubStr(content, e))

    err := Km_Validate()
    if (err != "") {
        Km_WriteFile(path, content)
        return {ok: false, msg: "構文を確認できなかったので、保存しませんでした。`n" err}
    }

    hist := Km_HistLoad()
    hist[Km_HistKey(file, layerName, keyName)] := raw
    Km_HistSave(hist)
    try Km_WriteHtml()
    return {ok: true, msg: "保存しました（" file " の " lineNo " 行目）。Insert で再読み込みすると反映されます。"}
}

; 行がまだ無いキー・組み合わせに、新しい行を足す。結果は {ok, msg}
;   kind "hold"   … anchor のレイヤー（vk1C など）の最後の行のあとへ。「anchor & キー::  処理」
;   kind "leader" … anchor の関数（Leader_Caps など）の表の先頭へ。「"キー",  処理」は keys の表、「0x79,  処理」は specials の表
; 保存後の手順（元のファイルの複製、構文の確認、エラーなら元に戻す）は Km_Save と同じ
Km_Insert(file, kind, anchor, newText) {
    if !Km_IsKeymapFile(file)
        return {ok: false, msg: "このファイルは編集できません。"}
    newText := Trim(newText, " `t")
    if (newText = "" || RegExMatch(newText, "[\r\n]"))
        return {ok: false, msg: "1 行で、空でない内容を入力してください。"}

    dir := Km_KeymapDir()
    path := dir "\" file
    content := FileRead(path, "UTF-8")
    lines := StrSplit(content, "`n")                       ; 各行の末尾に CR が残ることがある
    cr := (lines.Length && SubStr(lines[1], -1) = "`r") ? "`r" : ""

    if (kind = "hold") {
        if !RegExMatch(newText, "i)^" anchor " & (\S+?)::", &nm)
            return {ok: false, msg: "「" anchor " & キー::  処理」の形で書いてください。"}
        last := 0
        for i, l in lines {
            if RegExMatch(l, "i)^" anchor " & (\S+?)::", &m) {
                last := i
                if (m[1] = nm[1])
                    return {ok: false, msg: "すでに同じキーの行があります（" i " 行目）。"}
            }
        }
        if !last
            return {ok: false, msg: file " に " anchor " の行が見つかりません。"}
        at := last + 1, text := newText
        if RegExMatch(file, "^chord\w*\.ahk$")            ; 3 キーの割り当ては、もう一方の起点を上の行に重ねて書く（同じ処理が 2 つの起点で働く）
            text := "vk1C & " nm[1] "::" cr "`n" newText
    }
    else if (kind = "leader") {
        fnLine := 0
        for i, l in lines {
            if RegExMatch(l, "^" anchor "\(\)\s*\{") {
                fnLine := i
                break
            }
        }
        if !fnLine
            return {ok: false, msg: file " に " anchor "() が見つかりません。"}
        fnEnd := lines.Length
        for i, l in lines {
            if (i > fnLine && SubStr(l, 1, 1) = "}") {
                fnEnd := i
                break
            }
        }
        if RegExMatch(newText, "^0x([0-9A-Fa-f]+),", &nm)
            table := "specials", newKey := Integer("0x" nm[1])
        else if RegExMatch(newText, '^"(.)",', &nm)
            table := "keys", newKey := StrLower(nm[1])
        else
            return {ok: false, msg: '「"キー",  処理」または「0x79,  処理」の形で書いてください。'}
        head := 0
        loop fnEnd - fnLine - 1 {
            i := fnLine + A_Index
            l := lines[i]
            if (!head && RegExMatch(l, "^\s*static " table " := " (table = "keys" ? "Leader_Keys" : "Map") "\(\s*$"))
                head := i
            else if (table = "keys" && RegExMatch(l, '^\s*"(.)",', &m) && StrLower(m[1]) = newKey)
                return {ok: false, msg: "すでに同じキーの行があります（" i " 行目）。"}
            else if (table = "specials" && RegExMatch(l, "^\s*(?:static specials := Map\()?0x([0-9A-Fa-f]+),", &m) && Integer("0x" m[1]) = newKey)
                return {ok: false, msg: "すでに同じキーの行があります（" i " 行目）。"}
        }
        if !head
            return {ok: false, msg: anchor "() には、" (table = "keys" ? "文字キー" : "特殊キー") "の表がありません。"}
        ; 表の先頭へ入れるので、後ろに表の行が続くときは末尾にカンマが要る（空の表だけ要らない）
        needComma := !RegExMatch(lines[head + 1], "^\s*\)")
        KP_SplitComment(newText, &action, &comment)
        if (needComma && SubStr(action, -1) != ",")
            action .= ","
        else if (!needComma && SubStr(action, -1) = ",")
            action := RTrim(SubStr(action, 1, -1))
        at := head + 1
        text := "        " action (comment != "" ? "  `; " comment : "")
    }
    else
        return {ok: false, msg: "足せない種類のレイヤーです。"}

    lines.InsertAt(at, text cr)
    out := ""
    for i, l in lines
        out .= (i > 1 ? "`n" : "") l

    DirCreate(dir "\.backup")
    FileCopy(path, dir "\.backup\" file ".bak", true)
    Km_WriteFile(path, out)

    err := Km_Validate()
    if (err != "") {
        Km_WriteFile(path, content)
        return {ok: false, msg: "構文を確認できなかったので、保存しませんでした。`n" err}
    }
    try Km_WriteHtml()
    return {ok: true, msg: "行を足しました（" file " の " at " 行目）。Insert で再読み込みすると反映されます。"}
}

; keymap\ の編集できるファイル名。設定のファイルは「Lib\config.ahk」のようにリポジトリの直下からのパスで渡される
Km_IsKeymapFile(file) {
    for f in KM_EDITABLE_FILES
        if (f = file)
            return true
    return false
}

Km_FilePath(file) => Km_IsKeymapFile(file) ? Km_KeymapDir() "\" file : Set_Root() "\" file

; lineNo 行目が raw と同じなら、その範囲（s ～ e の手前。cr は行末の CR）を返す。
; 行番号がずれていたときは、同じ内容の行がちょうど 1 つだけなら、それを使う
Km_FindLine(content, lineNo, raw, &s, &e, &cr) {
    if (Km_LineRange(content, lineNo, &s, &e, &cr, &text) && text == raw)
        return true
    found := 0, n := 0
    while Km_LineRange(content, ++n, &s1, &e1, &cr1, &text1) {
        if (text1 == raw) {
            if found
                return false
            found := n
        }
    }
    return found && Km_LineRange(content, found, &s, &e, &cr, &text)
}

; n 行目の範囲を返す。s：開始位置、e：行末（改行の位置）、cr：行末の CR、text：CR を除いた内容
Km_LineRange(content, n, &s, &e, &cr, &text) {
    s := 1
    loop n - 1 {
        p := InStr(content, "`n", , s)
        if !p
            return false
        s := p + 1
    }
    if (s > StrLen(content))
        return false
    e := InStr(content, "`n", , s) || StrLen(content) + 1
    seg := SubStr(content, s, e - s)
    cr := (SubStr(seg, -1) = "`r") ? "`r" : ""
    text := cr ? SubStr(seg, 1, -1) : seg
    return true
}

Km_WriteFile(path, text) {
    f := FileOpen(path, "w", "UTF-8-RAW")
    f.Write(text)
    f.Close()
}

; main.ahk の構文を確かめる。問題がなければ ""、あれば内容を返す。
; 終了コードはエラーでも 0 になるため、出力の有無で判定する。終わらないとき（存在しない関数名など）も不可とする
Km_Validate() {
    main := RegExReplace(A_LineFile, "\\Lib\\[^\\]+$") "\main.ahk"
    try
        proc := ComObject("WScript.Shell").Exec('"' A_AhkPath '" /ErrorStdOut /validate "' main '"')
    catch
        return "構文の確認を実行できませんでした。"
    start := A_TickCount
    while (proc.Status = 0 && A_TickCount - start < KM_VALIDATE_TIMEOUT_MS)
        Sleep(50)
    if (proc.Status = 0) {
        try proc.Terminate()
        return "構文の確認が終わりませんでした（存在しない関数名などが原因の可能性があります）。"
    }
    out := Trim(proc.StdOut.ReadAll() proc.StdErr.ReadAll(), " `t`r`n")
    return SubStr(out, 1, 600)
}

;------------------------------------------------------------------------------
; 1 つ前の内容の記録（keymap\.history.tsv：「ファイル|レイヤー|キー」＜タブ＞「行の内容」）
;------------------------------------------------------------------------------
Km_HistPath() => Km_KeymapDir() "\.history.tsv"

Km_HistKey(file, layerName, keyName) => file "|" layerName "|" keyName

Km_HistLoad() {
    hist := Map()
    path := Km_HistPath()
    if !FileExist(path)
        return hist
    loop parse FileRead(path, "UTF-8"), "`n", "`r" {
        p := InStr(A_LoopField, "`t")
        if (p > 1)
            hist[SubStr(A_LoopField, 1, p - 1)] := SubStr(A_LoopField, p + 1)
    }
    return hist
}

Km_HistSave(hist) {
    out := ""
    for k, v in hist
        out .= k "`t" v "`r`n"
    Km_WriteFile(Km_HistPath(), out)
}

; スクリプトの起動（Insert での再読み込みを含む）のたびに HTML を作り直す（このファイルの初期化が終わったあとに行う）。
; 開いたままのページは F5 で最新になる。失敗しても起動は続ける
try Km_WriteHtml()
