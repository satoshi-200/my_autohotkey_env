#Requires AutoHotkey v2.0
;==============================================================================
; text_ops.ahk
; 選択中の文字の取得・貼り付け、文字の変換、入力先の IME の状態、選択文字での検索
;   クイックメニューの「T テキスト変換」「N 日付・時刻」「G 検索・翻訳」と、記号メニューから使う
;   quick_menu.ahk から分けた。関数名の QM_ はそのまま
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk

;--- IME ----------------------------------------------------------------------

; IME ウィンドウへ問い合わせる（相手が応答しなくても 200ms で打ち切る）
QM_ImeQuery(hIme, cmd) {
    r := 0
    ok := DllCall("SendMessageTimeout", "Ptr", hIme, "UInt", 0x0283, "Ptr", cmd, "Ptr", 0
        , "UInt", 0x2, "UInt", 200, "UPtr*", &r, "Ptr")          ; WM_IME_CONTROL, SMTO_ABORTIFHUNG
    return ok ? r : 0
}

; 入力先の IME が「全角で入力する状態」か
;   IME オン かつ 変換モードに NATIVE（かな）または FULLSHAPE（全角）が含まれる → true
;   IME オフ、半角英数                                                          → false
QM_TargetImeIsFullWidth(hwnd) {
    if !hwnd
        return false
    ; フォーカスのある部品（エディタ本体など）を探す
    focus := hwnd
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    size := (A_PtrSize = 8) ? 72 : 48
    gti := Buffer(size, 0), NumPut("UInt", size, gti)
    if DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", gti)
        if (f := NumGet(gti, (A_PtrSize = 8) ? 16 : 12, "Ptr"))  ; hwndFocus
            focus := f
    hIme := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", focus, "Ptr")
    if !hIme
        return false
    if !QM_ImeQuery(hIme, 0x0005)                               ; IMC_GETOPENSTATUS
        return false
    mode := QM_ImeQuery(hIme, 0x0001)                           ; IMC_GETCONVERSIONMODE
    return (mode & 0x9) != 0                                     ; IME_CMODE_NATIVE | IME_CMODE_FULLSHAPE
}

; 半角の英数字・記号を全角に（! → ！、スペース → 全角スペース）
QM_ToFullAscii(s) {
    out := ""
    loop parse s {
        c := Ord(A_LoopField)
        out .= (c >= 0x21 && c <= 0x7E) ? Chr(c + 0xFEE0) : (c = 0x20 ? "　" : A_LoopField)
    }
    return out
}

; 選択中の文字を取得する（クリップボードは元に戻す）
QM_CopySelection(&text) {
    saved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    ok := ClipWait(0.5)
    text := ok ? A_Clipboard : ""
    A_Clipboard := saved
    return (ok && text != "")
}

; 文字を貼り付ける（クリップボードは元に戻す。waitMs は貼り付けが終わるのを待つ時間）
QM_Paste(text, waitMs := 300) {
    saved := ClipboardAll()
    A_Clipboard := text
    Send("^v")
    Sleep(waitMs)
    A_Clipboard := saved
}

; 選択中の文字を fn で変換して置き換える
QM_TransformSelection(fn) {
    if !QM_CopySelection(&text) {
        UI_Tip("文字が選択されていません")
        return
    }
    out := fn(text)
    if (out == text) {
        UI_Tip("変更はありませんでした")
        return
    }
    QM_Paste(out)
}

QM_InsertTime(fmt) => QM_Paste(FormatTime(, fmt))

QM_PastePlain() {
    if (A_Clipboard = "") {
        UI_Tip("クリップボードに文字がありません")
        return
    }
    A_Clipboard := A_Clipboard                                   ; 書式を取り除く
    Send("^v")
}

; IME をオフにする
QM_ImeOff(hwnd) {
    hIme := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if hIme
        DllCall("SendMessage", "Ptr", hIme, "UInt", 0x0283, "Ptr", 0x0006, "Ptr", 0)  ; IMC_SETOPENSTATUS = 0
}

;--- 文字変換 -----------------------------------------------------------------

; LCMapStringEx による変換（ひらがな・カタカナ・全角・半角）
QM_LCMap(s, flags) {
    n := DllCall("LCMapStringEx", "Str", "ja-JP", "UInt", flags, "Str", s, "Int", StrLen(s)
        , "Ptr", 0, "Int", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int")
    if (n <= 0)
        return s
    buf := Buffer(n * 2)
    DllCall("LCMapStringEx", "Str", "ja-JP", "UInt", flags, "Str", s, "Int", StrLen(s)
        , "Ptr", buf, "Int", n, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int")
    return StrGet(buf, n, "UTF-16")
}
QM_ToKatakana(s) => QM_LCMap(s, 0x00200000)                     ; LCMAP_KATAKANA
QM_ToHiragana(s) => QM_LCMap(s, 0x00100000)                     ; LCMAP_HIRAGANA

; 全角の英数字・記号・スペースだけを半角にする（かな・漢字はそのまま）
QM_ToHalfAlnum(s) {
    out := ""
    loop parse s {
        c := Ord(A_LoopField)
        out .= (c >= 0xFF01 && c <= 0xFF5E) ? Chr(c - 0xFEE0) : (c = 0x3000 ? " " : A_LoopField)
    }
    return out
}

; 半角カナだけを全角カナにする（濁点・半濁点も 1 文字にまとめる）
QM_HalfKanaToFull(s) {
    out := "", pos := 1
    while RegExMatch(s, "[\x{FF61}-\x{FF9F}]+", &m, pos) {
        out .= SubStr(s, pos, m.Pos - pos) . QM_LCMap(m[0], 0x00800000)   ; LCMAP_FULLWIDTH
        pos := m.Pos + m.Len
    }
    return out . SubStr(s, pos)
}

; 改行を削除して 1 行に（英単語どうしの間には半角スペースを入れる）
QM_JoinLinesText(s) {
    s := RegExReplace(s, "(?<=[!-~])[ \t]*\R+[ \t]*(?=[!-~])", " ")
    return RegExReplace(s, "[ \t]*\R+[ \t]*")
}

QM_JoinArray(arr) {
    out := ""
    for i, v in arr
        out .= (i > 1 ? "`r`n" : "") v
    return out
}

QM_TrimLines(s) {
    arr := []
    loop parse s, "`n", "`r" {
        t := Trim(A_LoopField, " `t　")
        if (t != "")
            arr.Push(t)
    }
    return QM_JoinArray(arr)
}

QM_Bullets(s) {
    arr := []
    loop parse s, "`n", "`r" {
        t := A_LoopField
        if (Trim(t, " `t　") != "" && SubStr(LTrim(t, " `t　"), 1, 1) != "・")
            t := "・" t
        arr.Push(t)
    }
    return QM_JoinArray(arr)
}

QM_SortLines(s) {
    s := RTrim(StrReplace(s, "`r`n", "`n"), "`n")
    return StrReplace(Sort(s), "`n", "`r`n")
}

QM_DedupLines(s) {
    seen := Map(), arr := []
    loop parse s, "`n", "`r" {
        if !seen.Has(A_LoopField) {
            seen[A_LoopField] := true
            arr.Push(A_LoopField)
        }
    }
    return QM_JoinArray(arr)
}

QM_Unquote(s)          => StrReplace(Trim(s), '"')
QM_BackslashToSlash(s) => StrReplace(s, "\", "/")

QM_CountSelection() {
    if !QM_CopySelection(&t) {
        UI_Tip("文字が選択されていません")
        return
    }
    t := RTrim(StrReplace(t, "`r`n", "`n"), "`n")
    lines   := StrSplit(t, "`n").Length
    all     := StrLen(StrReplace(t, "`n"))
    noSpace := StrLen(RegExReplace(t, "[\s　]"))
    UI_Tip(Format("文字数　　：{}`n空白を除く：{}`n行数　　　：{}", all, noSpace, lines), 4000)
}

;--- 検索・翻訳 ---------------------------------------------------------------
QM_UriEncode(s) {
    buf := Buffer(StrPut(s, "UTF-8"))
    StrPut(s, buf, "UTF-8")
    out := ""
    loop buf.Size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        out .= ((b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A)
            || b = 0x2D || b = 0x2E || b = 0x5F || b = 0x7E) ? Chr(b) : Format("%{:02X}", b)
    }
    return out
}

QM_WebSelection(baseUrl) {
    if !QM_CopySelection(&t) {
        UI_Tip("文字が選択されていません")
        return
    }
    Run(baseUrl . QM_UriEncode(Trim(t)))
}
