#Requires AutoHotkey v2.0
;==============================================================================
; key_wait.ahk
; 入力待ち（起点キーのあと次のキーを 1 つ受け取る）の共通部品
;   ih               入力待ちで共有する InputHook
;   isWaitingInput   待機中フラグ（待機中は各レイヤーのホットキーを止める）
;   IH_WaitNext()    次のキーを 1 つ待ち、キャンセル・タイムアウトを判定する
;   IH_ModeBegin() / IH_ModeEnd()  独自の InputHook を使うモードの開始・終了処理
;==============================================================================
#Include %A_LineFile%\..\config.ahk

ih := InputHook("L1")
isWaitingInput := false
IH_TIMEOUT_SEC := 5                       ; この秒数キー入力がなければ入力待ちをキャンセル
IH_forcedKey := ""                        ; InputHook に届かないキー（「A & B」の A）をホットキーから渡す

; Esc・Caps で終了、一定時間でタイムアウト（各モードの KeyOpt でも消えない）
ih.Timeout := IH_TIMEOUT_SEC
ih.KeyOpt("{Esc}{sc03A}", "ES")

; 次のキーを 1 つ待つ。endKeys は文字の代わりに受け付ける特殊キー。キャンセル・タイムアウトなら false
IH_WaitNext(mode, hint := "", endKeys := "") {
    IH_TipWaiting(mode, hint)
    if (endKeys != "")
        ih.KeyOpt(endKeys, "ES")
    ih.Start()
    ih.Wait()
    return !IH_EndWait(mode)
}

; いま何のキー待ちかをツールチップで表示する
IH_TipWaiting(mode, hint := "") {
    global isWaitingInput := true
    global IH_forcedKey := ""
    SetTimer(IH_TipClear, 0)              ; 前のモードの「消去タイマー」で待ち表示が消えないように
    ToolTip("⌨️ [" mode "] 次のキー待ち..." (hint != "" ? "`n" hint : "")
        "`nEsc / Caps / Space+Caps：キャンセル（" IH_TIMEOUT_SEC " 秒で自動キャンセル）")
}

; 入力待ちを終えた特殊キー（ホットキーから渡されたキーも含む）。文字入力なら ""
IH_EndKeyOf() => (ih.EndReason = "Stopped" && IH_forcedKey != "") ? IH_forcedKey : ih.EndKey

; ih を「特殊キー key で終わった」ことにして止める
IH_StopWithKey(key) {
    global IH_forcedKey := key
    ih.Stop()
}

; 入力待ちの終了処理。受け付けたキーを表示し、キャンセルされたら true を返す
IH_EndWait(mode) {
    global isWaitingInput
    endKey := IH_EndKeyOf()
    cancelled := ""
    if (ih.EndReason = "Timeout")
        cancelled := "タイムアウト"
    else if (endKey = "Escape" || endKey = "CapsLock")
        cancelled := "キャンセル"
    else if (endKey = "Space" && IH_CapsWhileSpaceHeld())
        cancelled := "キャンセル"
    isWaitingInput := false

    if (cancelled != "")
        ToolTip("❌ [" mode "] " cancelled)
    else
        ToolTip("✅ [" mode "] accepted:[" ((endKey != "") ? endKey : ih.Input) "]")
    SetTimer(IH_TipClear, -TOOLTIP_DURATION_MS)
    return cancelled != ""
}

; Space で入力待ちが終わったとき、Space を離すまでに Caps が押されたか（Space+Caps でのキャンセル）
IH_CapsWhileSpaceHeld() {
    h := InputHook("L0 T" IH_TIMEOUT_SEC)
    h.KeyOpt("{sc03A}", "ES")
    h.KeyOpt("{vk20}", "NS")              ; 押しっぱなしの Space の連打を止め、離したら終える
    h.OnKeyUp := (hk, vk, sc) => (vk = 0x20 ? hk.Stop() : 0)
    h.Start()
    if !GetKeyState("vk20", "P") {
        h.Stop()
        return false
    }
    h.Wait()
    return h.EndReason = "EndKey"
}

; 独自の InputHook を使うモードの開始（ほかのレイヤーを止め、呼び出し元の消去タイマーを止める）
IH_ModeBegin() {
    global isWaitingInput := true
    SetTimer(IH_TipClear, 0)
}

; 独自の InputHook を使うモードの終了（結果を短く表示する）
IH_ModeEnd(message) {
    global isWaitingInput := false
    ToolTip(message)
    SetTimer(IH_TipClear, -TOOLTIP_DURATION_MS)
}

IH_TipClear() => ToolTip()
