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

;------------------------------------------------------------------------------
; 大文字化
;------------------------------------------------------------------------------
; 次に入力する 1 文字を大文字にする
Text_CapitalizeNext() {
    h := InputHook("L1 M")
    h.Start()
    h.Wait()
    SendInput(Chr(Ord(h.Input) - 32))
}

;------------------------------------------------------------------------------
; 大文字入力モード（Caps → 無変換 から呼ぶ）
;   英字キーを Shift 付きで送る（Shift を押しながら打つのと同じで、IME の未確定文字になる）。
;   数字・記号はそのまま入力してモードを続ける。
;   Esc / Caps / 無変換 / 変換：終了のみ　Space・Enter・BS などほかのキー：終了してそのキーを入力
;   無変換 / 変換 / Space は leader_keys.ahk のホットキーから UpperMode_Stop() を呼ぶ
;------------------------------------------------------------------------------
UpperMode_hook := 0

UpperMode_IsOn() => UpperMode_hook && UpperMode_hook.InProgress
UpperMode_Stop() => UpperMode_IsOn() && UpperMode_hook.Stop()

UpperMode_Start() {
    global UpperMode_hook
    IH_ModeBegin()

    h := InputHook("L0 V")                          ; 指定しないキーはそのまま入力させる
    h.MinSendLevel := 1                             ; 自分で送った Shift+英字を拾って無限ループしないように
    h.KeyOpt("{All}", "E")                          ; ほかのキーは押したら終了（キーはそのまま届く）
    ; {All} は VK と SC の両方に付くので、外すときも両方から外す
    opt(vk, o) => h.KeyOpt(Format("{{}vk{:X}{}}{{}sc{:X}{}}", vk, GetKeySC(Format("vk{:X}", vk))), o)
    for vk in [0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C]  ; Shift / Ctrl / Alt / Win
        opt(vk, "-E")
    loop 10                                         ; 数字
        opt(0x2F + A_Index, "-E")
    for vk in [0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE, 0xE2]  ; 記号
        opt(vk, "-E")
    loop 26                                         ; 英字：止めて OnKeyDown で Shift+英字を送る
        opt(0x40 + A_Index, "-E +S +N")
    h.KeyOpt("{Esc}{sc03A}", "+E +S")               ; 終了のみ（キーは送らない）
    h.OnKeyDown := _UpperMode_OnKey

    UpperMode_hook := h
    ToolTip("🔠 [大文字モード] 英字を大文字で入力"
        . "`nEsc / Caps / 無変換 / 変換：終了　Space・Enter など：終了してそのキーを入力")
    h.Start()
    h.Wait()
    IH_ModeEnd("🔡 [大文字モード] 終了")
}

_UpperMode_OnKey(h, vk, sc) {
    if (GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("LWin") || GetKeyState("RWin")) {
        h.Stop()                                    ; Ctrl+C などは終了して通常のショートカットとして送る
        SendInput("{Blind}{vk" Format("{:X}", vk) "}")
        return
    }
    SendInput("+{vk" Format("{:X}", vk) "}")
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
