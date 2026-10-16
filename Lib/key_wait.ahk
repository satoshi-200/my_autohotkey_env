#Requires AutoHotkey v2.0
;==============================================================================
; key_wait.ahk
; 入力待ち（起点キーのあと次のキーを 1 つ受け取る）の共通部品
;   IH_hook          入力待ちで共有する InputHook
;   IH_waiting       待機中フラグ（待機中は各レイヤーのホットキーを止める）
;   IH_WaitNext()    次のキーを 1 つ待ち、キャンセル・タイムアウトを判定する
;   IH_ModeBegin() / IH_ModeEnd()  独自の InputHook を使うモードの開始・終了処理
;   IH_HotkeyTrigger() / IH_ChoiceHook() / IH_IsCancelKey()  そのモードで使う部品（ファイルの末尾）
;==============================================================================
#Include %A_LineFile%\..\config.ahk

IH_hook := InputHook("L1")
IH_waiting := false
IH_TIMEOUT_SEC := 10                      ; この秒数キー入力がなければ入力待ちをキャンセル
IH_forcedKey := ""                        ; InputHook に届かないキー（「A & B」の A）をホットキーから渡す

; Esc・Caps で終了、一定時間でタイムアウト（各モードの KeyOpt でも消えない）
IH_hook.Timeout := IH_TIMEOUT_SEC
IH_hook.KeyOpt("{Esc}{sc03A}", "ES")

; 次のキーを 1 つ待つ。endKeys は文字の代わりに受け付ける特殊キー。キャンセル・タイムアウトなら false
IH_WaitNext(mode, hint := "", endKeys := "", capsIsKey := false) {
    IH_TipWaiting(mode, hint)
    if (endKeys != "")
        IH_hook.KeyOpt(endKeys, "ES")
    IH_hook.Start()
    IH_hook.Wait()
    return !IH_EndWait(mode, capsIsKey)
}

; いま何のキー待ちかをツールチップで表示する
IH_TipWaiting(mode, hint := "") {
    global IH_waiting := true
    global IH_forcedKey := ""
    SetTimer(IH_TipClear, 0)              ; 前のモードの「消去タイマー」で待ち表示が消えないように
    ToolTip("⌨️ [" mode "] 次のキー待ち..." (hint != "" ? "`n" hint : "")
        "`nEsc / Caps / Space+Caps：キャンセル（" IH_TIMEOUT_SEC " 秒で自動キャンセル）")
}

; 入力待ちを終えた特殊キー（ホットキーから渡されたキーも含む）。文字入力なら ""
IH_EndKeyOf() => (IH_hook.EndReason = "Stopped" && IH_forcedKey != "") ? IH_forcedKey : IH_hook.EndKey

; IH_hook を「特殊キー key で終わった」ことにして止める
IH_StopWithKey(key) {
    global IH_forcedKey := key
    IH_hook.Stop()
}

; 入力待ちの終了処理。受け付けたキーを表示し、キャンセルされたら true を返す（capsIsKey：Caps をキャンセルではなくキーとして受ける）
IH_EndWait(mode, capsIsKey := false) {
    global IH_waiting
    endKey := IH_EndKeyOf()
    cancelled := ""
    if (IH_hook.EndReason = "Timeout")
        cancelled := "タイムアウト"
    else if (endKey = "Escape" || (endKey = "CapsLock" && !capsIsKey))
        cancelled := "キャンセル"
    else if (endKey = "Space" && IH_CapsWhileSpaceHeld())
        cancelled := "キャンセル"
    IH_waiting := false

    if (cancelled != "")
        ToolTip("❌ [" mode "] " cancelled)
    else
        ToolTip("✅ [" mode "] accepted:[" ((endKey != "") ? endKey : IH_hook.Input) "]")
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
    global IH_waiting := true
    SetTimer(IH_TipClear, 0)
}

; 独自の InputHook を使うモードの終了（結果を短く表示する）
IH_ModeEnd(message) {
    global IH_waiting := false
    ToolTip(message)
    SetTimer(IH_TipClear, -TOOLTIP_DURATION_MS)
}

IH_TipClear() => ToolTip()

;------------------------------------------------------------------------------
; 独自の InputHook で選ぶモード（アプリ切り替え・タブ切り替えなど）の共通部品
;------------------------------------------------------------------------------
; 呼び出しに使ったキー。「A & B」形式のホットキーなら prefix に A を入れて B を返し、それ以外は fallback を返す
IH_HotkeyTrigger(&prefix, fallback) {
    prefix := ""
    if RegExMatch(A_ThisHotkey, "^[~*$]*(\S+) & (\S+)$", &m) {
        prefix := m[1]
        return m[2]
    }
    return fallback
}

; 押されたキーで分岐するための InputHook（文字は入力させない。修飾キーと押したままのプレフィックスは除く）
IH_ChoiceHook(idleSec, prefix := "") {
    h := InputHook("L0 T" idleSec)
    h.KeyOpt("{All}", "ES")
    h.KeyOpt("{LCtrl}{RCtrl}{LShift}{RShift}{LAlt}{RAlt}{LWin}{RWin}", "-ES")
    if (prefix != "")
        h.KeyOpt("{" prefix "}", "-E")            ; 押したままのプレフィックスキーのリピートで決定しないように
    return h
}

; JIS キーボードの CapsLock（英数）は EndKey の名前が "CapsLock" とは限らないので、スキャンコードでも判定する
IH_IsCapsKey(key) => key != "" && (key = "CapsLock" || GetKeySC(key) = 0x3A)

; 取り消しのキーか（Esc、Caps、Space を押したまま Caps）。Space は決定のキーでもあるので、Caps が来なかったときは false
IH_IsCancelKey(key) => key = "Escape" || IH_IsCapsKey(key) || (key != "" && GetKeyVK(key) = 0x20 && IH_CapsWhileSpaceHeld())
