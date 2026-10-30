#Requires AutoHotkey v2.0
;==============================================================================
; outlook_mail.ahk
; Outlook のメール選択モード（keymap\leader_keys.ahk の Leader_Kana から呼ぶ。かなキー）
;   OutlookMail_SelectMode()  … カーソルだけを動かして複数のメールを選び、e（extract）で内容をクリップボードへコピーする
;       矢印（Space+j k l `; も）  カーソルだけ移動（選択は変わらない。Outlook の Ctrl+↑↓）
;       Shift+矢印                連続した範囲を選ぶ（Shift+↑↓）
;       s … カーソルのメールを選択・解除（Ctrl+Space）   r … 選択をすべて解除（ClearSelection）
;       e … 選択中のメールの文面を丸ごとクリップボードへ入れて終わる
;       Esc / Caps / かな … 終わる
;   コピーするのは、件名・日時・差出人・宛先・Cc・添付名・本文（引用も含めた全文）。
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\key_mode.ahk

OLM_MODE_IDLE_SEC := 30                             ; 選択モードで、この秒数キー入力がなければ終わる

OutlookMail_SelectMode() {
    st := {}
    IHM_Run(st, {message: _OlmMode_Message, onKey: _OlmMode_OnKey, onStart: _OlmMode_Tip
        , idleSec: OLM_MODE_IDLE_SEC, tip: "corner"})
    if (st.result = "copy")
        OutlookMail_CopyText()
}

_OlmMode_Message(st) {
    switch st.result {
        case "copy":    return "✅ [Outlook 選択] コピーします"
        case "timeout": return "❌ [Outlook 選択] タイムアウト"
        case "error":   return "⚠️ [Outlook 選択] 失敗：" st.err
        default:        return "✅ [Outlook 選択] 終了"
    }
}

_OlmMode_Tip(st) {
    n := ""
    ex := _OutlookMail_Explorer()
    if IsObject(ex) {
        try n := "：" ex.Selection.Count " 通選択中"
    }
    IHM_Tip(st, "📧 Outlook 選択モード" n
        , "矢印（Space+j k l `;）：カーソル移動`nShift+矢印：範囲`ns：選択・解除　r：全解除`ne：コピーして終了　Esc：終了")
}

_OlmMode_OnKey(st, k) {
    if k.left
        return
    if (k.sc = 0x01 || k.sc = 0x3A || k.sc = 0x70) {        ; Esc / Caps / カタカナひらがな
        IHM_Finish(st, "end")
        return
    }
    shift := st.held.Has(0x2A) || st.held.Has(0x36)
    switch k.name {
        case "up", "down":
            SendInput((shift ? "+" : "^") "{" k.name "}")
        case "s":
            SendInput("^{Space}")
        case "r":
            try _OutlookMail_Explorer().ClearSelection()
        case "e":
            IHM_Finish(st, "copy")
            return
        default:
            return
    }
    Sleep(60)
    _OlmMode_Tip(st)
}

_OutlookMail_Explorer() {
    try {
        return ComObjActive("Outlook.Application").ActiveExplorer()
    }
    return ""
}

; 選択中のメールの文面を、クリップボードへ入れる
OutlookMail_CopyText() {
    ex := _OutlookMail_Explorer()
    if !IsObject(ex) {
        UI_Tip("Outlook に接続できません")
        return
    }
    text := "", n := 0
    try {
        sel := ex.Selection
        loop sel.Count {
            item := sel.Item(A_Index)
            if (item.Class != 43)
                continue
            text .= _OutlookMail_Format(item) "`n`n"
            n++
        }
    } catch as e {
        UI_Tip("メールを読み取れませんでした：" e.Message, 3000)
        return
    }
    if (n = 0) {
        UI_Tip("メールが選択されていません")
        return
    }
    A_Clipboard := RTrim(text, "`n")
    UI_Tip(n " 通をコピーしました", 2000)
}

_OutlookMail_Format(item) {
    folder := ""
    try folder := item.Parent.Name
    kind := RegExMatch(folder, "i)Sent|送信") ? "送信" : "受信"
    att := ""
    try {
        loop item.Attachments.Count
            att .= (att = "" ? "" : ", ") item.Attachments.Item(A_Index).FileName
    }
    return "--- メール ---`n件名: " item.Subject "`n日時: " _OutlookMail_Date(item) "`n種別: " kind
        . "`n差出人: " item.SenderName "`n宛先: " item.To "`nCc: " item.CC "`n添付: " att
        . "`n本文:`n" item.Body
}

; 送信日時（なければ受信日時）を yyyy-MM-dd HH:mm で返す
_OutlookMail_Date(item) {
    s := ""
    try s := String(item.SentOn)
    if !RegExMatch(s, "(\d{4})\D(\d{1,2})\D(\d{1,2})\D+(\d{1,2}):(\d{2})", &m) || Integer(m[1]) < 1990 {
        try s := String(item.ReceivedTime)
        if !RegExMatch(s, "(\d{4})\D(\d{1,2})\D(\d{1,2})\D+(\d{1,2}):(\d{2})", &m)
            return s
    }
    return Format("{:04}-{:02}-{:02} {:02}:{}", Integer(m[1]), Integer(m[2]), Integer(m[3]), Integer(m[4]), m[5])
}
