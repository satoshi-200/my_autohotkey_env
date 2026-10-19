#Requires AutoHotkey v2.0
;==============================================================================
; multi_clipboard.ahk
; マルチクリップボード：英数字キーごとの「箱」に文字列を保存・貼り付けする
;   Clip_Copy()      選択範囲をコピーして箱に保存
;   Clip_Cut()       選択範囲を切り取って箱に保存
;   Clip_Paste()     箱の中身を貼り付け
;   Clip_Show()      箱の中身を全文表示
;   Clip_Clear()     箱を 1 つ空にする（すべて空にする Clip_ClearAll は Lib\archive\unused_functions.ahk に移した）
;   箱は一覧（キーと中身の先頭、複数列）から、キー / 矢印+Enter / クリックで選ぶ。Esc でキャンセル
;==============================================================================
#Include %A_LineFile%\..\ui_common.ahk
#Include %A_LineFile%\..\text_ops.ahk

Clip_boxes := Map()
CLIP_ROWS  := 12                    ; 一覧の 1 列の行数（超えたら次の列へ）
CLIP_C_SEL := "CCE4F7"              ; 選んでいる行の背景色
CLIP_C_BG  := "FFFFFF"              ; 一覧の背景色

Clip_Copy() => _Clip_Store("save")
Clip_Cut()  => _Clip_Store("cut")

Clip_Paste() {
    key := _Clip_Pick("paste")
    if (key = "")
        return
    if !Clip_boxes.Has(key) {
        _Clip_Tip("箱 [" key "] は空っぽです。")
        return
    }
    QM_Paste(Clip_boxes[key], 100)
}

Clip_Show() {
    static win := 0, content := 0
    key := _Clip_Pick("check")
    if (key = "")
        return
    if !win {
        win := Gui("+AlwaysOnTop")
        win.SetFont("s10", "Yu Gothic UI")
        content := win.Add("Edit", "ReadOnly +VScroll w640 h400")
        win.OnEvent("Escape", (g) => g.Hide())
    }
    win.Title := "箱 [" key "] の中身（Esc で閉じる）"
    content.Value := Clip_boxes[key]
    win.Show()
}

Clip_Clear() {
    key := _Clip_Pick("clear")
    if (key = "" || !Clip_boxes.Has(key))
        return
    Clip_boxes.Delete(key)
    _Clip_Tip("箱 [" key "] を空にしました。")
}

;------------------------------------------------------------------------------
; 内部処理
;------------------------------------------------------------------------------
; 選択範囲をコピー（mode = "save"）または切り取り（"cut"）して、選んだ箱に入れる
_Clip_Store(mode) {
    key := _Clip_Pick(mode)
    if (key = "")
        return
    cut := (mode = "cut")
    A_Clipboard := ""
    Send(cut ? "^x" : "^c")
    if ClipWait(0.5) {
        Clip_boxes[key] := A_Clipboard
        _Clip_Tip("箱 [" key "] に" (cut ? "切り取って保存" : "コピー") "しました！")
    } else
        _Clip_Tip((cut ? "切り取り" : "コピー") "失敗。文字を選択してる？")
}

; 一覧に出す箱のキー。"save" / "cut" は空き箱も、それ以外は中身のある箱だけ
_Clip_Keys(mode) {
    static BASE_KEYS := "abcdefghijklmnopqrstuvwxyz0123456789"
    showEmpty := (mode = "save" || mode = "cut")
    keys := []
    loop parse BASE_KEYS
        if (showEmpty || Clip_boxes.Has(A_LoopField))
            keys.Push(A_LoopField)
    for key in Clip_boxes                           ; 英数字以外のキーに保存された箱
        if !InStr(BASE_KEYS, key)
            keys.Push(key)
    return keys
}

; 箱の一覧を複数列で表示し、キー入力・矢印+Enter・クリックで選ばせる。戻り値は箱のキー（キャンセルは ""）
_Clip_Pick(mode) {
    keys := _Clip_Keys(mode)
    if !keys.Length {
        _Clip_Tip("中身のある箱はありません")
        return ""
    }
    target := WinExist("A")
    st := {keys: keys, sel: 1, cells: [], picked: "", cancelled: false, hook: 0}
    g := _Clip_PickerGui(mode, st)
    g.Show("AutoSize Center")
    _Clip_Paint(st, st.sel, CLIP_C_SEL)
    _Clip_WaitPick(st)
    g.Destroy()

    ; コピー・貼り付けが元のウィンドウに届くように戻す
    if target {
        try WinActivate("ahk_id " target)
        try WinWaitActive("ahk_id " target, , 1)
    }
    return st.picked
}

; 一覧の画面を作る（行は CLIP_ROWS ごとに次の列へ）。クリック・Esc は st に書いて入力待ちを止める
_Clip_PickerGui(mode, st) {
    static KEY_W := 30, ROW_H := 26, GAP := 14
    static TITLES := Map(
        "save",  "【保存】コピーして入れる箱",
        "cut",   "【切取】切り取って入れる箱",
        "paste", "【貼付】取り出す箱",
        "check", "【確認】中身を見る箱",
        "clear", "【消去】空にする箱")

    keys := st.keys
    cols := Ceil(keys.Length / CLIP_ROWS)
    nRows := Min(keys.Length, CLIP_ROWS)
    cellW := cols = 1 ? 520 : 260
    totalW := cols * (KEY_W + cellW) + (cols - 1) * GAP

    g := Gui("+AlwaysOnTop -Caption +Border +ToolWindow", "ClipBoxPicker")
    g.BackColor := CLIP_C_BG
    g.MarginX := 10, g.MarginY := 8
    g.SetFont("s10", "Yu Gothic UI")
    g.Add("Text", "x10 y8 w" totalW, "マルチクリップボード ▸ " TITLES[mode])

    for i, key in keys {
        x := 10 + ((i - 1) // CLIP_ROWS) * (KEY_W + cellW + GAP)
        y := 36 + Mod(i - 1, CLIP_ROWS) * ROW_H
        has := Clip_boxes.Has(key)
        g.SetFont("s10 bold c" (has ? "1F4E99" : "A0A0A0"))
        kc := g.Add("Text", "x" x " y" y " w" KEY_W " h" (ROW_H - 2) " Center +0x200 Background" CLIP_C_BG, key)
        g.SetFont("s10 norm c" (has ? "000000" : "A0A0A0"))
        ; 0x200 = 縦中央・1 行、0x4000 = はみ出したら末尾を…に
        tc := g.Add("Text", "x" (x + KEY_W) " y" y " w" cellW " h" (ROW_H - 2) " +0x4200 Background" CLIP_C_BG
            , has ? _Clip_Preview(Clip_boxes[key]) : "（空き）")
        onClick := _Clip_OnClick.Bind(st, key)
        kc.OnEvent("Click", onClick), tc.OnEvent("Click", onClick)
        st.cells.Push([kc, tc])
    }
    g.SetFont("s9 norm cGray")
    g.Add("Text", "x10 y" (36 + nRows * ROW_H + 6) " w" totalW
        , "キーを押すと決定　矢印 + Enter / クリックでも可　Esc：キャンセル")
    g.OnEvent("Escape", (*) => _Clip_Cancel(st))
    g.OnEvent("Close", (*) => _Clip_Cancel(st))
    return g
}

; キーを待ち、選ばれた箱を st.picked に入れる。矢印は終了キーにせず通知だけ受ける（入力待ちを張り直す間にキーを取りこぼさないため）
_Clip_WaitPick(st) {
    hook := st.hook := InputHook("L1")
    hook.KeyOpt("{Esc}{Enter}{NumpadEnter}", "E")
    hook.KeyOpt("{Up}{Down}{Left}{Right}", "N")
    hook.OnKeyDown := (h, vk, sc) => _Clip_Move(st, vk)
    hook.Start()
    hook.Wait()
    if (st.picked != "" || st.cancelled)
        return
    if (hook.EndReason = "Max") {
        if ((st.picked := _Clip_FindKey(st.keys, hook.Input)) = "")
            _Clip_Tip("[" hook.Input "] は選べません")
    } else if (hook.EndReason = "EndKey" && InStr(hook.EndKey, "Enter"))
        st.picked := st.keys[st.sel]
}

_Clip_OnClick(st, key, *) {
    st.picked := key
    if st.hook
        st.hook.Stop()
}

_Clip_Cancel(st) {
    st.cancelled := true
    if st.hook
        st.hook.Stop()
}

; 選択の移動（↑ ↓ で 1 行、← → で 1 列）
_Clip_Move(st, vk) {
    next := st.sel + (vk = 0x26 ? -1 : vk = 0x28 ? 1 : vk = 0x25 ? -CLIP_ROWS : CLIP_ROWS)
    if (next >= 1 && next <= st.keys.Length) {
        _Clip_Paint(st, st.sel, CLIP_C_BG)
        _Clip_Paint(st, st.sel := next, CLIP_C_SEL)
    }
}

_Clip_Paint(st, i, color) {
    for c in st.cells[i] {
        c.Opt("Background" color)
        c.Redraw()
    }
}

; 一覧に出す中身の先頭（改行は ↵ にして 1 行に）
_Clip_Preview(text) {
    text := StrReplace(StrReplace(StrReplace(text, "`r`n", " ↵ "), "`n", " ↵ "), "`t", " ")
    return StrLen(text) > 200 ? SubStr(text, 1, 200) : text
}

_Clip_FindKey(keys, target) {
    for key in keys
        if (StrLower(key) = StrLower(target))
            return key
    return ""
}

_Clip_Tip(text) => UI_TipFlash("✨ " text, 2000)
