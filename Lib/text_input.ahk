#Requires AutoHotkey v2.0
;==============================================================================
; text_input.ahk
; 文字入力の補助（IME の切り替え・大文字化・箇条書き・日付の入力・ホイールでのテキストカーソル移動）
;   IME_GET / IME_SET は IME.ahk で定義
;==============================================================================
#Include %A_LineFile%\..\IME.ahk
#Include %A_LineFile%\..\key_wait.ahk

;------------------------------------------------------------------------------
; IME の切り替え
;   VK_IME_ON / VK_IME_OFF：現在の状態に関係なく ON / OFF にする（Microsoft IME など対応 IME のみ）
;------------------------------------------------------------------------------
Ime_Hiragana() => SendInput("{vk16}")
Ime_Alnum()    => SendInput("{vk1A}")

; 未確定の文字があると VK_IME_OFF は無視される（確定もされない）ので、先に IME_SET で確定してオフにする
Ime_AlnumCommit() {
    try IME_SET(0)
    SendInput("{vk1A}")
}

;------------------------------------------------------------------------------
; 大文字化
;------------------------------------------------------------------------------
; 次に入力する 1 文字を大文字にする
; 待ちを別スレッドで行う。呼び出し元（Caps のホットキー）のスレッドを塞ぐと、待っている間は Caps → 変換 / Space などが効かない
Text_CapitalizeNext() => SetTimer(_Text_CapitalizeNext, -1)

_Text_CapitalizeNext() {
    h := InputHook("L1 M")
    h.KeyOpt("{Esc}", "ES")                         ; Esc で取り消し
    h.Start()
    h.Wait()
    if (h.EndReason = "Max")
        SendInput(Chr(Ord(h.Input) - 32))
}

;------------------------------------------------------------------------------
; IME を一時的に半角にして入力する（入力後は元の IME の状態に戻す）
;------------------------------------------------------------------------------
; 箇条書きの記号「- 」を入力する
Text_BulletPoint() {
    imeOn := IME_GET() != 0
    IME_SET(0)
    SendInput("{-}")
    SendInput("{Space}")
    Sleep(50)                                       ; - の後のスペースが全角になるのを防ぐ
    IME_SET(imeOn ? 1 : 0)
}

Text_SendHalfWidth(text) {
    imeOn := IME_GET() != 0
    IME_SET(0)
    SendInput(text)
    Sleep(100)                                      ; 入力が終わる前に IME が戻るのを防ぐ
    IME_SET(imeOn ? 1 : 0)
}

; 現在の日時を format（FormatTime の書式）で入力する
Text_InsertDate(format) => Text_SendHalfWidth(FormatTime(, format))

;------------------------------------------------------------------------------
; マウスホイールでテキストカーソルを動かす（dir：Up / Down / Left / Right）
;------------------------------------------------------------------------------
TEXT_WHEEL_SLEEP_MS := 20

Text_WheelCursor(dir) {
    Sleep(TEXT_WHEEL_SLEEP_MS)
    SendInput("{Blind}{" dir "}")
    Sleep(TEXT_WHEEL_SLEEP_MS)
}
