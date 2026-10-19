#Requires AutoHotkey v2.0
;==============================================================================
; key_wait.ahk
; 入力待ち（起点キーのあと次のキーを 1 つ受け取る）の共通部品
;   IH_hook          入力待ちで共有する InputHook
;   IH_waiting       待機中フラグ（待機中は各レイヤーのホットキーを止める）
;   IH_WaitNext()    次のキーを 1 つ待ち、キャンセル・タイムアウトを判定する
;   IH_ModeBegin() / IH_ModeEnd()  独自の InputHook を使うモードの開始・終了処理
;   IH_HotkeyTrigger() / IH_ChoiceHook() / IH_IsCancelKey()  そのモードで使う部品（ファイルの末尾）
;   IH_LayerSc()     変換+g や Space+s のような「別のキーを送る割り当て」を、モードでもそのキーとして扱う
;   IH_SpaceAChar()  Space+A の表（右手側の文字を左手で入力）を、モードから引く
;==============================================================================
#Include %A_LineFile%\..\config.ahk
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\keymap_parse.ahk

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
    SetTimer(UI_TipClear, 0)              ; 前のモードの「消去タイマー」で待ち表示が消えないように
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
        UI_TipFlash("❌ [" mode "] " cancelled)
    else
        UI_TipFlash("✅ [" mode "] accepted:[" ((endKey != "") ? endKey : IH_hook.Input) "]")
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
    SetTimer(UI_TipClear, 0)
}

; 独自の InputHook を使うモードの終了（結果を短く表示する）
IH_ModeEnd(message) {
    global IH_waiting := false
    UI_TipFlash(message)
}

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

;------------------------------------------------------------------------------
; 親指キーのレイヤーのうち、「別のキーを送るだけ」の割り当てを、モードでもそのキーとして扱うための部品
;   モードの間はレイヤーのホットキーが止まる。自分の SendInput は自分の InputHook に届かないので、
;   変換+g（BackSpace）や Space+s（BackSpace）を押しても、モードには g や s だけが届く。
;   そこで、keymap\hold_keys.ahk の「起点 & キー::  SendInput("{キー}")」を読んで、同じ対応をモードでも使う。
;   対応を二重に書かない。割り当てを変えれば、モードもこれに従う。
;------------------------------------------------------------------------------
; 親指キー（変換・Space・無変換）を押したまま打ったキー sc を、レイヤーが送るキーのスキャンコードに直す。
; held は押されているキー（スキャンコード → true）。送るキーがない割り当ては、ignoreOthers なら 0（無視）、そうでなければ元の sc。
; Esc と Caps は取り消しなので、親指キーを押していてもそのまま返す。
; 親指キー自身に独自の意味があるモード（Vimium C 風ヒントの Space＝ダブルクリックなど）では使わない。
IH_LayerSc(held, sc, ignoreOthers := false) {
    static prefixes := Map(0x79, "vk1C", 0x39, "vk20", 0x7B, "vk1D")
    static table := 0
    if (sc = 0x01 || sc = 0x3A || prefixes.Has(sc))
        return sc
    for thumb, prefix in prefixes {
        if !held.Has(thumb)
            continue
        if !IsObject(table)
            table := _IH_LoadLayerTable()
        key := prefix "|" sc
        if table.Has(key)
            return table[key]
        return ignoreOthers ? 0 : sc
    }
    return sc
}

; hold_keys.ahk から、「起点|キーのスキャンコード → 送るキーのスキャンコード」の表を作る
_IH_LoadLayerTable() {
    table := Map()
    try
        src := KP_Read("hold_keys.ahk")
    catch
        return table
    for prefix in ["vk1C", "vk1D", "vk20"]
        for row in KP_HoldRows(src, prefix) {
            if RegExMatch(row.action, "^SendInput\(`"(?:\{Blind\})?\{(\w+)\}`"\)$", &k)
                name := k[1]
            else if (row.action = "ShiftHold_Enter()")
                name := "Enter"
            else
                continue
            from := GetKeySC(row.key), to := GetKeySC(name)
            if (from && to && !table.Has(prefix "|" from))
                table[prefix "|" from] := to
        }
    return table
}

; Space+A（leader_keys.ahk の Leader_SpaceA の表）で、キー key（小文字 1 文字）に割り当てられた 1 文字。なければ ""
; 左手だけで右手側の文字を入力するモード（Vimium C 風ヒントなど）が、同じ対応を使うための部品。表は読んで使う（二重に書かない）
IH_SpaceAChar(key) {
    static table := 0
    if !IsObject(table) {
        table := Map()
        table.CaseSense := false
        src := ""
        try src := KP_Read("leader_keys.ahk")
        for row in KP_LeaderRows(src, "Leader_SpaceA")
            if (!row.special && RegExMatch(row.action, '^"\{(.)\}"$', &m))
                table[row.key] := m[1]
    }
    return table.Has(key) ? table[key] : ""
}
