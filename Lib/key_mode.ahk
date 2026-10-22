#Requires AutoHotkey v2.0
;==============================================================================
; key_mode.ahk
; InputHook でキーを受けるモード（カーソル移動モード、Vimium C 風ヒントなど）の共通の骨組み。関数は IHM_ で始める
;   IHM_Run(st, opts)    モードを動かす。st はモードの状態オブジェクト（held・leftHand・result・hook・idle が加わる）
;   IHM_Finish(st, result)  結果を決めて待ちを終える（最初に決めた結果を残す）
;   IHM_Tip(st, status, help)  案内を出す（出し方は opts.tip。下の説明）
; 骨組みがやること
;   ・IH_ModeBegin / IH_ModeEnd、InputHook（全キーを通知し、アプリには渡さない）、時間切れ（押すたびに数え直す）、後始末
;   ・押しっぱなし（キーリピート）の無視、押しているキーの記録（st.held：スキャンコード → true）
;     始めたときに押しているキー（起動に使ったキー）も調べて記録するので、割り当てを変えてもこちらは直さなくてよい
;   ・親指キーのレイヤー（変換+g など、別のキーを送る割り当て）を、送るキーに読み替える（IH_LayerSc）
;   ・Space+A のあとのキー 1 つを、Space+A の表で右手側の文字に直す（IH_SpaceAChar）
; 使い方の例：Lib\mouse_grid.ahk
; opts の項目
;   message(st)   終わったときに出す文字列を返す（st.result と st.err を見る）。必須
;   onKey(st, k)  キーが来たとき。k は {sc, name, left}。sc は読み替えたあとのスキャンコード、name は文字（小文字）、
;                 left は Space+A で右手側の文字に直したキー（このとき sc は 0）。必須
;   onStart(st)   始める前（表示を作るなど）。ここで IHM_Finish したら、キーを待たずに終わる。
;                 onEnd(st) 後始末（finally で呼ぶ）。onTip(st) Space+A の待ちが変わったとき（案内の書き直し）。onKeyUp(st, vk, sc) キーを離したとき
;   idleSec       この秒数キー入力がなければ "timeout"（既定 IH_TIMEOUT_SEC）
;   layers        false にすると読み替えも Space+A も行わず、すべてのキーをそのまま onKey に渡す（親指キーに独自の意味があるモード用）。
;                 このとき k は {sc, vk, name, raw: true}。リピートの無視もしない。既定 true
;   keep          Space+A の待ちの間も、文字に直さず通常のキーとして扱うスキャンコード（Esc・Caps・BackSpace・Tab は常に）
;   critical      true にすると、キーの処理の間はタイマーに割り込まれない
;   tip           案内（IHM_Tip）の出し方。既定 "cursor"
;                   "cursor"：状態と説明を、マウスカーソルの近くに出す
;                   "corner"：状態（短い 1 行）だけを、カーソルのあるモニターの左下に出す。手が止まったら説明も出す
;                   "hidden"：何も出さない。手が止まったら、左下に状態と説明を出す
;                 画面に重ねる表示があるモード（ラベル・グリッド）は、案内が押したい場所を隠さないよう "corner" か "hidden" にする
;   helpDelayMs   "corner" / "hidden" で、説明を出すまでの操作のない時間（既定 IHM_HELP_DELAY_MS）
; 親指キー（変換・Space・無変換）そのものは何もしない（k を渡さない）。親指キーを押したまま打ったキーのうち、
; 送るキーのない割り当て（関数を呼ぶものなど）は渡さない（Esc と Caps は除く）。
;==============================================================================
#Include %A_LineFile%\..\key_wait.ahk
#Include %A_LineFile%\..\ui_common.ahk

IHM_HELP_DELAY_MS := 1000                 ; 案内の説明を出すまでの、操作のない時間（tip が "corner" / "hidden" のとき）

IHM_Run(st, opts) {
    IH_ModeBegin()
    st.result := "", st.err := "", st.leftHand := false
    st.held := Map()
    st.hook := InputHook("L0")
    st.idle := IHM_Finish.Bind(st, "timeout")
    st.tipPos := opts.HasProp("tip") ? opts.tip : "cursor"
    st.helpDelayMs := opts.HasProp("helpDelayMs") ? opts.helpDelayMs : IHM_HELP_DELAY_MS
    st.helpFn := _IHM_ShowHelp.Bind(st)
    st.tipText := ["", ""]
    idleMs := (opts.HasProp("idleSec") ? opts.idleSec : IH_TIMEOUT_SEC) * 1000
    st.hook.KeyOpt("{All}", "NS")                   ; すべてのキーを通知し、アプリには渡さない
    st.hook.OnKeyDown := _IHM_OnKeyDown.Bind(st, opts, idleMs)
    st.hook.OnKeyUp := _IHM_OnKeyUp.Bind(st, opts)
    _IHM_MarkHeld(st)
    try {
        if opts.HasProp("onStart")
            opts.onStart.Call(st)
        if (st.result = "") {                       ; onStart で終えている（例：部品が見つからない）ときは待たない
            SetTimer(st.idle, -idleMs)
            st.hook.Start()
            st.hook.Wait()
        }
    }
    catch as e {
        st.result := "error"
        st.err := e.Message
    }
    finally {
        SetTimer(st.idle, 0)
        SetTimer(st.helpFn, 0)
        st.hook.Stop()
        if opts.HasProp("onEnd")
            opts.onEnd.Call(st)
    }
    IH_ModeEnd(opts.message.Call(st))
}

; 結果を決めて待ちを終える（最初に決めた結果を残す）
IHM_Finish(st, result) {
    if (st.result = "")
        st.result := result
    st.hook.Stop()
}

; 案内を出す。status は短い状態（1 行）、help は操作の説明（なければ ""）。出し方は opts.tip
IHM_Tip(st, status, help := "") {
    SetTimer(st.helpFn, 0)
    st.tipText := [status, help]
    switch st.tipPos {
        case "cursor":
            UI_ToolTip(status (help != "" ? "`n" help : ""))
            return
        case "hidden":
            ToolTip()
        default:
            _IHM_TipCorner(status)
    }
    if (help != "")
        SetTimer(st.helpFn, -st.helpDelayMs)
}

_IHM_ShowHelp(st) {
    if (st.result = "")
        _IHM_TipCorner(st.tipText[1] "`n" st.tipText[2])
}

; カーソルのあるモニターの作業領域の左下に出す（タスクバーに重ねない）
_IHM_TipCorner(text) {
    CoordMode("Mouse", "Screen"), CoordMode("ToolTip", "Screen")
    MouseGetPos(&mx, &my)
    MonitorGetWorkArea(UI_MonitorFromPoint(mx, my), &l, &t, &r, &b)
    if !(hwnd := UI_ToolTip(text, l + 12, b - 60))
        return
    WinGetPos(, , , &h, hwnd)
    WinMove(l + 12, b - h - 12, , , hwnd)
}

_IHM_OnKeyDown(st, opts, idleMs, h, vk, sc) {
    if (opts.HasProp("critical") && opts.critical)
        Critical()
    SetTimer(st.idle, -idleMs)                      ; 待ち時間は押すたびに数え直す
    if (st.result != "")
        return
    if (opts.HasProp("layers") && !opts.layers) {
        opts.onKey.Call(st, {sc: sc, vk: vk, name: _IHM_KeyName(vk, sc), raw: true})
        return
    }
    if (st.held.Has(sc) && sc != 0x01 && sc != 0x3A)   ; 押しっぱなしのリピートは無視（取り消しの Esc / Caps は常に受ける）
        return
    k := _IHM_Resolve(st, opts, vk, sc)
    if k
        opts.onKey.Call(st, k)
}

_IHM_OnKeyUp(st, opts, h, vk, sc) {
    if st.held.Has(sc)
        st.held.Delete(sc)
    if opts.HasProp("onKeyUp")
        opts.onKeyUp.Call(st, vk, sc)
}

; 始めたときに押しているキー（起動に使ったキーなど）を st.held に入れ、離すまでリピートとして無視する
; Caps・半角/全角・かなは、離しても押したままと返ることがあるので調べない
_IHM_MarkHeld(st) {
    static codes := 0
    if !IsObject(codes) {
        codes := []
        for sc in [0x79, 0x7B]                      ; 変換・無変換
            codes.Push(sc)
        loop 0x58
            if !(A_Index = 0x3A || A_Index = 0x29)
                codes.Push(A_Index)
        valid := []
        for sc in codes                             ; キーのないスキャンコードは GetKeyState がエラーになるので除く
            try GetKeyState(Format("sc{:X}", sc), "P"), valid.Push(sc)
        codes := valid
    }
    for sc in codes
        if GetKeyState(Format("sc{:X}", sc), "P")
            st.held[sc] := true
}

; 押されたキーを {sc, name, left} にする。渡さないキーは 0
_IHM_Resolve(st, opts, vk, sc) {
    spaceHeld := st.held.Has(0x39)
    st.held[sc] := true
    if (sc = 0x39 || sc = 0x79 || sc = 0x7B)        ; 親指キーそのものは何もしない
        return 0
    if (spaceHeld && sc = 0x1E) {                   ; Space+A：次のキー 1 つを右手側の文字に直す
        st.leftHand := true
        _IHM_Tip(st, opts)
        return 0
    }
    if (st.leftHand && !_IHM_IsKept(opts, sc)) {
        st.leftHand := false
        ch := IH_SpaceAChar(_IHM_KeyName(vk, sc))
        if (ch = "") {
            _IHM_Tip(st, opts)
            return 0
        }
        return {sc: 0, name: StrLower(ch), left: true}
    }
    st.leftHand := false
    real := IH_LayerSc(st.held, sc, true)           ; 変換+g や Space+s は、送るキー（BackSpace）として扱う
    if !real
        return 0
    return {sc: real, name: (real = sc) ? _IHM_KeyName(vk, sc) : StrLower(GetKeyName(Format("sc{:X}", real))), left: false}
}

_IHM_IsKept(opts, sc) {
    if (sc = 0x01 || sc = 0x3A || sc = 0x0E || sc = 0x0F)   ; Esc / Caps / BackSpace / Tab
        return true
    if opts.HasProp("keep")
        for k in opts.keep
            if (k = sc)
                return true
    return false
}

_IHM_Tip(st, opts) {
    if opts.HasProp("onTip")
        opts.onTip.Call(st)
}

_IHM_KeyName(vk, sc) => StrLower(GetKeyName(Format("vk{:X}sc{:X}", vk, sc)))
