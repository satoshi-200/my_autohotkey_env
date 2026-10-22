#Requires AutoHotkey v2.0
;==============================================================================
; date_input.ahk
; 日付・時刻の入力：フォーマットを選んで入力する。確定までは何も入力しない。ツールチップと InputHook で動かし、小窓を出さない（ファイル名の変更中にも使える）。
;   DateInput_Start()   Space+F → i。日付を調整してから、フォーマットを選ぶ（2 段階）
;   QM_DateQuick_Show() Space+F → u。今の日時で、フォーマットの選択から始める（1 段階）。BS で日付の調整へ進める
;   どちらも同じ一覧（DATEINPUT_FORMATS）から選ぶ。
;
;   1. 日付の調整（初期値は今日）
;        K / ←：1 日戻る　L / →：1 日進む　J / ↑：10 日戻る　; / ↓：10 日進む　G / H / V / B / N / Enter：日付を確定
;   2. フォーマットの選択（初期値は先頭）
;        一覧の [ ] のキー：その形式で入力
;        ↑ / ↓：前 / 次　← / →：先頭 / 最後　G / H / V / B / N / Enter：▶ の形式で入力　BS：日付の調整へ
;   矢印は Space + j / k / l / ; でも打てる（Space+j = ←、k = ↑、l = ↓、; = →）。
;   Esc / Caps / Space+Caps：キャンセル（DATEINPUT_TIMEOUT_MS 操作がなければ自動でキャンセル）
;==============================================================================
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\key_mode.ahk
#Include %A_LineFile%\..\text_input.ahk

DATEINPUT_TIMEOUT_MS := 60000                  ; 操作がないときにキャンセルするまでの時間
DATEINPUT_DAY_STEP   := 10                     ; J / ; で動かす日数

; 選べるフォーマット（FormatTime の書式）。先頭が初期値。キーは DATEINPUT_FORMAT_KEYS の同じ順
DATEINPUT_FORMATS := [
    "yyyy/MM/dd", "yyyy-MM-dd", "yyyy.MM.dd", "yyyyMMdd", "yy/MM/dd", "yyMMdd", "yyMMdd_",
    "yyyy/MM/dd(ddd)", "M/d", "MM/dd", "yyyy年M月d日", "yyyy年MM月dd日",
    "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm", "HH:mm", "HH:mm:ss", "HHmm", "HHmmss", "yyyyMMdd_HHmmss", "yyyyMMdd_HHmm"]
; 各フォーマットを直接選ぶキー（g / h / v / b / n は確定用）
DATEINPUT_FORMAT_KEYS := ["a", "s", "d", "f", "j", "k", "l", ";", "q", "w", "e", "r", "u", "i", "o", "p", "z", "x", "c", "m"]

DateInput_Start() => _DateInput_Run(1)

QM_DateQuick_Show() => _DateInput_Run(2)

_DateInput_Run(stage) {
    if IH_waiting
        return
    ; live：日付を調整していない間は、入力する時点の日時を使う
    st := {date: A_Now, stage: stage, idx: 1, text: "", live: stage = 2}
    ; layers 既定：Space+j/k/l/; を矢印、Space+g/h を Enter として受ける
    IHM_Run(st, {message: _DateInput_Message, onKey: _DateInput_OnKey, onStart: _DateInput_Show
        , idleSec: DATEINPUT_TIMEOUT_MS // 1000, tip: "cursor"})
    if (st.result = "pick")
        Text_SendHalfWidth(st.text)
}

_DateInput_Message(st) {
    switch st.result {
        case "pick":    return st.live ? "" : "✅ [日付入力] " st.text   ; 日時を選んだだけのときは、入力した文字だけが残るようにする
        case "timeout": return "❌ [日付入力] タイムアウト"
        case "error":   return "⚠️ [日付入力] 失敗：" st.err
        default:        return "❌ [日付入力] キャンセル"
    }
}

_DateInput_Pick(st, idx) {
    if st.live
        st.date := A_Now
    st.text := FormatTime(st.date, DATEINPUT_FORMATS[idx])
    IHM_Finish(st, "pick")
}

_DateInput_OnKey(st, k) {
    key := k.name
    if (k.sc = 0x01 || k.sc = 0x3A) {               ; Esc / Caps（Space+Caps もこの Caps）
        IHM_Finish(st, "cancel")
        return
    }
    if (key = "g" || key = "h" || key = "v" || key = "b" || key = "n" || key = "enter") {
        if (st.stage = 1) {
            st.stage := 2
        } else {
            _DateInput_Pick(st, st.idx)
            return
        }
    } else if (st.stage = 1) {
        switch key {
            case "k", "left":  st.date := DateAdd(st.date, -1, "Days")
            case "l", "right": st.date := DateAdd(st.date, 1, "Days")
            case "j", "up":    st.date := DateAdd(st.date, -DATEINPUT_DAY_STEP, "Days")
            case ";", "down":  st.date := DateAdd(st.date, DATEINPUT_DAY_STEP, "Days")
        }
    } else {
        last := DATEINPUT_FORMATS.Length
        for i, fk in DATEINPUT_FORMAT_KEYS {
            if (key = fk && i <= last) {
                _DateInput_Pick(st, i)
                return
            }
        }
        switch key {
            case "down":  st.idx := Min(st.idx + 1, last)
            case "up":    st.idx := Max(st.idx - 1, 1)
            case "left":  st.idx := 1
            case "right": st.idx := last
            case "backspace": st.stage := 1, st.live := false
        }
    }
    _DateInput_Show(st)
}

_DateInput_Show(st) {
    if st.live
        st.date := A_Now
    if (st.stage = 1) {
        text := "📅 [日付入力] 日付を選ぶ`n"
            . FormatTime(st.date, "yyyy/MM/dd(ddd)") "`n"
            . "K / ←：1 日戻る　L / →：1 日進む　J / ↑：" DATEINPUT_DAY_STEP " 日戻る　; / ↓：" DATEINPUT_DAY_STEP " 日進む`n"
            . "G / H / V / B / N / Enter：日付を確定　Esc / Caps：キャンセル"
    } else {
        text := "📅 [日付・時刻] フォーマットを選ぶ"
        for fmt in DATEINPUT_FORMATS
            text .= "`n" (A_Index = st.idx ? "▶ " : "　 ") "[" StrUpper(DATEINPUT_FORMAT_KEYS[A_Index]) "] " FormatTime(st.date, fmt)
        text .= "`nキー：その形式で入力　↑ ↓：選ぶ　← →：先頭 / 最後　BS：日付を変える`nG / H / V / B / N / Enter：▶ で入力　Esc / Caps：キャンセル"
    }
    IHM_Tip(st, text)
}
