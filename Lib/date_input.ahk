#Requires AutoHotkey v2.0
;==============================================================================
; date_input.ahk
; 日付入力：日付を調整 → フォーマットを選ぶ → 入力する（2 段階。確定までは何も入力しない）
;   DateInput_Start()  呼ぶと現在の日付を表示する。クイックメニュー N → N から呼ぶ。
;
;   1. 日付の調整（初期値は今日）
;        K：1 日戻る　L：1 日進む　J：10 日戻る　;：10 日進む　H / N：日付を確定
;   2. フォーマットの選択（初期値は先頭の yyyy/MM/dd）
;        L：次　K：前　J：先頭　;：最後　H / N：確定して入力
;   Esc / Caps / Space+Caps：キャンセル（DATEINPUT_TIMEOUT_MS 操作がなければ自動でキャンセル）
;==============================================================================
#Include %A_LineFile%\..\text_input.ahk

DATEINPUT_TIMEOUT_MS := 60000                  ; 操作がないときにキャンセルするまでの時間
DATEINPUT_DAY_STEP   := 10                     ; J / ; で動かす日数

; 選べるフォーマット（FormatTime の書式）。先頭が初期値
DATEINPUT_FORMATS := [
    "yyyy/MM/dd", "yyyy-MM-dd", "yyyy.MM.dd", "yyyyMMdd", "yy/MM/dd", "yyMMdd", "yyMMdd_",
    "yyyy/MM/dd(ddd)", "M/d", "MM/dd", "yyyy年M月d日", "yyyy年MM月dd日"]

DateInput_Start() {
    if isWaitingInput
        return
    IH_ModeBegin()

    st := {date: A_Now, stage: 1, idx: 1, result: ""}
    h := InputHook("L0 T" DATEINPUT_TIMEOUT_MS // 1000)
    h.KeyOpt("{All}", "+N +S")                      ; すべてのキーを受け取り、アプリには送らない
    ; {All} は VK と SC の両方に付くので、外すときも両方から外す
    for vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]  ; Shift / Ctrl / Alt / Win
        h.KeyOpt(Format("{{}vk{:X}{}}{{}sc{:X}{}}", vk, GetKeySC(Format("vk{:X}", vk))), "-N -S")
    h.OnKeyDown := (hk, vk, sc) => _DateInput_OnKey(hk, vk, sc, st)

    _DateInput_Show(st)
    h.Start()
    h.Wait()

    if (st.result != "") {
        IH_ModeEnd("✅ [日付入力] " st.result)
        Text_SendHalfWidth(st.result)
    } else
        IH_ModeEnd("❌ [日付入力] " (h.EndReason = "Timeout" ? "タイムアウト" : "キャンセル"))
}

_DateInput_OnKey(h, vk, sc, st) {
    if (vk = 0x1B || vk = 0x14 || sc = 0x03A) {     ; Esc / CapsLock（JIS では英数キー。Space+Caps もこの Caps で止まる）
        h.Stop()
        return
    }
    if (GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin"))
        return
    key := _DateInput_KeyName(vk)
    if (key = "")
        return

    if (key = "h" || key = "n") {
        if (st.stage = 1) {
            st.stage := 2
        } else {
            st.result := FormatTime(st.date, DATEINPUT_FORMATS[st.idx])
            h.Stop()
            return
        }
    } else if (st.stage = 1) {
        switch key {
            case "k": st.date := DateAdd(st.date, -1, "Days")
            case "l": st.date := DateAdd(st.date, 1, "Days")
            case "j": st.date := DateAdd(st.date, -DATEINPUT_DAY_STEP, "Days")
            case ";": st.date := DateAdd(st.date, DATEINPUT_DAY_STEP, "Days")
        }
    } else {
        last := DATEINPUT_FORMATS.Length
        switch key {
            case "l": st.idx := Min(st.idx + 1, last)
            case "k": st.idx := Max(st.idx - 1, 1)
            case "j": st.idx := 1
            case ";": st.idx := last
        }
    }
    _DateInput_Show(st)
}

; 英字（小文字）と ; を返す。それ以外は ""（JIS の ; は 0xBB、US は 0xBA）
_DateInput_KeyName(vk) {
    if (vk >= 0x41 && vk <= 0x5A)
        return StrLower(Chr(vk))
    if ((vk = 0xBA || vk = 0xBB) && DllCall("MapVirtualKey", "UInt", vk, "UInt", 2, "UInt") = Ord(";"))
        return ";"
    return ""
}

_DateInput_Show(st) {
    if (st.stage = 1) {
        text := "📅 [日付入力] 日付を選ぶ`n"
            . FormatTime(st.date, "yyyy/MM/dd(ddd)") "`n"
            . "K：1 日戻る　L：1 日進む　J：" DATEINPUT_DAY_STEP " 日戻る　;：" DATEINPUT_DAY_STEP " 日進む`n"
            . "H / N：日付を確定　Esc / Caps：キャンセル"
    } else {
        text := "📅 [日付入力] フォーマットを選ぶ"
        for fmt in DATEINPUT_FORMATS
            text .= "`n" (A_Index = st.idx ? "▶ " : "　 ") FormatTime(st.date, fmt)
        text .= "`nL：次　K：前　J：先頭　;：最後`nH / N：確定して入力　Esc / Caps：キャンセル"
    }
    ToolTip(text)
}
