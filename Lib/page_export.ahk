#Requires AutoHotkey v2.0
;==============================================================================
; page_export.ahk
; 前面のウィンドウの画面の内容（ラベルと入力欄の値）を Markdown にして、ファイルへ保存しクリップボードにも入れる
;   クイックメニューの「ウィンドウ → E」から呼ぶ（PageExport_Run）
;
; 仕組み
;   UI Automation で画面の部品の木を 1 回で取り（キャッシュ）、順に読む。ブラウザなら Web ページ（Document）の中だけを読む。
;   ・文字（Text）は、同じ親の中で続いているものを 1 つの文にまとめる
;   ・「○○:」で終わる短い文は項目名。次の文か入力欄の値と組にして「- 項目名: 値」にする
;   ・入力欄・プルダウン → 短い 1 行は「- **項目名**: 値」、長い・複数行は「### 項目名」の下に値（スクロールで隠れた部分も含む）
;   ・項目名も値もない入力欄は出さない。ボタン・パスワード欄も出さない
;   ・チェック・ラジオ・選択中のタブ → 一覧・見出し
;   Edge / Chrome は、UI Automation で最初に問い合わせたときに中身の木を作り始めるので、少なければ取り直す
;   別のタブ（画面の切り替え）の内容は、切り替えてからもう一度呼ぶ
;   項目名が取れないときは PAGE_EXPORT_DEBUG を true にすると、部品の木を .tree.txt に書く
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\ui_common.ahk

PAGE_EXPORT_DIR  := EnvGet("USERPROFILE") "\Downloads"   ; 保存先（毎回聞くときは、最初に開くフォルダ）
PAGE_EXPORT_ASK  := true                          ; 保存先を毎回聞くか（キャンセルしたときは保存しない）
PAGE_EXPORT_COPY := true                          ; クリップボードにコピーするか
PAGE_EXPORT_LABEL_MAX := 40                       ; これより短い文字は、直後の入力欄のラベルとみなす
PAGE_EXPORT_DEBUG := false                        ; 部品の木（種類・名前・値）を、保存したファイルの隣に .tree.txt で書く
PAGE_EXPORT_IGNORE := "^(行追加|行削除|上移動|下移動|公報|包袋|キャンセル|保存|保存して送信|差し戻し|プレビュー|Submit|\d+)$|^※"   ; この正規表現に合う文は出さない（ボタン名・行番号・注釈など）

PageExport_Run() {
    hwnd := WinExist("A")
    if !hwnd
        return
    full := WinGetTitle(hwnd)
    short := Trim(StrSplit(full, " - ")[1])
    UI_ToolTip("📝 [ページ書き出し] 取得中...")
    st := ""
    try {
        loop 12 {
            _PageExport_Wake(hwnd)
            st := PageExport_Collect(hwnd, short, true)
            if (st.sawDoc && (st.lines.Length >= 6 || A_Index >= 5))
                break
            Sleep(500)
        }
        if !st.sawDoc                                   ; ページ本体が見つからないアプリは、ウィンドウ全体を読む
            st := PageExport_Collect(hwnd, short, false)
    } catch as e {
        UI_TipFlash("⚠️ [ページ書き出し] 取得に失敗：" e.Message)
        return
    }
    if !IsObject(st) || !st.lines.Length {
        UI_TipFlash("❌ [ページ書き出し] 読み取れる内容がありません")
        return
    }

    text := "# " (short != "" ? short : "ページ") "`n`n取得日時: " FormatTime(, "yyyy/MM/dd HH:mm:ss") "`n`n"
    for l in st.lines
        text .= l "`n"

    msg := "✅ [ページ書き出し] " StrLen(text) " 文字"
    if (PAGE_EXPORT_ASK || PAGE_EXPORT_DIR != "") {   ; 保存先が "" で聞かないなら保存しない
        try {
            dir := (PAGE_EXPORT_DIR != "") ? PAGE_EXPORT_DIR : A_MyDocuments
            DirCreate(dir)
            name := RegExReplace(short, '[\\/:*?"<>|`r`n]', "_")
            path := dir "\" FormatTime(, "yyyyMMdd_HHmmss") "_" SubStr(name, 1, 40) ".md"
            if PAGE_EXPORT_ASK {
                path := FileSelect("S16", path, "ページ書き出しの保存先", "Markdown (*.md)")
                if (path != "" && !RegExMatch(path, "\.[^\\.]+$"))
                    path .= ".md"
            }
            if (path != "") {
                f := FileOpen(path, "w", "UTF-8-RAW")
                f.Write(text)
                f.Close()
                msg .= "`n" path
                if (PAGE_EXPORT_DEBUG && st.dump) {
                    tree := ""
                    for l in st.dump
                        tree .= l "`n"
                    f := FileOpen(path ".tree.txt", "w", "UTF-8-RAW")
                    f.Write(tree)
                    f.Close()
                }
            }
        } catch as e {
            msg .= "`n⚠️ 保存に失敗：" e.Message
        }
    }
    if PAGE_EXPORT_COPY {
        A_Clipboard := text
        msg .= "`n（クリップボードにもコピー）"
    }
    UI_TipFlash(msg, 4000)
}

; hwnd のウィンドウの内容を読み、状態（lines：Markdown の行の配列）を返す。docOnly なら Web ページ（Document）の中だけ
PageExport_Collect(hwnd, title, docOnly) {
    st := {lines: [], pending: "", run: "", seq: 0, lastIdx: 0, lastSeq: -1, title: title, docOnly: docOnly, sawDoc: false
        , dump: PAGE_EXPORT_DEBUG ? [] : 0}
    PageExport_Read(hwnd, st)
    _PageExport_Flush(st)
    tidy := []
    for l in st.lines {
        if (tidy.Length && l != "" && tidy[tidy.Length] != "" && (SubStr(tidy[tidy.Length], 1, 2) = "- ") != (SubStr(l, 1, 2) = "- "))
            tidy.Push("")                                ; 箇条書きと文章を空行で分ける（続けると箇条書きの続きになる）
        tidy.Push(l)
    }
    st.lines := tidy
    return st
}

; Edge / Chrome は、支援技術から問い合わせが来るまでページの中身の木を作らないので、ページ本体の窓へ問い合わせて起こす
_PageExport_Wake(hwnd) {
    if !InStr(WinGetClass(hwnd), "Chrome_WidgetWin")
        return
    try {
        child := DllCall("FindWindowEx", "Ptr", hwnd, "Ptr", 0, "Str", "Chrome_RenderWidgetHostHWND", "Ptr", 0, "Ptr")
        if child {
            SendMessage(0x3D, 0, -25, child, , , , , 200)   ; WM_GETOBJECT, UiaRootObjectId
            SendMessage(0x3D, 0, -4, child, , , , , 200)    ; OBJID_CLIENT
        }
    }
}

PageExport_Read(hwnd, st) {
    static cache := 0
    uia := UI_Uia()
    if !cache {
        ComCall(20, uia, "ptr*", &cr := 0)             ; IUIAutomation::CreateCacheRequest
        for id in [30003, 30005, 30019, 30045, 30079, 30086]   ; ControlType・Name・IsPassword・Value・SelectionItem 選択・Toggle 状態
            ComCall(3, cr, "int", id)                   ; IUIAutomationCacheRequest::AddProperty
        ComCall(7, cr, "int", 5)                        ; 対象の部品とその子孫すべて
        ComCall(11, cr, "int", 0)                       ; 部品そのものは持たない
        cache := cr
    }
    ComCall(10, uia, "ptr", hwnd, "ptr", cache, "ptr*", &root := 0)   ; ElementFromHandleBuildCache
    if !root
        return
    try
        _PageExport_Walk(root, st, false, Buffer(24), 0)
    finally
        ObjRelease(root)
}

; el とその子孫を読み、st.lines に足す
_PageExport_Walk(el, st, inDoc, v, depth) {
    ct := _PageExport_Int(el, 30003, v)
    name := _PageExport_Str(el, 30005, v)
    if (ct = 50030) {                                   ; Document
        inDoc := true
        st.sawDoc := true
    }
    active := inDoc || !st.docOnly
    inline := (ct = 50020 || ct = 50005)                ; Text・Hyperlink は同じ親の中で 1 つの文にまとめる
    if (active && st.dump)
        st.dump.Push(Format("{}{} {}  {}", _PageExport_Indent(depth), ct, SubStr(name, 1, 60)
            , (ct = 50004 || ct = 50003) ? "= " SubStr(_PageExport_Str(el, 30045, v), 1, 60) : ""))
    if (active && !inline)
        _PageExport_EndRun(st)
    seq := st.seq
    descend := true
    if active {
        switch ct {
            case 50020:                                 ; Text
                _PageExport_Add(st, name)
            case 50005:                                 ; Hyperlink
                _PageExport_Add(st, name)
                descend := false
            case 50004, 50003:                          ; Edit・ComboBox
                if !_PageExport_Int(el, 30019, v)
                    _PageExport_Input(st, name, _PageExport_Str(el, 30045, v))
                descend := false
            case 50002:                                 ; CheckBox
                _PageExport_Mark(st, name, _PageExport_Int(el, 30086, v) = 1, "[x]", "[ ]", true)
                descend := false
            case 50013:                                 ; RadioButton
                _PageExport_Mark(st, name, _PageExport_Int(el, 30079, v) = 1, "(●)", "(○)", false)
                descend := false
            case 50019:                                 ; TabItem：選択中のものだけ見出しにする
                if (_PageExport_Int(el, 30079, v) = 1) {
                    _PageExport_Flush(st)
                    st.lines.Push("## " _PageExport_Clean(name), "")
                }
                descend := false
            case 50000, 50011:                          ; Button・MenuItem：出さない
                descend := false
        }
    }
    if descend {
        ComCall(19, el, "ptr*", &kids := 0)             ; GetCachedChildren
        if kids {
            try {
                ComCall(3, kids, "int*", &n := 0)
                loop n {
                    ComCall(4, kids, "int", A_Index - 1, "ptr*", &kid := 0)
                    try
                        _PageExport_Walk(kid, st, inDoc, v, depth + 1)
                    finally
                        ObjRelease(kid)
                }
            }
            finally
                ObjRelease(kids)
        }
    }
    if (active && !inline) {
        ; 子から文字が取れなかったセル・項目は、名前を文字として使う（Chromium は子の文字を省くことがある）
        if (st.seq = seq && name != "" && (ct = 50029 || ct = 50035 || ct = 50026 || ct = 50007))
            _PageExport_Add(st, name)
        _PageExport_EndRun(st)
    }
}

_PageExport_Indent(depth) {
    s := ""
    loop Min(depth, 30)
        s .= "  "
    return s
}

; 続いている文字を 1 つの文にためる
_PageExport_Add(st, text) {
    if (text = "")
        return
    st.run .= text
    st.seq++
}

; ためた文字を 1 つの文として扱う。「○○:」は項目名で、次の文と組にする。短い文は次の入力欄のラベルの候補にする
_PageExport_EndRun(st) {
    text := _PageExport_Clean(st.run)
    st.run := ""
    if (text = "" || text = st.title || RegExMatch(text, PAGE_EXPORT_IGNORE))
        return
    isPair := RegExMatch(text, "^([^:：/]{1,20})[:：](?!//)\s*(.*)$", &m)     ; 「項目名: 値」が 1 つの文になっているもの
    isLabel := RegExMatch(text, "[:：]$")
    if (st.pending != "" && RegExMatch(st.pending, "[:：]$")) {
        if (!isPair && !isLabel) {
            st.lines.Push("- " _PageExport_Label(st.pending) ": " text)
            st.pending := ""
            return
        }
        st.lines.Push("- " _PageExport_Label(st.pending) ":")
        st.pending := ""
    }
    if isPair {
        if (Trim(m[2]) != "")
            st.lines.Push("- " Trim(m[1]) ": " Trim(m[2]))
        else
            st.pending := Trim(m[1]) ":"
        return
    }
    _PageExport_Flush(st)
    if (StrLen(text) <= PAGE_EXPORT_LABEL_MAX)
        st.pending := text
    else
        st.lines.Push(text, "")
}

_PageExport_Label(s) => Trim(RegExReplace(s, "[:：*＊\s]+$"))

_PageExport_Input(st, name, value) {
    label := (st.pending != "") ? _PageExport_Label(st.pending) : _PageExport_Label(_PageExport_Clean(name))
    st.pending := ""
    value := Trim(StrReplace(StrReplace(value, "`r`n", "`n"), "`r", "`n"), " `t`n")
    if (value = "" && (label = "" || label = "Submit"))
        return
    single := !InStr(value, "`n") && StrLen(value) <= 80
    if (label = "" && single && st.lastIdx && st.seq = st.lastSeq) {
        st.lines[st.lastIdx] .= " / " value                 ; 直前の入力欄の続き（ID と名前の組など）
        st.lastSeq := ++st.seq
        return
    }
    st.seq++
    if (label = "")
        label := "（項目名なし）"
    if (value = "")
        st.lines.Push("- **" label "**: （未入力）")
    else if !single
        st.lines.Push("", "### " label, "", value, "")
    else {
        st.lines.Push("- **" label "**: " value)
        st.lastIdx := st.lines.Length
        st.lastSeq := st.seq
    }
}

; チェック・ラジオ。チェックは名前がなければ直前の文字をラベルにする
_PageExport_Mark(st, name, on, yes, no, usePending) {
    label := _PageExport_Clean(name)
    if (label = "" && usePending)
        label := _PageExport_Label(st.pending), st.pending := ""
    else
        _PageExport_Flush(st)
    if (label != "" && !RegExMatch(label, "^(No|\d+)$")) {   ; 表の行番号のチェックは出さない
        st.seq++
        st.lines.Push("- " (on ? yes : no) " " label)
    }
}

; ラベルの候補として持っていた文字を、そのままの文章として出す
_PageExport_Flush(st) {
    if (st.pending = "")
        return
    if RegExMatch(st.pending, "[:：]$")
        st.lines.Push("- " _PageExport_Label(st.pending) ":")
    else
        st.lines.Push(st.pending, "")
    st.pending := ""
}

_PageExport_Clean(s) => Trim(RegExReplace(s, "\s+", " "))

_PageExport_Str(el, id, v) {
    ComCall(12, el, "int", id, "ptr", v)
    s := ""
    if (NumGet(v, 0, "ushort") = 8 && (p := NumGet(v, 8, "ptr")))
        s := StrGet(p, "UTF-16")
    DllCall("oleaut32\VariantClear", "ptr", v)
    return s
}

_PageExport_Int(el, id, v) {
    ComCall(12, el, "int", id, "ptr", v)
    vt := NumGet(v, 0, "ushort"), n := 0
    if (vt = 3)
        n := NumGet(v, 8, "int")
    else if (vt = 11)
        n := NumGet(v, 8, "short") != 0
    DllCall("oleaut32\VariantClear", "ptr", v)
    return n
}
